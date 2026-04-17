# Data Virtualization Demos

A collection of demos showcasing **Data Virtualization** capabilities in SQL — query external data sources (Parquet, CSV, etc.) directly using `OPENROWSET`, external tables, and related features without moving data.

## Demos

| Demo | Platform | Description |
|------|----------|-------------|
| [Seattle Safety](AzureSQLDatabase/SeattleSafety/) | Azure SQL Database | End-to-end walkthrough using a public 911 dispatch dataset: ad-hoc exploration with `OPENROWSET`, schema discovery, `filepath()`/`filename()`, data ingestion, external tables, hybrid queries, geospatial analysis, and hot/cold data tiering. |

## Getting Started

1. Provision an **Azure SQL Database** — Data Virtualization is **enabled by default** on Azure SQL Database, no `sp_configure` needed. (Only required for SQL Server on-prem / Managed Instance. See [Data virtualization overview](https://learn.microsoft.com/azure/azure-sql/database/data-virtualization-overview).)
2. Open the demo folder and run the scripts in order (01 → 05)
3. Each script is self-contained with comments explaining every step
4. No storage credentials are needed — all demo data lives in public blob containers

## Object naming convention

Scripts follow a consistent suffix convention so each object's tier is obvious:

| Suffix | Meaning |
|--------|---------|
| `_Local`    | Local table (fully ingested) |
| `_External` | External table (remote Parquet, full dataset) |
| `_Hot`      | Local table (recent data, indexed) |
| `_Cold`     | External table (historical data, remote) |
| `vw_..._Cold` | OPENROWSET view over cold data (supports `filepath()` partition elimination) |
| `vw_..._All`  | Unified view combining hot + cold |
