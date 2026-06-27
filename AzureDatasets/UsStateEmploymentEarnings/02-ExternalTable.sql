-- =============================================================================
-- Step 4.b - External Table over the Parquet files
-- Dataset: US State Employment, Hours and Earnings
-- Source:  https://learn.microsoft.com/azure/open-datasets/dataset-us-state-employment-earnings
-- Storage: abs://laborstatisticscontainer@azureopendatastorage.blob.core.windows.net/ehe_state/  (public, anonymous read - no credential required)
-- Platform: Azure SQL Database (Data Virtualization enabled by default)
-- =============================================================================
-- Goal: expose the remote Parquet as a regular table via an external data
--       source + file format + CREATE EXTERNAL TABLE. End users query it with
--       plain SELECT - no OPENROWSET, no storage URLs.
-- Run this script connected to the [UsStateEmploymentEarnings] database (created in 01).
-- =============================================================================

-- =============================================================================
-- Step 1: External data source (points at the dataset's storage folder)
-- =============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.external_data_sources WHERE name = 'UsStateEmploymentEarningsDS')
    CREATE EXTERNAL DATA SOURCE UsStateEmploymentEarningsDS
    WITH (
        LOCATION = 'abs://laborstatisticscontainer@azureopendatastorage.blob.core.windows.net/ehe_state'
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
IF OBJECT_ID('dbo.UsStateEmploymentEarnings_External') IS NOT NULL
    DROP EXTERNAL TABLE dbo.UsStateEmploymentEarnings_External;
GO

CREATE EXTERNAL TABLE dbo.UsStateEmploymentEarnings_External
(
    [area_code]        VARCHAR(50),
    [state_code]       VARCHAR(50),
    [data_type_code]   VARCHAR(50),
    [industry_code]    VARCHAR(50),
    [supersector_code] VARCHAR(50),
    [series_id]        VARCHAR(50),
    [year]             INT,
    [period]           VARCHAR(50),
    [value]            REAL,
    [footnote_codes]   VARCHAR(100),
    [seasonal]         VARCHAR(50),
    [supersector_name] VARCHAR(512),
    [industry_name]    VARCHAR(512),
    [data_type_text]   VARCHAR(512),
    [state_name]       VARCHAR(512),
    [area_name]        VARCHAR(512)
)
WITH (
    DATA_SOURCE = UsStateEmploymentEarningsDS,
    LOCATION    = '/',
    FILE_FORMAT = ParquetFormat
);
GO

-- Statistics give the optimizer accurate cardinality estimates. External
-- tables only support FULLSCAN (the engine scans the remote data once).
CREATE STATISTICS ST_UsStateEmploymentEarnings_series_id ON dbo.UsStateEmploymentEarnings_External ([series_id]) WITH FULLSCAN;
CREATE STATISTICS ST_UsStateEmploymentEarnings_year ON dbo.UsStateEmploymentEarnings_External ([year]) WITH FULLSCAN;
CREATE STATISTICS ST_UsStateEmploymentEarnings_period ON dbo.UsStateEmploymentEarnings_External ([period]) WITH FULLSCAN;
GO

-- =============================================================================
-- Step 4: Query the external table - just like a regular table
-- =============================================================================
SELECT TOP 50 *
FROM dbo.UsStateEmploymentEarnings_External;
GO

-- Inspect the external table definition
SELECT c.column_id, c.name, t.name AS data_type, c.max_length
FROM sys.columns AS c
JOIN sys.types AS t ON c.user_type_id = t.user_type_id
WHERE c.object_id = OBJECT_ID('dbo.UsStateEmploymentEarnings_External')
ORDER BY c.column_id;
GO
