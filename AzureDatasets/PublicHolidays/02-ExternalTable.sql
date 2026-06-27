-- =============================================================================
-- Step 4.b - External Table over the Parquet files
-- Dataset: Public Holidays
-- Source:  https://learn.microsoft.com/azure/open-datasets/dataset-public-holidays
-- Storage: abs://holidaydatacontainer@azureopendatastorage.blob.core.windows.net/Processed/  (public, anonymous read - no credential required)
-- Platform: Azure SQL Database (Data Virtualization enabled by default)
-- =============================================================================
-- Goal: expose the remote Parquet as a regular table via an external data
--       source + file format + CREATE EXTERNAL TABLE. End users query it with
--       plain SELECT - no OPENROWSET, no storage URLs.
-- Run this script connected to the [PublicHolidays] database (created in 01).
-- =============================================================================

-- =============================================================================
-- Step 1: External data source (points at the dataset's storage folder)
-- =============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.external_data_sources WHERE name = 'PublicHolidaysDS')
    CREATE EXTERNAL DATA SOURCE PublicHolidaysDS
    WITH (
        LOCATION = 'abs://holidaydatacontainer@azureopendatastorage.blob.core.windows.net/Processed'
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
IF OBJECT_ID('dbo.PublicHolidays_External') IS NOT NULL
    DROP EXTERNAL TABLE dbo.PublicHolidays_External;
GO

CREATE EXTERNAL TABLE dbo.PublicHolidays_External
(
    [countryOrRegion]      VARCHAR(256),
    [holidayName]          VARCHAR(512),
    [normalizeHolidayName] VARCHAR(512),
    [isPaidTimeOff]        BIT,
    [countryRegionCode]    VARCHAR(50),
    [date]                 DATETIME2(7)
)
WITH (
    DATA_SOURCE = PublicHolidaysDS,
    LOCATION    = '/',
    FILE_FORMAT = ParquetFormat
);
GO

-- Statistics give the optimizer accurate cardinality estimates. External
-- tables only support FULLSCAN (the engine scans the remote data once).
CREATE STATISTICS ST_PublicHolidays_date ON dbo.PublicHolidays_External ([date]) WITH FULLSCAN;
CREATE STATISTICS ST_PublicHolidays_countryRegionCode ON dbo.PublicHolidays_External ([countryRegionCode]) WITH FULLSCAN;
GO

-- =============================================================================
-- Step 4: Query the external table - just like a regular table
-- =============================================================================
SELECT TOP 50 *
FROM dbo.PublicHolidays_External
ORDER BY [date] DESC;
GO

-- Inspect the external table definition
SELECT c.column_id, c.name, t.name AS data_type, c.max_length
FROM sys.columns AS c
JOIN sys.types AS t ON c.user_type_id = t.user_type_id
WHERE c.object_id = OBJECT_ID('dbo.PublicHolidays_External')
ORDER BY c.column_id;
GO
