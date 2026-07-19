#!/usr/bin/env bash
set -euo pipefail

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
credential_url=${BACKUP_CREDENTIAL_URL:-https://tpcpublicstorage.blob.core.windows.net/tpch}
command -v "$sqlcmd_bin" >/dev/null

if [[ ! "$credential_url" =~ ^https://[A-Za-z0-9.-]+/[A-Za-z0-9_-]+$ ]]; then
    printf 'BACKUP_CREDENTIAL_URL must identify one HTTPS Blob container.\n' >&2
    exit 2
fi

sas_token=${AZURE_STORAGE_SAS_TOKEN#\?}
if [[ -z "$sas_token" || "$sas_token" == *$'\n'* || "$sas_token" == *$'\r'* ]]; then
    printf 'AZURE_STORAGE_SAS_TOKEN must be a non-empty, single-line token.\n' >&2
    exit 1
fi

escaped_sas=${sas_token//\'/\'\'}
escaped_url=${credential_url//\'/\'\'}
credential_identifier=$credential_url

sqlcmd_options=(
    -S "$SQL_SERVER"
    -d master
    -U "$SQL_USER"
    -N
    -l 60
    -b
    -r 1
    -W
)

if [[ "${SQLCMD_TRUST_SERVER_CERTIFICATE:-0}" == "1" ]]; then
    sqlcmd_options+=(-C)
fi

printf '%s\n' "
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF EXISTS
(
    SELECT 1
    FROM sys.credentials
    WHERE name = N'$escaped_url'
)
    THROW 50100, 'The Blob backup credential already exists.', 1;

CREATE CREDENTIAL [$credential_identifier]
WITH
(
    IDENTITY = N'SHARED ACCESS SIGNATURE',
    SECRET = N'$escaped_sas'
);

SELECT name, credential_identity
FROM sys.credentials
WHERE name = N'$escaped_url';
" | "$sqlcmd_bin" "${sqlcmd_options[@]}"

unset escaped_sas sas_token
