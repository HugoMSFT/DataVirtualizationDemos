# Azure Open Datasets &mdash; Data Virtualization Demos

Load [Azure Open Datasets](https://learn.microsoft.com/azure/open-datasets/dataset-catalog)
into **Azure SQL Database** with **data virtualization** (`OPENROWSET` / PolyBase) &mdash;
no data movement pipeline required. Every dataset below lives in the public
`azureopendatastorage` storage account and allows anonymous read, so **no
`DATABASE SCOPED CREDENTIAL` is needed**.

Each included dataset gets its own folder with three scripts:

| Script | What it does |
|--------|--------------|
| `01-IngestData-OPENROWSET.sql` | Creates a database named after the dataset and ingests the Parquet into a local table with `OPENROWSET` (step **4.a**). |
| `02-ExternalTable.sql` | Creates an external data source + file format + `CREATE EXTERNAL TABLE` over the files (step **4.b**). |
| `03-OpenRowsetVsExternal-Views.sql` | Wraps both methods in views to compare `OPENROWSET` vs the external table (step **4.c**). |

## Which datasets make sense in SQL?

Rule of thumb: **if a dataset is tabular Parquet/CSV and ships an Azure Synapse
example, it is almost always worth loading into SQL.** Image, audio, and
free-text/ML datasets are skipped &mdash; they aren't relational and gain nothing
from a SQL engine.

| Dataset | Category | Load into SQL? | Notes |
|---------|----------|:--------------:|-------|
| [TartanAir: AirSim Simulation](https://learn.microsoft.com/azure/open-datasets/dataset-tartanair-simulation) | Transportation | &#10060; No | Robotics/SLAM simulation (images, depth, IMU). Binary blobs, not relational. |
| [NYC Taxi - Yellow](./NycTaxiYellow/) | Transportation | &#9989; Yes | Parquet trip records. Partitioned by year/month. **Included.** |
| [NYC Taxi - Green](./NycTaxiGreen/) | Transportation | &#9989; Yes | Parquet trip records. Partitioned by year/month. **Included.** |
| [NYC Taxi - For-Hire Vehicle](./NycTaxiForHireVehicle/) | Transportation | &#9989; Yes | Parquet trip records. Partitioned by year/month. **Included.** |
| [COVID-19 Data Lake](https://learn.microsoft.com/azure/open-datasets/dataset-covid-19-data-lake) | Health & genomics | &#9888;&#65039; Partial | A *collection* of sub-datasets in mixed formats (CSV/JSON/Parquet). Individual tabular tables load fine; pick a specific one rather than the whole lake. |
| [US Labor Force Statistics](./UsLaborForceStatistics/) | Labor & economics | &#9989; Yes | Parquet, BLS series. **Included.** |
| [US National Employment, Hours & Earnings](./UsNationalEmploymentEarnings/) | Labor & economics | &#9989; Yes | Parquet, BLS series. **Included.** |
| [US State Employment, Hours & Earnings](./UsStateEmploymentEarnings/) | Labor & economics | &#9989; Yes | Parquet, BLS series. **Included.** |
| [US Local Area Unemployment](./UsLocalAreaUnemployment/) | Labor & economics | &#9989; Yes | Parquet, BLS series. **Included.** |
| [US Consumer Price Index](./UsConsumerPriceIndex/) | Labor & economics | &#9989; Yes | Parquet, BLS series. **Included.** |
| [US Producer Price Index - Industry](./UsProducerPriceIndexIndustry/) | Labor & economics | &#9989; Yes | Parquet, BLS series. **Included.** |
| [US Producer Price Index - Commodities](./UsProducerPriceIndexCommodities/) | Labor & economics | &#9989; Yes | Parquet, BLS series. **Included.** |
| [US Population by County](./UsPopulationByCounty/) | Population & safety | &#9989; Yes | Parquet, Decennial Census. Partitioned by year. **Included.** |
| [US Population by ZIP Code](./UsPopulationByZip/) | Population & safety | &#9989; Yes | Parquet, Decennial Census. Partitioned by year. **Included.** |
| [Boston Safety](./BostonSafety/) | Population & safety | &#9989; Yes | Parquet 311 calls. **Included.** |
| [Chicago Safety](./ChicagoSafety/) | Population & safety | &#9989; Yes | Parquet 311 calls. **Included.** |
| [New York City Safety](./NewYorkCitySafety/) | Population & safety | &#9989; Yes | Parquet 311 calls. **Included.** |
| [San Francisco Safety](./SanFranciscoSafety/) | Population & safety | &#9989; Yes | Parquet 311 + fire calls. **Included.** |
| [Seattle Safety](../AzureSQLDatabase/SeattleSafety/) | Population & safety | &#9989; Yes | Parquet 911 dispatches. Covered by the dedicated **SeattleSafety** demo. |
| [Diabetes](https://learn.microsoft.com/azure/open-datasets/dataset-diabetes) | Supplemental | &#10060; No | 442-row ML toy set delivered through the SDK, not exposed as queryable Parquet in the open container. |
| [OJ Sales Simulated](https://learn.microsoft.com/azure/open-datasets/dataset-oj-sales-simulated) | Supplemental | &#9888;&#65039; Marginal | Tabular CSV but built for *many-models* ML (thousands of tiny files). Works with `OPENROWSET`/CSV, but limited analytical value. |
| [MNIST](https://learn.microsoft.com/azure/open-datasets/dataset-mnist) | Supplemental | &#10060; No | Handwritten-digit image pixels. Not relational. |
| [Microsoft News (MIND)](https://learn.microsoft.com/azure/open-datasets/dataset-microsoft-news) | Supplemental | &#10060; No | Large news/click text corpus for recommender research. NLP-oriented, not a SQL analytics fit. |
| [Public Holidays](./PublicHolidays/) | Supplemental | &#9989; Yes | Parquet, 38 countries 1970-2099. **Included.** |
| [Russian Open Speech To Text](https://learn.microsoft.com/azure/open-datasets/dataset-open-speech-text) | Supplemental | &#10060; No | Audio + transcripts. Binary audio, not relational. |

**18 of 25** catalog datasets are a natural fit for SQL
(17 scripted here + the existing SeattleSafety demo).

## Included datasets

| Dataset | Container | Format | Database created |
|---------|-----------|--------|------------------|
| [NYC Taxi & Limousine - Yellow Taxi Trips](./NycTaxiYellow/) | `nyctlc` | Parquet | `NycTaxiYellow` |
| [NYC Taxi & Limousine - Green Taxi Trips](./NycTaxiGreen/) | `nyctlc` | Parquet | `NycTaxiGreen` |
| [NYC Taxi & Limousine - For-Hire Vehicle Trips](./NycTaxiForHireVehicle/) | `nyctlc` | Parquet | `NycTaxiForHireVehicle` |
| [US Labor Force Statistics](./UsLaborForceStatistics/) | `laborstatisticscontainer` | Parquet | `UsLaborForceStatistics` |
| [US National Employment, Hours and Earnings](./UsNationalEmploymentEarnings/) | `laborstatisticscontainer` | Parquet | `UsNationalEmploymentEarnings` |
| [US State Employment, Hours and Earnings](./UsStateEmploymentEarnings/) | `laborstatisticscontainer` | Parquet | `UsStateEmploymentEarnings` |
| [US Local Area Unemployment Statistics](./UsLocalAreaUnemployment/) | `laborstatisticscontainer` | Parquet | `UsLocalAreaUnemployment` |
| [US Consumer Price Index](./UsConsumerPriceIndex/) | `laborstatisticscontainer` | Parquet | `UsConsumerPriceIndex` |
| [US Producer Price Index - Industry](./UsProducerPriceIndexIndustry/) | `laborstatisticscontainer` | Parquet | `UsProducerPriceIndexIndustry` |
| [US Producer Price Index - Commodities](./UsProducerPriceIndexCommodities/) | `laborstatisticscontainer` | Parquet | `UsProducerPriceIndexCommodities` |
| [US Population by County](./UsPopulationByCounty/) | `censusdatacontainer` | Parquet | `UsPopulationByCounty` |
| [US Population by ZIP Code](./UsPopulationByZip/) | `censusdatacontainer` | Parquet | `UsPopulationByZip` |
| [Boston Safety Data (311 calls)](./BostonSafety/) | `citydatacontainer` | Parquet | `BostonSafety` |
| [Chicago Safety Data (311 calls)](./ChicagoSafety/) | `citydatacontainer` | Parquet | `ChicagoSafety` |
| [New York City Safety Data (311 calls)](./NewYorkCitySafety/) | `citydatacontainer` | Parquet | `NewYorkCitySafety` |
| [San Francisco Safety Data (311 + fire calls)](./SanFranciscoSafety/) | `citydatacontainer` | Parquet | `SanFranciscoSafety` |
| [Public Holidays](./PublicHolidays/) | `holidaydatacontainer` | Parquet | `PublicHolidays` |

## How to run (Azure SQL Database)

1. Open the dataset folder you want and start with `01-IngestData-OPENROWSET.sql`.
2. **Step 1 of `01` runs against `master`** to `CREATE DATABASE`. Azure SQL Database
   does not support `USE` to switch databases &mdash; reconnect a new query window to
   the new database, then run the rest of `01`, followed by `02` and `03`.
3. Data Virtualization is enabled by default on Azure SQL Database (no
   `sp_configure`). For SQL Server / Managed Instance, enable PolyBase first.

## Object naming convention

| Object | Pattern |
|--------|---------|
| Database | `<DatasetName>` |
| Local (ingested) table | `dbo.<DatasetName>_Local` |
| External table | `dbo.<DatasetName>_External` |
| OPENROWSET view | `dbo.vw_<DatasetName>_OpenRowset` |
| External-table view | `dbo.vw_<DatasetName>_External` |
| External data source | `<DatasetName>DS` |
| External file format | `ParquetFormat` |

## A note on large datasets

The NYC Taxi sources are 10s of GB. Their `01` script ingests a single
month by default (widen the `BULK` path to load more), while `02`/`03` expose the
full dataset remotely. Partition-folder columns (`puYear`, `puMonth`, census
`year`) are surfaced through `filepath()` in the OPENROWSET views to demonstrate
**partition elimination**.
