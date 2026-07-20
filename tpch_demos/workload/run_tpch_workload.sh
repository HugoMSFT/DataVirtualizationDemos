#!/usr/bin/env bash
set -euo pipefail

required_variables=(
    SQL_SERVER
    SQL_DATABASE
    SQL_USER
    SQLCMDPASSWORD
    PLATFORM_LABEL
    OUTPUT_DIR
)

for variable_name in "${required_variables[@]}"; do
    if [[ -z "${!variable_name:-}" ]]; then
        printf 'Required environment variable %s is not set.\n' "$variable_name" >&2
        exit 1
    fi
done

if [[ "$PLATFORM_LABEL" != "vm" && "$PLATFORM_LABEL" != "azure" ]]; then
    printf 'PLATFORM_LABEL must be vm or azure.\n' >&2
    exit 2
fi

command -v docker >/dev/null

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$OUTPUT_DIR"
output_dir="$(cd "$OUTPUT_DIR" && pwd)"

sqlcmd_options=(
    -S "$SQL_SERVER"
    -d "$SQL_DATABASE"
    -U "$SQL_USER"
    -N
    -l 60
    -t 0
    -b
    -r 1
    -W
    -s '|'
    -h -1
    -w 65535
    -i /work/tpch_readonly_workload.sql
)

if [[ "${SQLCMD_TRUST_SERVER_CERTIFICATE:-0}" == "1" ]]; then
    sqlcmd_options+=(-C)
fi

read -r -a target_schemas <<< "${TARGET_SCHEMAS:-dbo rs ext}"

if [[ "${#target_schemas[@]}" == "0" ]]; then
    printf 'TARGET_SCHEMAS must contain at least one schema.\n' >&2
    exit 2
fi

seen_schemas=' '
for schema_name in "${target_schemas[@]}"; do
    case "$schema_name" in
        dbo|rs|ext) ;;
        *)
            printf 'Unsupported schema in TARGET_SCHEMAS: %s\n' \
                "$schema_name" >&2
            exit 2
            ;;
    esac

    if [[ "$seen_schemas" == *" $schema_name "* ]]; then
        printf 'TARGET_SCHEMAS contains duplicate schema %s.\n' \
            "$schema_name" >&2
        exit 2
    fi
    seen_schemas+="$schema_name "
done

runs=()
schema_count=${#target_schemas[@]}
for iteration in 1 2 3; do
    offset=$(( (iteration - 1) % schema_count ))
    for ((position = 0; position < schema_count; position++)); do
        schema_index=$(( (offset + position) % schema_count ))
        runs+=("$iteration ${target_schemas[$schema_index]}")
    done
done

for run in "${runs[@]}"; do
    read -r iteration schema_name <<< "$run"
    output_file="${output_dir}/${PLATFORM_LABEL}_${schema_name}_${iteration}.txt"
    attempt_file="${output_file}.attempt"

    if [[ "${SKIP_COMPLETED:-0}" == "1" ]] \
        && [[ -f "$output_file" ]] \
        && grep -q '|99|TOTAL|' "$output_file"; then
        printf 'Skipping completed %s iteration %s on %s.\n' \
            "$schema_name" "$iteration" "$PLATFORM_LABEL"
        continue
    fi

    printf 'Running %s iteration %s on %s...\n' \
        "$schema_name" "$iteration" "$PLATFORM_LABEL"

    completed=0
    for attempt in 1 2 3; do
        rm -f "$attempt_file"

        if docker run --rm --platform "${DOCKER_PLATFORM:-linux/amd64}" \
            -v "${script_dir}:/work:ro" \
            -v "${output_dir}:/results" \
            -e SQLCMDPASSWORD \
            -e "TARGET_SCHEMA=${schema_name}" \
            -e "ITERATION=${iteration}" \
            "${SQLCMD_IMAGE:-mcr.microsoft.com/mssql-tools:latest}" \
            /opt/mssql-tools/bin/sqlcmd \
            "${sqlcmd_options[@]}" \
            -o "/results/$(basename "$attempt_file")"; then
            if ! grep -q '|99|TOTAL|' "$attempt_file"; then
                printf 'The successful sqlcmd process did not emit a TOTAL row.\n' >&2
                cat "$attempt_file" >&2
                exit 1
            fi

            mv "$attempt_file" "$output_file"
            completed=1
            break
        fi

        if [[ ! -f "$attempt_file" ]]; then
            printf 'sqlcmd failed before producing an output file.\n' >&2
            exit 1
        fi

        if ! grep -Eqi \
            'communication link failure|TCP Provider|not currently available|temporarily unavailable|database .* is resuming' \
            "$attempt_file"; then
            cat "$attempt_file" >&2
            exit 1
        fi

        printf '  transient connection failure (attempt %s of 3)\n' "$attempt" >&2
        if [[ "$attempt" -lt 3 ]]; then
            sleep "${RETRY_DELAY_SECONDS:-20}"
        fi
    done

    if [[ "$completed" != "1" ]]; then
        cat "$attempt_file" >&2
        exit 1
    fi

    awk -F'|' '$4 == 99 { printf "  total: %s ms\n", $6 }' "$output_file"
done
