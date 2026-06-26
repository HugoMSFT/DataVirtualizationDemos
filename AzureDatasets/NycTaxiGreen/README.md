# NYC Taxi & Limousine - Green Taxi Trips

Data Virtualization demo for the [NYC Taxi & Limousine - Green Taxi Trips](https://learn.microsoft.com/azure/open-datasets/dataset-taxi-green) Azure Open Dataset.

> **Large dataset:** script `01` ingests a single month by default. Widen the `BULK` path to load more.

## Dataset details

| Property | Value |
|----------|-------|
| **Source** | Azure Open Datasets |
| **Doc** | https://learn.microsoft.com/azure/open-datasets/dataset-taxi-green |
| **Storage account** | `azureopendatastorage` |
| **Container** | `nyctlc` |
| **Path** | `green/` |
| **Format** | Parquet |
| **Volume** | ~80M rows / 2 GB; partitioned by puYear / puMonth |
| **Partitioned by** | `puYear`, `puMonth` (folder keys, surfaced via `filepath()`) |

Storage is publicly readable (anonymous), so no `DATABASE SCOPED CREDENTIAL` is needed.

## Scripts

| Script | Purpose |
|--------|---------|
| [01-IngestData-OPENROWSET.sql](01-IngestData-OPENROWSET.sql) | Create the `NycTaxiGreen` database and ingest the data into `dbo.NycTaxiGreen_Local` with `OPENROWSET`. |
| [02-ExternalTable.sql](02-ExternalTable.sql) | Create the external data source, file format, and `dbo.NycTaxiGreen_External` external table. |
| [03-OpenRowsetVsExternal-Views.sql](03-OpenRowsetVsExternal-Views.sql) | Wrap both methods in views and compare `OPENROWSET` vs external table. |

Run them in order (`01` -> `02` -> `03`). On Azure SQL Database, run `01` step 1 against `master`, then reconnect to `[NycTaxiGreen]` for the rest.

## Columns

| Column | Parquet type | SQL type |
|--------|--------------|----------|
| `vendorID` | int | INT |
| `lpepPickupDatetime` | timestamp | DATETIME2(7) |
| `lpepDropoffDatetime` | timestamp | DATETIME2(7) |
| `passengerCount` | int | INT |
| `tripDistance` | double | FLOAT |
| `puLocationId` | string | VARCHAR(50) |
| `doLocationId` | string | VARCHAR(50) |
| `pickupLongitude` | double | FLOAT |
| `pickupLatitude` | double | FLOAT |
| `dropoffLongitude` | double | FLOAT |
| `dropoffLatitude` | double | FLOAT |
| `rateCodeID` | int | INT |
| `storeAndFwdFlag` | string | VARCHAR(50) |
| `paymentType` | int | INT |
| `fareAmount` | double | FLOAT |
| `extra` | double | FLOAT |
| `mtaTax` | double | FLOAT |
| `improvementSurcharge` | string | VARCHAR(50) |
| `tipAmount` | double | FLOAT |
| `tollsAmount` | double | FLOAT |
| `ehailFee` | double | FLOAT |
| `totalAmount` | double | FLOAT |
| `tripType` | int | INT |
