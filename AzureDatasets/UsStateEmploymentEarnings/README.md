# US State Employment, Hours and Earnings

Data Virtualization demo for the [US State Employment, Hours and Earnings](https://learn.microsoft.com/azure/open-datasets/dataset-us-state-employment-earnings) Azure Open Dataset.

## Dataset details

| Property | Value |
|----------|-------|
| **Source** | Azure Open Datasets |
| **Doc** | https://learn.microsoft.com/azure/open-datasets/dataset-us-state-employment-earnings |
| **Storage account** | `azureopendatastorage` |
| **Container** | `laborstatisticscontainer` |
| **Path** | `ehe_state/` |
| **Format** | Parquet |
| **Volume** | Parquet; ~24,000 series from 1990 |

Storage is publicly readable (anonymous), so no `DATABASE SCOPED CREDENTIAL` is needed.

## Scripts

| Script | Purpose |
|--------|---------|
| [01-IngestData-OPENROWSET.sql](01-IngestData-OPENROWSET.sql) | Create the `UsStateEmploymentEarnings` database and ingest the data into `dbo.UsStateEmploymentEarnings_Local` with `OPENROWSET`. |
| [02-ExternalTable.sql](02-ExternalTable.sql) | Create the external data source, file format, and `dbo.UsStateEmploymentEarnings_External` external table. |
| [03-OpenRowsetVsExternal-Views.sql](03-OpenRowsetVsExternal-Views.sql) | Wrap both methods in views and compare `OPENROWSET` vs external table. |

Run them in order (`01` -> `02` -> `03`). On Azure SQL Database, run `01` step 1 against `master`, then reconnect to `[UsStateEmploymentEarnings]` for the rest.

## Columns

| Column | Parquet type | SQL type |
|--------|--------------|----------|
| `area_code` | string | VARCHAR(50) |
| `state_code` | string | VARCHAR(50) |
| `data_type_code` | string | VARCHAR(50) |
| `industry_code` | string | VARCHAR(50) |
| `supersector_code` | string | VARCHAR(50) |
| `series_id` | string | VARCHAR(50) |
| `year` | int | INT |
| `period` | string | VARCHAR(50) |
| `value` | float | REAL |
| `footnote_codes` | string | VARCHAR(100) |
| `seasonal` | string | VARCHAR(50) |
| `supersector_name` | string | VARCHAR(512) |
| `industry_name` | string | VARCHAR(512) |
| `data_type_text` | string | VARCHAR(512) |
| `state_name` | string | VARCHAR(512) |
| `area_name` | string | VARCHAR(512) |
