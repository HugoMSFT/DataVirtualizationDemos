# US National Employment, Hours and Earnings

Data Virtualization demo for the [US National Employment, Hours and Earnings](https://learn.microsoft.com/azure/open-datasets/dataset-us-national-employment-earnings) Azure Open Dataset.

## Dataset details

| Property | Value |
|----------|-------|
| **Source** | Azure Open Datasets |
| **Doc** | https://learn.microsoft.com/azure/open-datasets/dataset-us-national-employment-earnings |
| **Storage account** | `azureopendatastorage` |
| **Container** | `laborstatisticscontainer` |
| **Path** | `ehe_national/` |
| **Format** | Parquet |
| **Volume** | Parquet; ~26,000 series from 1939 |

Storage is publicly readable (anonymous), so no `DATABASE SCOPED CREDENTIAL` is needed.

## Scripts

| Script | Purpose |
|--------|---------|
| [01-IngestData-OPENROWSET.sql](01-IngestData-OPENROWSET.sql) | Create the `UsNationalEmploymentEarnings` database and ingest the data into `dbo.UsNationalEmploymentEarnings_Local` with `OPENROWSET`. |
| [02-ExternalTable.sql](02-ExternalTable.sql) | Create the external data source, file format, and `dbo.UsNationalEmploymentEarnings_External` external table. |
| [03-OpenRowsetVsExternal-Views.sql](03-OpenRowsetVsExternal-Views.sql) | Wrap both methods in views and compare `OPENROWSET` vs external table. |

Run them in order (`01` -> `02` -> `03`). On Azure SQL Database, run `01` step 1 against `master`, then reconnect to `[UsNationalEmploymentEarnings]` for the rest.

## Columns

| Column | Parquet type | SQL type |
|--------|--------------|----------|
| `data_type_code` | string | VARCHAR(50) |
| `industry_code` | string | VARCHAR(50) |
| `supersector_code` | string | VARCHAR(50) |
| `series_id` | string | VARCHAR(50) |
| `year` | int | INT |
| `period` | string | VARCHAR(50) |
| `value` | float | REAL |
| `footnote_codes` | string | VARCHAR(100) |
| `seasonal` | string | VARCHAR(50) |
| `series_title` | string | VARCHAR(512) |
| `supersector_name` | string | VARCHAR(512) |
| `industry_name` | string | VARCHAR(512) |
| `data_type_text` | string | VARCHAR(512) |
