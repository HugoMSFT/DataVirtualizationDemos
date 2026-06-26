# US Producer Price Index - Commodities

Data Virtualization demo for the [US Producer Price Index - Commodities](https://learn.microsoft.com/azure/open-datasets/dataset-us-producer-price-index-commodities) Azure Open Dataset.

## Dataset details

| Property | Value |
|----------|-------|
| **Source** | Azure Open Datasets |
| **Doc** | https://learn.microsoft.com/azure/open-datasets/dataset-us-producer-price-index-commodities |
| **Storage account** | `azureopendatastorage` |
| **Container** | `laborstatisticscontainer` |
| **Path** | `ppi_commodity/` |
| **Format** | Parquet |
| **Volume** | Parquet; ~5,500 series |

Storage is publicly readable (anonymous), so no `DATABASE SCOPED CREDENTIAL` is needed.

## Scripts

| Script | Purpose |
|--------|---------|
| [01-IngestData-OPENROWSET.sql](01-IngestData-OPENROWSET.sql) | Create the `UsProducerPriceIndexCommodities` database and ingest the data into `dbo.UsProducerPriceIndexCommodities_Local` with `OPENROWSET`. |
| [02-ExternalTable.sql](02-ExternalTable.sql) | Create the external data source, file format, and `dbo.UsProducerPriceIndexCommodities_External` external table. |
| [03-OpenRowsetVsExternal-Views.sql](03-OpenRowsetVsExternal-Views.sql) | Wrap both methods in views and compare `OPENROWSET` vs external table. |

Run them in order (`01` -> `02` -> `03`). On Azure SQL Database, run `01` step 1 against `master`, then reconnect to `[UsProducerPriceIndexCommodities]` for the rest.

## Columns

| Column | Parquet type | SQL type |
|--------|--------------|----------|
| `item_code` | string | VARCHAR(50) |
| `group_code` | string | VARCHAR(50) |
| `series_id` | string | VARCHAR(50) |
| `year` | int | INT |
| `period` | string | VARCHAR(50) |
| `value` | float | REAL |
| `footnote_codes` | string | VARCHAR(100) |
| `seasonal` | string | VARCHAR(50) |
| `series_title` | string | VARCHAR(512) |
| `group_name` | string | VARCHAR(512) |
| `item_name` | string | VARCHAR(512) |
