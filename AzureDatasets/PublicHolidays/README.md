# Public Holidays

Data Virtualization demo for the [Public Holidays](https://learn.microsoft.com/azure/open-datasets/dataset-public-holidays) Azure Open Dataset.

## Dataset details

| Property | Value |
|----------|-------|
| **Source** | Azure Open Datasets |
| **Doc** | https://learn.microsoft.com/azure/open-datasets/dataset-public-holidays |
| **Storage account** | `azureopendatastorage` |
| **Container** | `holidaydatacontainer` |
| **Path** | `Processed/` |
| **Format** | Parquet |
| **Volume** | ~500 KB; 38 countries/regions, 1970-2099 |

Storage is publicly readable (anonymous), so no `DATABASE SCOPED CREDENTIAL` is needed.

## Scripts

| Script | Purpose |
|--------|---------|
| [01-IngestData-OPENROWSET.sql](01-IngestData-OPENROWSET.sql) | Create the `PublicHolidays` database and ingest the data into `dbo.PublicHolidays_Local` with `OPENROWSET`. |
| [02-ExternalTable.sql](02-ExternalTable.sql) | Create the external data source, file format, and `dbo.PublicHolidays_External` external table. |
| [03-OpenRowsetVsExternal-Views.sql](03-OpenRowsetVsExternal-Views.sql) | Wrap both methods in views and compare `OPENROWSET` vs external table. |

Run them in order (`01` -> `02` -> `03`). On Azure SQL Database, run `01` step 1 against `master`, then reconnect to `[PublicHolidays]` for the rest.

## Columns

| Column | Parquet type | SQL type |
|--------|--------------|----------|
| `countryOrRegion` | string | VARCHAR(256) |
| `holidayName` | string | VARCHAR(512) |
| `normalizeHolidayName` | string | VARCHAR(512) |
| `isPaidTimeOff` | bool | BIT |
| `countryRegionCode` | string | VARCHAR(50) |
| `date` | timestamp | DATETIME2(7) |
