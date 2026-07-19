#!/usr/bin/env bash
set -euo pipefail

database_name=${1:?Usage: export_parquet_to_blob.sh <database-name>}

if [[ ! "$database_name" =~ ^[A-Za-z0-9_]+$ ]]; then
    printf 'Database names may contain only letters, numbers, and underscores.\n' >&2
    exit 2
fi

required_variables=(
    SQL_SERVER
    SQL_USER
    SQLCMDPASSWORD
    AZURE_STORAGE_SAS_TOKEN
)

for variable_name in "${required_variables[@]}"; do
    if [[ -z "${!variable_name:-}" ]]; then
        printf 'Required environment variable %s is not set.\n' \
            "$variable_name" >&2
        exit 1
    fi
done

sqlcmd_bin=${SQLCMD_BIN:-sqlcmd}
storage_account=${AZURE_STORAGE_ACCOUNT:-tpcpublicstorage}
storage_container=${AZURE_STORAGE_CONTAINER:-tpch}
blob_prefix=${PARQUET_BLOB_PREFIX:-tpch_parquet/$database_name}
storage_sas=${AZURE_STORAGE_SAS_TOKEN#\?}
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
schema_generator="$script_dir/../schemas/generate_tpch_schema.sql"
schema_dir=$(mktemp -d "${TMPDIR:-/tmp}/tpch-parquet-schema.XXXXXX")
cleanup_database_objects=0

command -v "$sqlcmd_bin" >/dev/null
command -v az >/dev/null
test -r "$schema_generator"

if [[ -z "$storage_sas" || "$storage_sas" == *$'\n'* || "$storage_sas" == *$'\r'* ]]; then
    printf 'AZURE_STORAGE_SAS_TOKEN must be a non-empty, single-line token.\n' >&2
    exit 1
fi

if [[ ! "$blob_prefix" =~ ^[A-Za-z0-9_./-]+$ || "$blob_prefix" == *..* ]]; then
    printf 'PARQUET_BLOB_PREFIX contains unsupported characters.\n' >&2
    exit 2
fi

sqlcmd_options=(
    -S "$SQL_SERVER"
    -d "$database_name"
    -U "$SQL_USER"
    -N
    -l 60
    -t 0
    -b
    -r 1
    -W
)

if [[ "${SQLCMD_TRUST_SERVER_CERTIFICATE:-0}" == "1" ]]; then
    sqlcmd_options+=(-C)
fi

run_sql_file() {
    "$sqlcmd_bin" "${sqlcmd_options[@]}" "$@"
}

cleanup() {
    status=$?
    trap - EXIT

    if [[ "$cleanup_database_objects" == "1" ]] \
        && [[ "${KEEP_CETAS_OBJECTS:-0}" != "1" ]]; then
        if ! run_sql_file \
            -v "DATABASE_NAME=$database_name" \
            -i "$script_dir/cleanup_tpch_parquet_objects.sql"; then
            printf 'Failed to remove temporary CETAS objects.\n' >&2
            if [[ "$status" == "0" ]]; then
                status=1
            fi
        fi
    fi

    rm -rf "$schema_dir"
    exit "$status"
}
trap cleanup EXIT

existing_blob_count=$(
    AZURE_STORAGE_ACCOUNT="$storage_account" \
    AZURE_STORAGE_SAS_TOKEN="$storage_sas" \
        az storage blob list \
        --container-name "$storage_container" \
        --prefix "$blob_prefix/" \
        --num-results 1 \
        --query 'length(@)' \
        --output tsv \
        --only-show-errors
)

if [[ "$existing_blob_count" != "0" ]]; then
    printf 'Destination prefix is not empty: %s/%s\n' \
        "$storage_container" "$blob_prefix" >&2
    exit 3
fi

"$script_dir/configure_cetas_credential.sh" "$database_name"
cleanup_database_objects=1

run_sql_file \
    -v "DATABASE_NAME=$database_name" "BLOB_PREFIX=$blob_prefix" \
    -i "$script_dir/export_tpch_tables_parquet.sql"

run_sql_file \
    -v "DATABASE_NAME=$database_name" \
    -i "$script_dir/validate_tpch_parquet.sql"

generate_schema() {
    local mode=$1
    local table_filter=$2
    local output_file=$3

    "$sqlcmd_bin" "${sqlcmd_options[@]}" \
        -h -1 \
        -w 65535 \
        -v \
            "SCHEMA_MODE=$mode" \
            "SCHEMA_FILTER=dbo" \
            "TABLE_FILTER=$table_filter" \
        -i "$schema_generator" \
        -o "$output_file"

    test -s "$output_file"
}

upload_schema() {
    local source_file=$1
    local blob_name=$2

    AZURE_STORAGE_ACCOUNT="$storage_account" \
    AZURE_STORAGE_SAS_TOKEN="$storage_sas" \
        az storage blob upload \
        --container-name "$storage_container" \
        --name "$blob_name" \
        --file "$source_file" \
        --content-type 'text/plain; charset=utf-8' \
        --overwrite false \
        --only-show-errors \
        --output none
}

generate_schema full '*' "$schema_dir/_schema.sql"
upload_schema "$schema_dir/_schema.sql" "$blob_prefix/_schema.sql"

for table_name in customer lineitem nation orders part partsupp region supplier; do
    table_schema="$schema_dir/$table_name.sql"
    generate_schema table "$table_name" "$table_schema"
    upload_schema \
        "$table_schema" \
        "$blob_prefix/dbo.$table_name/_schema.sql"
done

blob_count=$(
    AZURE_STORAGE_ACCOUNT="$storage_account" \
    AZURE_STORAGE_SAS_TOKEN="$storage_sas" \
        az storage blob list \
        --container-name "$storage_container" \
        --prefix "$blob_prefix/" \
        --query 'length(@)' \
        --output tsv \
        --only-show-errors
)

printf '%s/%s contains %s Parquet and schema blobs.\n' \
    "$storage_container" "$blob_prefix" "$blob_count"
