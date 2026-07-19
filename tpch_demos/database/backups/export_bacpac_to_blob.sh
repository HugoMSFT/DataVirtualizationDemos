#!/usr/bin/env bash
set -euo pipefail

database_name=${1:?Usage: export_bacpac_to_blob.sh <database-name>}

if [[ ! "$database_name" =~ ^[A-Za-z0-9_]+$ ]]; then
    printf 'Database names may contain only letters, numbers, and underscores.\n' >&2
    exit 2
fi

required_variables=(
    SQL_SERVER
    SQL_USER
    SQLCMDPASSWORD
)

for variable_name in "${required_variables[@]}"; do
    if [[ -z "${!variable_name:-}" ]]; then
        printf 'Required environment variable %s is not set.\n' \
            "$variable_name" >&2
        exit 1
    fi
done

sqlpackage_bin=${SQLPACKAGE_BIN:-sqlpackage}
storage_account=${AZURE_STORAGE_ACCOUNT:-tpcpublicstorage}
storage_container=${AZURE_STORAGE_CONTAINER:-tpch}
blob_prefix=${BACPAC_BLOB_PREFIX:-}
output_dir=${OUTPUT_DIR:-"$PWD/tpch-bacpac-output"}

if [[ ! "$blob_prefix" =~ ^[A-Za-z0-9_./-]*$ || "$blob_prefix" == *..* ]]; then
    printf 'BACPAC_BLOB_PREFIX contains unsupported characters.\n' >&2
    exit 2
fi

blob_prefix=${blob_prefix#/}
if [[ -n "$blob_prefix" ]]; then
    blob_prefix=${blob_prefix%/}/
fi

command -v "$sqlpackage_bin" >/dev/null
command -v az >/dev/null
command -v curl >/dev/null
command -v unzip >/dev/null

mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
target_file="$output_dir/$database_name.bacpac"
temp_directory="$output_dir/.tmp-$database_name"
blob_name="${blob_prefix}${database_name}.bacpac"
trust_server_certificate=False

if [[ "${SQLCMD_TRUST_SERVER_CERTIFICATE:-0}" == "1" ]]; then
    trust_server_certificate=True
fi

cleanup() {
    rm -rf "$temp_directory"
}
trap cleanup EXIT

if [[ -e "$target_file" && "${REUSE_EXISTING_BACPAC:-0}" != "1" ]]; then
    printf 'Target file already exists: %s\n' "$target_file" >&2
    exit 3
fi

if [[ ! -e "$target_file" ]]; then
    mkdir -p "$temp_directory"
    "$sqlpackage_bin" \
        /Action:Export \
        /TargetFile:"$target_file" \
        /SourceServerName:"$SQL_SERVER" \
        /SourceDatabaseName:"$database_name" \
        /SourceUser:"$SQL_USER" \
        /SourcePassword:"$SQLCMDPASSWORD" \
        /SourceEncryptConnection:True \
        /SourceTrustServerCertificate:"$trust_server_certificate" \
        /SourceTimeout:60 \
        /MaxParallelism:4 \
        /p:CommandTimeout=0 \
        /p:LongRunningCommandTimeout=0 \
        /p:DatabaseLockTimeout=-1 \
        /p:CompressionOption=Normal \
        /p:Storage=Memory \
        /p:TempDirectoryForTableData="$temp_directory" \
        /p:VerifyExtraction=True
else
    printf 'Reusing completed local export %s\n' "$target_file"
fi

unzip -tq "$target_file"
file_size=$(wc -c < "$target_file" | tr -d '[:space:]')

if command -v sha256sum >/dev/null; then
    sha256=$(sha256sum "$target_file" | awk '{print $1}')
else
    sha256=$(shasum -a 256 "$target_file" | awk '{print $1}')
fi

az storage blob upload \
    --account-name "$storage_account" \
    --container-name "$storage_container" \
    --name "$blob_name" \
    --file "$target_file" \
    --auth-mode login \
    --content-type application/octet-stream \
    --metadata \
        "artifact=bacpac" \
        "source_database=$database_name" \
        "sha256=$sha256" \
    --validate-content \
    --overwrite false \
    --only-show-errors \
    --output none

blob_url="https://${storage_account}.blob.core.windows.net/${storage_container}/${blob_name}"
headers=$(curl -fsSI --retry 3 "$blob_url" | tr -d '\r')
blob_size=$(printf '%s\n' "$headers" |
    awk -F': ' 'tolower($1) == "content-length" {print $2}')
blob_sha256=$(printf '%s\n' "$headers" |
    awk -F': ' 'tolower($1) == "x-ms-meta-sha256" {print $2}')

if [[ "$blob_size" != "$file_size" || "$blob_sha256" != "$sha256" ]]; then
    printf 'Blob validation failed for %s\n' "$blob_url" >&2
    exit 4
fi

if [[ "${DELETE_LOCAL_AFTER_UPLOAD:-0}" == "1" ]]; then
    rm -f "$target_file"
fi

printf '%s|%s bytes|sha256=%s\n' "$blob_url" "$blob_size" "$blob_sha256"
