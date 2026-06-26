# US Labor Force Statistics

Data Virtualization demo for the [US Labor Force Statistics](https://learn.microsoft.com/azure/open-datasets/dataset-us-labor-force) Azure Open Dataset.

## Dataset details

| Property | Value |
|----------|-------|
| **Source** | Azure Open Datasets |
| **Doc** | https://learn.microsoft.com/azure/open-datasets/dataset-us-labor-force |
| **Storage account** | `azureopendatastorage` |
| **Container** | `laborstatisticscontainer` |
| **Path** | `lfs/` |
| **Format** | Parquet |
| **Volume** | Parquet; Current Population Survey series |

Storage is publicly readable (anonymous), so no `DATABASE SCOPED CREDENTIAL` is needed.

## Scripts

| Script | Purpose |
|--------|---------|
| [01-IngestData-OPENROWSET.sql](01-IngestData-OPENROWSET.sql) | Create the `UsLaborForceStatistics` database and ingest the data into `dbo.UsLaborForceStatistics_Local` with `OPENROWSET`. |
| [02-ExternalTable.sql](02-ExternalTable.sql) | Create the external data source, file format, and `dbo.UsLaborForceStatistics_External` external table. |
| [03-OpenRowsetVsExternal-Views.sql](03-OpenRowsetVsExternal-Views.sql) | Wrap both methods in views and compare `OPENROWSET` vs external table. |

Run them in order (`01` -> `02` -> `03`). On Azure SQL Database, run `01` step 1 against `master`, then reconnect to `[UsLaborForceStatistics]` for the rest.

## Columns

| Column | Parquet type | SQL type |
|--------|--------------|----------|
| `series_id` | string | VARCHAR(50) |
| `year` | int | INT |
| `period` | string | VARCHAR(50) |
| `value` | float | REAL |
| `footnote_codes` | string | VARCHAR(100) |
| `lfst_code` | int | INT |
| `periodicity_code` | string | VARCHAR(50) |
| `series_title` | string | VARCHAR(512) |
| `absn_code` | int | INT |
| `activity_code` | int | INT |
| `ages_code` | int | INT |
| `cert_code` | int | INT |
| `class_code` | int | INT |
| `duration_code` | int | INT |
| `education_code` | int | INT |
| `entr_code` | int | INT |
| `expr_code` | int | INT |
| `hheader_code` | int | INT |
| `hour_code` | int | INT |
| `indy_code` | int | INT |
| `jdes_code` | int | INT |
| `look_code` | int | INT |
| `mari_code` | int | INT |
| `mjhs_code` | int | INT |
| `occupation_code` | int | INT |
| `orig_code` | int | INT |
| `pcts_code` | int | INT |
| `race_code` | int | INT |
| `rjnw_code` | int | INT |
| `rnlf_code` | int | INT |
| `rwns_code` | int | INT |
| `seek_code` | int | INT |
| `sexs_code` | int | INT |
| `tdat_code` | int | INT |
| `vets_code` | int | INT |
| `wkst_code` | int | INT |
| `born_code` | int | INT |
| `chld_code` | int | INT |
| `disa_code` | int | INT |
| `seasonal` | string | VARCHAR(50) |
