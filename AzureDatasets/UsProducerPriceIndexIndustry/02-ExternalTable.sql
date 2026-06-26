-- =============================================================================
-- Step 4.b - External Table over the Parquet files
-- Dataset: US Producer Price Index - Industry
-- Source:  https://learn.microsoft.com/azure/open-datasets/dataset-us-producer-price-index-industry
-- Storage: abs://laborstatisticscontainer@azureopendatastorage.blob.core.windows.net/ppi_industry/  (public, anonymous read - no credential required)
-- Platform: Azure SQL Database (Data Virtualization enabled by default)
-- =============================================================================
-- Goal: expose the remote Parquet as a regular table via an external data
--       source + file format + CREATE EXTERNAL TABLE. End users query it with
--       plain SELECT - no OPENROWSET, no storage URLs.
-- Run this script connected to the [UsProducerPriceIndexIndustry] database (created in 01).
-- =============================================================================

-- =============================================================================
-- Step 1: External data source (points at the dataset's storage folder)
-- =============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.external_data_sources WHERE name = 'UsProducerPriceIndexIndustryDS')
    CREATE EXTERNAL DATA SOURCE UsProducerPriceIndexIndustryDS
    WITH (
        LOCATION = 'abs://laborstatisticscontainer@azureopendatastorage.blob.core.windows.net/ppi_industry'
    );
GO

-- =============================================================================
-- Step 2: External file format (Parquet)
-- =============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.external_file_formats WHERE name = 'ParquetFormat')
    CREATE EXTERNAL FILE FORMAT ParquetFormat
    WITH (
        FORMAT_TYPE = PARQUET
    );
GO

-- =============================================================================
-- Step 3: External table (explicit schema - matches the Parquet physical types)
-- =============================================================================
-- LOCATION '/' is relative to the data source and reads every Parquet file
-- under the folder (PolyBase skips paths beginning with '_' or '.').
IF OBJECT_ID('dbo.UsProducerPriceIndexIndustry_External') IS NOT NULL
    DROP EXTERNAL TABLE dbo.UsProducerPriceIndexIndustry_External;
GO

CREATE EXTERNAL TABLE dbo.UsProducerPriceIndexIndustry_External
(
    [product_code]   VARCHAR(50),
    [industry_code]  VARCHAR(50),
    [series_id]      VARCHAR(50),
    [year]           INT,
    [period]         VARCHAR(50),
    [value]          REAL,
    [footnote_codes] VARCHAR(100),
    [seasonal]       VARCHAR(50),
    [series_title]   VARCHAR(512),
    [industry_name]  VARCHAR(512),
    [product_name]   VARCHAR(512)
)
WITH (
    DATA_SOURCE = UsProducerPriceIndexIndustryDS,
    LOCATION    = '/',
    FILE_FORMAT = ParquetFormat
);
GO

-- Statistics give the optimizer accurate cardinality estimates. External
-- tables only support FULLSCAN (the engine scans the remote data once).
CREATE STATISTICS ST_UsProducerPriceIndexIndustry_series_id ON dbo.UsProducerPriceIndexIndustry_External ([series_id]) WITH FULLSCAN;
CREATE STATISTICS ST_UsProducerPriceIndexIndustry_year ON dbo.UsProducerPriceIndexIndustry_External ([year]) WITH FULLSCAN;
CREATE STATISTICS ST_UsProducerPriceIndexIndustry_period ON dbo.UsProducerPriceIndexIndustry_External ([period]) WITH FULLSCAN;
GO

-- =============================================================================
-- Step 4: Query the external table - just like a regular table
-- =============================================================================
SELECT TOP 50 *
FROM dbo.UsProducerPriceIndexIndustry_External;
GO

-- Inspect the external table definition
SELECT c.column_id, c.name, t.name AS data_type, c.max_length
FROM sys.external_table_columns AS c
JOIN sys.types AS t ON c.user_type_id = t.user_type_id
WHERE c.object_id = OBJECT_ID('dbo.UsProducerPriceIndexIndustry_External')
ORDER BY c.column_id;
GO
