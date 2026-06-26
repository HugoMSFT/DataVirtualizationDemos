# US Local Area Unemployment Statistics

Data Virtualization demo for the [US Local Area Unemployment Statistics](https://learn.microsoft.com/azure/open-datasets/dataset-us-local-unemployment) Azure Open Dataset.

## Dataset details

| Property | Value |
|----------|-------|
| **Source** | Azure Open Datasets |
| **Doc** | https://learn.microsoft.com/azure/open-datasets/dataset-us-local-unemployment |
| **Storage account** | `azureopendatastorage` |
| **Container** | `laborstatisticscontainer` |
| **Path** | `laus/` |
| **Format** | Parquet |
| **Volume** | Parquet; ~33,000 series from 2000 |

Storage is publicly readable (anonymous), so no `DATABASE SCOPED CREDENTIAL` is needed.

## Scripts

| Script | Purpose |
|--------|---------|
| [01-IngestData-OPENROWSET.sql](01-IngestData-OPENROWSET.sql) | Create the `UsLocalAreaUnemployment` database and ingest the data into `dbo.UsLocalAreaUnemployment_Local` with `OPENROWSET`. |
| [02-ExternalTable.sql](02-ExternalTable.sql) | Create the external data source, file format, and `dbo.UsLocalAreaUnemployment_External` external table. |
| [03-OpenRowsetVsExternal-Views.sql](03-OpenRowsetVsExternal-Views.sql) | Wrap both methods in views and compare `OPENROWSET` vs external table. |

Run them in order (`01` -> `02` -> `03`). On Azure SQL Database, run `01` step 1 against `master`, then reconnect to `[UsLocalAreaUnemployment]` for the rest.

## Columns

| Column | Parquet type | SQL type |
|--------|--------------|----------|
| `area_code` | string | VARCHAR(50) |
| `area_type_code` | string | VARCHAR(50) |
| `srd_code` | string | VARCHAR(50) |
| `measure_code` | string | VARCHAR(50) |
| `series_id` | string | VARCHAR(50) |
| `year` | int | INT |
| `period` | string | VARCHAR(50) |
| `value` | float | REAL |
| `footnote_codes` | string | VARCHAR(100) |
| `seasonal` | string | VARCHAR(50) |
| `series_title` | string | VARCHAR(512) |
| `measure_text` | string | VARCHAR(512) |
| `srd_text` | string | VARCHAR(512) |
| `areatype_text` | string | VARCHAR(512) |
| `area_text` | string | VARCHAR(512) |
