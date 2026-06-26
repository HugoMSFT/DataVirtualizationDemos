# US Population by ZIP Code

Data Virtualization demo for the [US Population by ZIP Code](https://learn.microsoft.com/azure/open-datasets/dataset-us-population-zip) Azure Open Dataset.

## Dataset details

| Property | Value |
|----------|-------|
| **Source** | Azure Open Datasets |
| **Doc** | https://learn.microsoft.com/azure/open-datasets/dataset-us-population-zip |
| **Storage account** | `azureopendatastorage` |
| **Container** | `censusdatacontainer` |
| **Path** | `release/us_population_zip/` |
| **Format** | Parquet |
| **Volume** | Decennial Census 2010; partitioned by year |
| **Partitioned by** | `censusYear` (folder keys, surfaced via `filepath()`) |

Storage is publicly readable (anonymous), so no `DATABASE SCOPED CREDENTIAL` is needed.

## Scripts

| Script | Purpose |
|--------|---------|
| [01-IngestData-OPENROWSET.sql](01-IngestData-OPENROWSET.sql) | Create the `UsPopulationByZip` database and ingest the data into `dbo.UsPopulationByZip_Local` with `OPENROWSET`. |
| [02-ExternalTable.sql](02-ExternalTable.sql) | Create the external data source, file format, and `dbo.UsPopulationByZip_External` external table. |
| [03-OpenRowsetVsExternal-Views.sql](03-OpenRowsetVsExternal-Views.sql) | Wrap both methods in views and compare `OPENROWSET` vs external table. |

Run them in order (`01` -> `02` -> `03`). On Azure SQL Database, run `01` step 1 against `master`, then reconnect to `[UsPopulationByZip]` for the rest.

## Columns

| Column | Parquet type | SQL type |
|--------|--------------|----------|
| `decennialTime` | string | VARCHAR(50) |
| `zipCode` | string | VARCHAR(50) |
| `population` | int | INT |
| `race` | string | VARCHAR(50) |
| `sex` | string | VARCHAR(50) |
| `minAge` | int | INT |
| `maxAge` | int | INT |
