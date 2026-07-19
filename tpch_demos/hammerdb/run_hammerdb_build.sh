#!/usr/bin/env bash
set -euo pipefail

target=${1:?Usage: run_hammerdb_build.sh <azure|sqlvm>}

case "$target" in
    azure)
        build_script=mssqls_tproch_build_sf10.py
        ;;
    sqlvm)
        build_script=mssqls_tproch_build_sqlvm_sf10.py
        ;;
    *)
        printf 'Target must be azure or sqlvm, not %s.\n' "$target" >&2
        exit 2
        ;;
esac

: "${MSSQL_SERVER:?MSSQL_SERVER must be set}"
: "${MSSQL_DATABASE:?MSSQL_DATABASE must be set}"
: "${MSSQL_USERNAME:?MSSQL_USERNAME must be set}"

command -v docker >/dev/null
command -v python3 >/dev/null

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
temp_secret=

cleanup() {
    if [[ -n "$temp_secret" ]]; then
        rm -f "$temp_secret"
    fi
}
trap cleanup EXIT

if [[ -n "${MSSQL_PASSWORD_FILE:-}" ]]; then
    secret_dir="$(cd "$(dirname "$MSSQL_PASSWORD_FILE")" && pwd)"
    secret_file="$secret_dir/$(basename "$MSSQL_PASSWORD_FILE")"
elif [[ -n "${MSSQL_PASSWORD:-}" ]]; then
    umask 077
    temp_secret=$(mktemp "${TMPDIR:-/tmp}/tpch-hammerdb-password.XXXXXX")
    printf '%s' "$MSSQL_PASSWORD" > "$temp_secret"
    secret_file="$temp_secret"
else
    printf 'MSSQL_PASSWORD or MSSQL_PASSWORD_FILE must be set.\n' >&2
    exit 1
fi

if [[ ! -s "$secret_file" ]]; then
    printf 'The SQL password file is empty or unreadable: %s\n' "$secret_file" >&2
    exit 1
fi

docker_options=(
    run
    --rm
    --platform "${DOCKER_PLATFORM:-linux/amd64}"
    --mount "type=bind,src=${script_dir},dst=/work,readonly"
    --mount "type=bind,src=${secret_file},dst=/run/secrets/mssql-password,readonly"
    -e "HAMMERDB_BUILD_SCRIPT=$build_script"
    -e "MSSQL_SERVER=$MSSQL_SERVER"
    -e "MSSQL_DATABASE=$MSSQL_DATABASE"
    -e "MSSQL_USERNAME=$MSSQL_USERNAME"
    -e MSSQL_PASSWORD_FILE=/run/secrets/mssql-password
)

if [[ -n "${HAMMERDB_DOCKER_NETWORK:-}" ]]; then
    docker_options+=(--network "$HAMMERDB_DOCKER_NETWORK")
fi

docker "${docker_options[@]}" "${HAMMERDB_IMAGE:-tpcorg/hammerdb:v5.0}" \
    bash -lc '
        set -euo pipefail
        export PATH="/work/bin:/opt/mssql-tools18/bin:$PATH"
        export TMP=/tmp/hammerdb-tmp
        mkdir -p "$TMP"
        cd /home/hammerdb
        exec ./hammerdbcli py auto "/work/$HAMMERDB_BUILD_SCRIPT"
    ' 2>&1 |
    MSSQL_PASSWORD_FILE="$secret_file" python3 -u "$script_dir/redact_stream.py"
