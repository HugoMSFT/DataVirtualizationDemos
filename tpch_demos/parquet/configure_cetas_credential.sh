#!/usr/bin/env bash
set -euo pipefail

database_name=${1:?Usage: configure_cetas_credential.sh <database-name>}

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
command -v "$sqlcmd_bin" >/dev/null
command -v openssl >/dev/null

sas_token=${AZURE_STORAGE_SAS_TOKEN#\?}
if [[ -z "$sas_token" || "$sas_token" == *$'\n'* || "$sas_token" == *$'\r'* ]]; then
    printf 'AZURE_STORAGE_SAS_TOKEN must be a non-empty, single-line token.\n' >&2
    exit 1
fi

master_key_password=${DATABASE_MASTER_KEY_PASSWORD:-}
if [[ -z "$master_key_password" ]]; then
    master_key_password="Cetas-$(openssl rand -hex 28)-aA1!"
fi

escaped_sas=${sas_token//\'/\'\'}
escaped_master_key=${master_key_password//\'/\'\'}

sqlcmd_options=(
    -S "$SQL_SERVER"
    -d "$database_name"
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
    FROM sys.database_scoped_credentials
    WHERE name = N'__tpch_blob_credential'
)
    THROW 50201, 'Temporary CETAS credential already exists.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.external_data_sources
    WHERE name = N'__tpch_blob_source'
)
    THROW 50202, 'Temporary CETAS data source already exists.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.external_file_formats
    WHERE name = N'__tpch_parquet_format'
)
    THROW 50203, 'Temporary CETAS file format already exists.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.symmetric_keys
    WHERE name = N'##MS_DatabaseMasterKey##'
)
    EXEC
    (
        N'CREATE MASTER KEY ENCRYPTION BY PASSWORD = N''$escaped_master_key''';'
    );

CREATE DATABASE SCOPED CREDENTIAL [__tpch_blob_credential]
WITH
(
    IDENTITY = N'SHARED ACCESS SIGNATURE',
    SECRET = N'$escaped_sas'
);

CREATE EXTERNAL DATA SOURCE [__tpch_blob_source]
WITH
(
    LOCATION = N'abs://tpch@tpcpublicstorage.blob.core.windows.net/',
    CREDENTIAL = [__tpch_blob_credential]
);

CREATE EXTERNAL FILE FORMAT [__tpch_parquet_format]
WITH
(
    FORMAT_TYPE = PARQUET
);

SELECT
    DB_NAME() AS database_name,
    (SELECT COUNT(*) FROM sys.database_scoped_credentials
     WHERE name = N'__tpch_blob_credential') AS credentials,
    (SELECT COUNT(*) FROM sys.external_data_sources
     WHERE name = N'__tpch_blob_source') AS data_sources,
    (SELECT COUNT(*) FROM sys.external_file_formats
     WHERE name = N'__tpch_parquet_format') AS file_formats;
" | "$sqlcmd_bin" "${sqlcmd_options[@]}"

unset escaped_sas escaped_master_key master_key_password sas_token
