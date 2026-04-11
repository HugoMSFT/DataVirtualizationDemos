# Seattle Safety — Data Virtualization Demo

Demonstrates **Data Virtualization** in Azure SQL Database using the [Seattle Safety](https://learn.microsoft.com/en-us/azure/open-datasets/dataset-seattle-safety) public dataset (Seattle Fire Department 911 dispatches, ~800K rows in Parquet format).

## Prerequisites

- An Azure SQL Database with **Data Virtualization** enabled
- No storage credentials needed — the dataset is publicly accessible

## Demo Scripts

| Script | Description |
|--------|-------------|
| [01-AdHocExploration.sql](01-AdHocExploration.sql) | Query Parquet files directly with `OPENROWSET`. Discover schema with `sp_describe_first_result_set`, explore data with aggregations, use `WITH` clause for schema definition, inspect file metadata with `filepath()` and `filename()`. |
| [02-IngestData.sql](02-IngestData.sql) | Ingest the full dataset into a local table using `SELECT INTO`, add indexes, and query locally. |
| [03-ExternalTables.sql](03-ExternalTables.sql) | Create persistent external data source, file format, and external table. Hybrid join between external Parquet data and a local lookup table. Schema introspection on external objects. |
| [04-AdvancedFeatures.sql](04-AdvancedFeatures.sql) | Schema discovery via `dm_exec_describe_first_result_set` DMV, geospatial queries (`geography::Point`, distance calculations) on virtualized data, execution plan and external work DMV introspection. |
| [05-DataTiering.sql](05-DataTiering.sql) | Hot/cold data tiering strategy. Ingest recent data (2025-2026) locally via `OPENROWSET` with a `WHERE` filter, keep older years as external tables in the `cold` schema, and unify everything behind a single view. |

## Dataset Details

| Property | Value |
|----------|-------|
| **Source** | Azure Open Datasets |
| **Storage Account** | `azureopendatastorage` |
| **Container** | `citydatacontainer` |
| **Path** | `Safety/Release/city=Seattle/` |
| **Format** | Parquet |

### Columns

| Column | Type | Description |
|--------|------|-------------|
| `address` | string | Location of the incident |
| `category` | string | Response type (Aid Response, Medic Response, etc.) |
| `dataSubtype` | string | Always `911_Fire` |
| `dataType` | string | Always `Safety` |
| `dateTime` | timestamp | Date and time of the call |
| `latitude` | double | Latitude of the incident |
| `longitude` | double | Longitude of the incident |
