# NYC Taxi & Limousine - For-Hire Vehicle Trips

Data Virtualization demo for the [NYC Taxi & Limousine - For-Hire Vehicle Trips](https://learn.microsoft.com/azure/open-datasets/dataset-taxi-for-hire-vehicle) Azure Open Dataset.

> **Large dataset:** script `01` ingests a single month by default. Widen the `BULK` path to load more.

## Dataset details

| Property | Value |
|----------|-------|
| **Source** | Azure Open Datasets |
| **Doc** | https://learn.microsoft.com/azure/open-datasets/dataset-taxi-for-hire-vehicle |
| **Storage account** | `azureopendatastorage` |
| **Container** | `nyctlc` |
| **Path** | `fhv/` |
| **Format** | Parquet |
| **Volume** | ~500M rows / 5 GB; partitioned by puYear / puMonth |
| **Partitioned by** | `puYear`, `puMonth` (folder keys, surfaced via `filepath()`) |

Storage is publicly readable (anonymous), so no `DATABASE SCOPED CREDENTIAL` is needed.

## Scripts

| Script | Purpose |
|--------|---------|
| [01-IngestData-OPENROWSET.sql](01-IngestData-OPENROWSET.sql) | Create the `NycTaxiForHireVehicle` database and ingest the data into `dbo.NycTaxiForHireVehicle_Local` with `OPENROWSET`. |
| [02-ExternalTable.sql](02-ExternalTable.sql) | Create the external data source, file format, and `dbo.NycTaxiForHireVehicle_External` external table. |
| [03-OpenRowsetVsExternal-Views.sql](03-OpenRowsetVsExternal-Views.sql) | Wrap both methods in views and compare `OPENROWSET` vs external table. |

Run them in order (`01` -> `02` -> `03`). On Azure SQL Database, run `01` step 1 against `master`, then reconnect to `[NycTaxiForHireVehicle]` for the rest.

## Columns

| Column | Parquet type | SQL type |
|--------|--------------|----------|
| `dispatchBaseNum` | string | VARCHAR(50) |
| `pickupDateTime` | timestamp | DATETIME2(7) |
| `dropOffDateTime` | timestamp | DATETIME2(7) |
| `puLocationId` | string | VARCHAR(50) |
| `doLocationId` | string | VARCHAR(50) |
| `srFlag` | string | VARCHAR(50) |
