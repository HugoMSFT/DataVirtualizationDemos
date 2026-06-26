# US Producer Price Index - Industry

Data Virtualization demo for the [US Producer Price Index - Industry](https://learn.microsoft.com/azure/open-datasets/dataset-us-producer-price-index-industry) Azure Open Dataset.

## Dataset details

| Property | Value |
|----------|-------|
| **Source** | Azure Open Datasets |
| **Doc** | https://learn.microsoft.com/azure/open-datasets/dataset-us-producer-price-index-industry |
| **Storage account** | `azureopendatastorage` |
| **Container** | `laborstatisticscontainer` |
| **Path** | `ppi_industry/` |
| **Format** | Parquet |
| **Volume** | Parquet; ~4,800 series |

Storage is publicly readable (anonymous), so no `DATABASE SCOPED CREDENTIAL` is needed.

## Scripts

| Script | Purpose |
|--------|---------|
| [01-IngestData-OPENROWSET.sql](01-IngestData-OPENROWSET.sql) | Create the `UsProducerPriceIndexIndustry` database and ingest the data into `dbo.UsProducerPriceIndexIndustry_Local` with `OPENROWSET`. |
| [02-ExternalTable.sql](02-ExternalTable.sql) | Create the external data source, file format, and `dbo.UsProducerPriceIndexIndustry_External` external table. |
| [03-OpenRowsetVsExternal-Views.sql](03-OpenRowsetVsExternal-Views.sql) | Wrap both methods in views and compare `OPENROWSET` vs external table. |

Run them in order (`01` -> `02` -> `03`). On Azure SQL Database, run `01` step 1 against `master`, then reconnect to `[UsProducerPriceIndexIndustry]` for the rest.

## Columns

| Column | Parquet type | SQL type |
|--------|--------------|----------|
| `product_code` | string | VARCHAR(50) |
| `industry_code` | string | VARCHAR(50) |
| `series_id` | string | VARCHAR(50) |
| `year` | int | INT |
| `period` | string | VARCHAR(50) |
| `value` | float | REAL |
| `footnote_codes` | string | VARCHAR(100) |
| `seasonal` | string | VARCHAR(50) |
| `series_title` | string | VARCHAR(512) |
| `industry_name` | string | VARCHAR(512) |
| `product_name` | string | VARCHAR(512) |
