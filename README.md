# Data Virtualization Demos

A collection of demos showcasing **Data Virtualization** capabilities in SQL — query external data sources (Parquet, CSV, etc.) directly using `OPENROWSET`, external tables, and related features without moving data.

## Demos

| Demo | Platform | Description |
|------|----------|-------------|
| [Seattle Safety](AzureSQLDatabase/SeattleSafety/) | Azure SQL Database | End-to-end walkthrough using a public 911 dispatch dataset: ad-hoc exploration with `OPENROWSET`, schema discovery, `filepath()`/`filename()`, data ingestion, external tables, hybrid queries, and geospatial analysis. |

## Getting Started

1. Provision an **Azure SQL Database** with Data Virtualization enabled
2. Open the demo folder and run the scripts in order (01 → 04)
3. Each script is self-contained with comments explaining every step
