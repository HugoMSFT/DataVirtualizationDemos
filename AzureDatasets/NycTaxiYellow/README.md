# NYC Taxi & Limousine - Yellow Taxi Trips

Data Virtualization demo for the [NYC Taxi & Limousine - Yellow Taxi Trips](https://learn.microsoft.com/azure/open-datasets/dataset-taxi-yellow) Azure Open Dataset.

> **Large dataset:** script `01` ingests a single month by default. Widen the `BULK` path to load more.

## Dataset details

| Property | Value |
|----------|-------|
| **Source** | Azure Open Datasets |
| **Doc** | https://learn.microsoft.com/azure/open-datasets/dataset-taxi-yellow |
| **Storage account** | `azureopendatastorage` |
| **Container** | `nyctlc` |
| **Path** | `yellow/` |
| **Format** | Parquet |
| **Volume** | ~1.5B rows / 50 GB (2009-2018); partitioned by puYear / puMonth |
| **Partitioned by** | `puYear`, `puMonth` (folder keys, surfaced via `filepath()`) |

Storage is publicly readable (anonymous), so no `DATABASE SCOPED CREDENTIAL` is needed.

## Scripts

| Script | Purpose |
|--------|---------|
| [01-IngestData-OPENROWSET.sql](01-IngestData-OPENROWSET.sql) | Create the `NycTaxiYellow` database and ingest the data into `dbo.NycTaxiYellow_Local` with `OPENROWSET`. |
| [02-ExternalTable.sql](02-ExternalTable.sql) | Create the external data source, file format, and `dbo.NycTaxiYellow_External` external table. |
| [03-OpenRowsetVsExternal-Views.sql](03-OpenRowsetVsExternal-Views.sql) | Wrap both methods in views and compare `OPENROWSET` vs external table. |

Run them in order (`01` -> `02` -> `03`). On Azure SQL Database, run `01` step 1 against `master`, then reconnect to `[NycTaxiYellow]` for the rest.

## Columns

| Column | Parquet type | SQL type |
|--------|--------------|----------|
| `vendorID` | string | VARCHAR(50) |
| `tpepPickupDateTime` | timestamp | DATETIME2(7) |
| `tpepDropoffDateTime` | timestamp | DATETIME2(7) |
| `passengerCount` | int | INT |
| `tripDistance` | double | FLOAT |
| `puLocationId` | string | VARCHAR(50) |
| `doLocationId` | string | VARCHAR(50) |
| `startLon` | double | FLOAT |
| `startLat` | double | FLOAT |
| `endLon` | double | FLOAT |
| `endLat` | double | FLOAT |
| `rateCodeId` | int | INT |
| `storeAndFwdFlag` | string | VARCHAR(50) |
| `paymentType` | string | VARCHAR(50) |
| `fareAmount` | double | FLOAT |
| `extra` | double | FLOAT |
| `mtaTax` | double | FLOAT |
| `improvementSurcharge` | string | VARCHAR(50) |
| `tipAmount` | double | FLOAT |
| `tollsAmount` | double | FLOAT |
| `totalAmount` | double | FLOAT |
