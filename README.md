# Data Virtualization Demos

A collection of demos showcasing **Data Virtualization** capabilities in SQL — query external data sources (Parquet, CSV, etc.) directly using `OPENROWSET`, external tables, and related features without moving data.

## Demos

| Demo | Platform | Description |
|------|----------|-------------|
| [TPC-H SF10 data virtualization](tpch_demos/) | SQL Server 2025 and Azure SQL Database | Consumer-ready public SF10 backups, BACPACs, and anonymous Parquet data with restore/import instructions, external tables, validation, schema references, and sample workload results. |
| [Seattle Safety](AzureSQLDatabase/SeattleSafety/) | Azure SQL Database | End-to-end walkthrough using a public 911 dispatch dataset: ad-hoc exploration with `OPENROWSET`, schema discovery, `filepath()`/`filename()`, data ingestion, external tables, hybrid queries, geospatial analysis, and hot/cold data tiering. |

## Getting Started

1. Choose a demo from the catalog and follow its README.
2. Provision the SQL target described by that demo.
3. Run the scripts in the documented order.
4. All source data is public; storage credentials are not required for reads.

## Object naming convention

The Seattle Safety scripts use a consistent suffix convention so each
object's tier is obvious:

| Suffix | Meaning |
|--------|---------|
| `_Local`    | Local table (fully ingested) |
| `_External` | External table (remote Parquet, full dataset) |
| `_Hot`      | Local table (recent data, indexed) |
| `_Cold`     | External table (historical data, remote) |
| `vw_..._Cold` | OPENROWSET view over cold data (supports `filepath()` partition elimination) |
| `vw_..._All`  | Unified view combining hot + cold |
