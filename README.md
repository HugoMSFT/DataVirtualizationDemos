# Data Virtualization Demos

A collection of demos showcasing
[**Data Virtualization**](https://learn.microsoft.com/en-us/sql/relational-databases/polybase/data-virtualization-guide?view=sql-server-ver17)
capabilities in SQL: query external data sources such as Parquet and CSV
directly using `OPENROWSET`, external tables, and related features without
moving data.

## Demos

| Demo | Platform | Description |
|------|----------|-------------|
| [HammerDB TPROC-H SF10 data virtualization](tpch_demos/) | SQL Server 2025 and Azure SQL Database | Public TPROC-H-generated SF10 backups, BACPACs, and anonymous Parquet data with restore/import instructions, validation, and sample workload results. This is not an official TPC-H data set or benchmark. |
| [Seattle Safety](AzureSQLDatabase/SeattleSafety/) | Azure SQL Database | End-to-end walkthrough using a public 911 dispatch dataset: ad-hoc exploration with `OPENROWSET`, schema discovery, `filepath()`/`filename()`, data ingestion, external tables, hybrid queries, geospatial analysis, and hot/cold data tiering. |

## Getting Started

1. Choose a demo from the catalog and follow its README.
2. Provision the SQL target described by that demo.
3. Run the scripts in the documented order.
4. All source data is public; storage credentials are not required for reads.

## Official Microsoft documentation

- [Connect, query, and export data with PolyBase](https://learn.microsoft.com/en-us/sql/relational-databases/polybase/data-virtualization-guide?view=sql-server-ver17)
- [PolyBase overview](https://learn.microsoft.com/en-us/sql/relational-databases/polybase/overview?view=sql-server-ver17)
- [`CREATE EXTERNAL DATA SOURCE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-external-data-source-transact-sql?view=sql-server-ver17)
- [`CREATE EXTERNAL FILE FORMAT`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-external-file-format-transact-sql?view=sql-server-ver17)
- [`CREATE EXTERNAL TABLE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-external-table-transact-sql?view=sql-server-ver17)

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
