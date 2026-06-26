-- =============================================================================
-- Step 4.b - External Table over the Parquet files
-- Dataset: Boston Safety Data (311 calls)
-- Source:  https://learn.microsoft.com/azure/open-datasets/dataset-boston-safety
-- Storage: abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=Boston/  (public, anonymous read - no credential required)
-- Platform: Azure SQL Database (Data Virtualization enabled by default)
-- =============================================================================
-- Goal: expose the remote Parquet as a regular table via an external data
--       source + file format + CREATE EXTERNAL TABLE. End users query it with
--       plain SELECT - no OPENROWSET, no storage URLs.
-- Run this script connected to the [BostonSafety] database (created in 01).
-- =============================================================================

-- =============================================================================
-- Step 1: External data source (points at the dataset's storage folder)
-- =============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.external_data_sources WHERE name = 'BostonSafetyDS')
    CREATE EXTERNAL DATA SOURCE BostonSafetyDS
    WITH (
        LOCATION = 'abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=Boston'
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
IF OBJECT_ID('dbo.BostonSafety_External') IS NOT NULL
    DROP EXTERNAL TABLE dbo.BostonSafety_External;
GO

CREATE EXTERNAL TABLE dbo.BostonSafety_External
(
    [dataType]           VARCHAR(50),
    [dataSubtype]        VARCHAR(50),
    [dateTime]           DATETIME2(7),
    [category]           VARCHAR(256),
    [subcategory]        VARCHAR(256),
    [status]             VARCHAR(256),
    [address]            VARCHAR(500),
    [latitude]           FLOAT,
    [longitude]          FLOAT,
    [source]             VARCHAR(50),
    [extendedProperties] VARCHAR(4000)
)
WITH (
    DATA_SOURCE = BostonSafetyDS,
    LOCATION    = '/',
    FILE_FORMAT = ParquetFormat
);
GO

-- Statistics give the optimizer accurate cardinality estimates. External
-- tables only support FULLSCAN (the engine scans the remote data once).
CREATE STATISTICS ST_BostonSafety_dateTime ON dbo.BostonSafety_External ([dateTime]) WITH FULLSCAN;
CREATE STATISTICS ST_BostonSafety_category ON dbo.BostonSafety_External ([category]) WITH FULLSCAN;
GO

-- =============================================================================
-- Step 4: Query the external table - just like a regular table
-- =============================================================================
SELECT TOP 50 *
FROM dbo.BostonSafety_External
ORDER BY [dateTime] DESC;
GO

-- Inspect the external table definition
SELECT c.column_id, c.name, t.name AS data_type, c.max_length
FROM sys.columns AS c
JOIN sys.types AS t ON c.user_type_id = t.user_type_id
WHERE c.object_id = OBJECT_ID('dbo.BostonSafety_External')
ORDER BY c.column_id;
GO
