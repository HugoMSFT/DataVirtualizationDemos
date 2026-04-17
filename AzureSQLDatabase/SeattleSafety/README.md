# Seattle Safety — Data Virtualization Demo

Demonstrates **Data Virtualization** in Azure SQL Database using the [Seattle Safety](https://learn.microsoft.com/en-us/azure/open-datasets/dataset-seattle-safety) public dataset (Seattle Fire Department 911 dispatches, ~1.87M rows in Parquet format, 2003–2023).

## Prerequisites

- An **Azure SQL Database** — Data Virtualization is enabled by default (no `sp_configure` required; that step is only for SQL Server on-prem / Managed Instance).
- No storage credentials needed — both demo containers are publicly accessible.

## Data sources used

| Source | Used by | Notes |
|--------|---------|-------|
| `abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=Seattle/` | 01–04 | Canonical Azure Open Dataset. Flat layout (no year partitions). |
| `abs://publiclake.blob.core.windows.net/seattlesafety/year=YYYY/` | 05, 05b | Year-partitioned copy of the same data hosted in a public Azure Storage account owned by the demo author. Used to showcase partition elimination with `filepath()` and one external table per folder. |

Both containers allow anonymous read, so no `DATABASE SCOPED CREDENTIAL` is needed. For private storage, see [CREATE DATABASE SCOPED CREDENTIAL](https://learn.microsoft.com/sql/t-sql/statements/create-database-scoped-credential-transact-sql).

## Object naming convention

| Suffix | Meaning |
|--------|---------|
| `_Local`    | Local table (full ingest) |
| `_External` | External table (remote Parquet, full dataset) |
| `_Hot`      | Local table (recent data, indexed) |
| `_Cold`     | External table (historical data, remote) |
| `vw_..._Cold` / `vw_..._All` | OPENROWSET / unified views over the tiers |

## Demo Scripts

| Script | Description |
|--------|-------------|
| [01-AdHocExploration.sql](01-AdHocExploration.sql) | Query Parquet files directly with `OPENROWSET`. Discover schema via automatic inference and `sp_describe_first_result_set`, explore data with aggregations, and inspect file metadata with `filepath()` and `filename()`. |
| [02-IngestData.sql](02-IngestData.sql) | Ingest the full dataset into `dbo.SeattleSafety_Local` using `SELECT INTO`, add indexes, and compare remote vs local query performance. |
| [03-ExternalTables.sql](03-ExternalTables.sql) | Create persistent external data source, file format, and external table. Introduce the explicit `WITH` schema clause, join external Parquet with a local lookup, and inspect external-object metadata. |
| [04-AdvancedFeatures.sql](04-AdvancedFeatures.sql) | Schema discovery via `dm_exec_describe_first_result_set` DMV, geospatial queries on virtualized data, and predicate-pushdown evidence via `dm_exec_external_work`. |
| [05-DataTiering.sql](05-DataTiering.sql) | Hot/cold tiering. Ingest the most-recent year into a local `_Hot` table via folder-targeted `OPENROWSET`, keep older years as an external `_Cold` table, and unify both behind a single view. Standalone — does not depend on 02. |
| [05b-PerformanceTests.sql](05b-PerformanceTests.sql) | Side-by-side perf comparisons: folder-targeted OPENROWSET vs `YEAR()` filter, explicit `WITH` vs schema inference, statistics on/off, and partition elimination via `filepath()`. |
| [demo-script.md](demo-script.md) | Presenter notes — narration flow, what to highlight, expected audience reactions. |

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
