-- =============================================================================
-- Step 4.b - External Table over the Parquet files
-- Dataset: US Population by County
-- Source:  https://learn.microsoft.com/azure/open-datasets/dataset-us-population-county
-- Storage: abs://censusdatacontainer@azureopendatastorage.blob.core.windows.net/release/us_population_county/  (public, anonymous read - no credential required)
-- Platform: Azure SQL Database (Data Virtualization enabled by default)
-- =============================================================================
-- Goal: expose the remote Parquet as a regular table via an external data
--       source + file format + CREATE EXTERNAL TABLE. End users query it with
--       plain SELECT - no OPENROWSET, no storage URLs.
-- Run this script connected to the [UsPopulationByCounty] database (created in 01).
-- =============================================================================

-- =============================================================================
-- Step 1: External data source (points at the dataset's storage folder)
-- =============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.external_data_sources WHERE name = 'UsPopulationByCountyDS')
    CREATE EXTERNAL DATA SOURCE UsPopulationByCountyDS
    WITH (
        LOCATION = 'abs://censusdatacontainer@azureopendatastorage.blob.core.windows.net/release/us_population_county'
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
-- This source is folder-partitioned (censusYear=). The storage also contains zero-byte
-- directory-marker blobs at each partition level; the data virtualization
-- engine treats them as directories. If your environment instead raises a
-- file-read error, either point LOCATION at one partition subfolder, or use
-- the OPENROWSET view in script 03 (it globs '*.parquet' and skips markers).
IF OBJECT_ID('dbo.UsPopulationByCounty_External') IS NOT NULL
    DROP EXTERNAL TABLE dbo.UsPopulationByCounty_External;
GO

CREATE EXTERNAL TABLE dbo.UsPopulationByCounty_External
(
    [decennialTime] VARCHAR(50),
    [stateName]     VARCHAR(256),
    [countyName]    VARCHAR(256),
    [population]    INT,
    [race]          VARCHAR(50),
    [sex]           VARCHAR(50),
    [minAge]        INT,
    [maxAge]        INT
)
WITH (
    DATA_SOURCE = UsPopulationByCountyDS,
    LOCATION    = '/',
    FILE_FORMAT = ParquetFormat
);
GO

-- Statistics give the optimizer accurate cardinality estimates. External
-- tables only support FULLSCAN (the engine scans the remote data once).
CREATE STATISTICS ST_UsPopulationByCounty_stateName ON dbo.UsPopulationByCounty_External ([stateName]) WITH FULLSCAN;
CREATE STATISTICS ST_UsPopulationByCounty_countyName ON dbo.UsPopulationByCounty_External ([countyName]) WITH FULLSCAN;
GO

-- =============================================================================
-- Step 4: Query the external table - just like a regular table
-- =============================================================================
SELECT TOP 50 *
FROM dbo.UsPopulationByCounty_External;
GO

-- Inspect the external table definition
SELECT c.column_id, c.name, t.name AS data_type, c.max_length
FROM sys.columns AS c
JOIN sys.types AS t ON c.user_type_id = t.user_type_id
WHERE c.object_id = OBJECT_ID('dbo.UsPopulationByCounty_External')
ORDER BY c.column_id;
GO
