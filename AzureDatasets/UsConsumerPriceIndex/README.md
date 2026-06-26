# US Consumer Price Index

Data Virtualization demo for the [US Consumer Price Index](https://learn.microsoft.com/azure/open-datasets/dataset-us-consumer-price-index) Azure Open Dataset.

## Dataset details

| Property | Value |
|----------|-------|
| **Source** | Azure Open Datasets |
| **Doc** | https://learn.microsoft.com/azure/open-datasets/dataset-us-consumer-price-index |
| **Storage account** | `azureopendatastorage` |
| **Container** | `laborstatisticscontainer` |
| **Path** | `cpi/` |
| **Format** | Parquet |
| **Volume** | Parquet; ~16,700 series, 25 years |

Storage is publicly readable (anonymous), so no `DATABASE SCOPED CREDENTIAL` is needed.

## Scripts

| Script | Purpose |
|--------|---------|
| [01-IngestData-OPENROWSET.sql](01-IngestData-OPENROWSET.sql) | Create the `UsConsumerPriceIndex` database and ingest the data into `dbo.UsConsumerPriceIndex_Local` with `OPENROWSET`. |
| [02-ExternalTable.sql](02-ExternalTable.sql) | Create the external data source, file format, and `dbo.UsConsumerPriceIndex_External` external table. |
| [03-OpenRowsetVsExternal-Views.sql](03-OpenRowsetVsExternal-Views.sql) | Wrap both methods in views and compare `OPENROWSET` vs external table. |

Run them in order (`01` -> `02` -> `03`). On Azure SQL Database, run `01` step 1 against `master`, then reconnect to `[UsConsumerPriceIndex]` for the rest.

## Columns

| Column | Parquet type | SQL type |
|--------|--------------|----------|
| `area_code` | string | VARCHAR(50) |
| `item_code` | string | VARCHAR(50) |
| `series_id` | string | VARCHAR(50) |
| `year` | int | INT |
| `period` | string | VARCHAR(50) |
| `value` | float | REAL |
| `footnote_codes` | string | VARCHAR(100) |
| `seasonal` | string | VARCHAR(50) |
| `periodicity_code` | string | VARCHAR(50) |
| `series_title` | string | VARCHAR(512) |
| `item_name` | string | VARCHAR(512) |
| `area_name` | string | VARCHAR(512) |
