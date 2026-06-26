# San Francisco Safety Data (311 + fire calls)

Data Virtualization demo for the [San Francisco Safety Data (311 + fire calls)](https://learn.microsoft.com/azure/open-datasets/dataset-san-francisco-safety) Azure Open Dataset.

## Dataset details

| Property | Value |
|----------|-------|
| **Source** | Azure Open Datasets |
| **Doc** | https://learn.microsoft.com/azure/open-datasets/dataset-san-francisco-safety |
| **Storage account** | `azureopendatastorage` |
| **Container** | `citydatacontainer` |
| **Path** | `Safety/Release/city=SanFrancisco/` |
| **Format** | Parquet |
| **Volume** | ~6M rows / 400 MB; daily updates |

Storage is publicly readable (anonymous), so no `DATABASE SCOPED CREDENTIAL` is needed.

## Scripts

| Script | Purpose |
|--------|---------|
| [01-IngestData-OPENROWSET.sql](01-IngestData-OPENROWSET.sql) | Create the `SanFranciscoSafety` database and ingest the data into `dbo.SanFranciscoSafety_Local` with `OPENROWSET`. |
| [02-ExternalTable.sql](02-ExternalTable.sql) | Create the external data source, file format, and `dbo.SanFranciscoSafety_External` external table. |
| [03-OpenRowsetVsExternal-Views.sql](03-OpenRowsetVsExternal-Views.sql) | Wrap both methods in views and compare `OPENROWSET` vs external table. |

Run them in order (`01` -> `02` -> `03`). On Azure SQL Database, run `01` step 1 against `master`, then reconnect to `[SanFranciscoSafety]` for the rest.

## Columns

| Column | Parquet type | SQL type |
|--------|--------------|----------|
| `dataType` | string | VARCHAR(50) |
| `dataSubtype` | string | VARCHAR(50) |
| `dateTime` | timestamp | DATETIME2(7) |
| `category` | string | VARCHAR(256) |
| `subcategory` | string | VARCHAR(256) |
| `status` | string | VARCHAR(256) |
| `address` | string | VARCHAR(500) |
| `latitude` | double | FLOAT |
| `longitude` | double | FLOAT |
| `source` | string | VARCHAR(50) |
| `extendedProperties` | string | VARCHAR(4000) |
