-- =============================================================================
-- Step 4.b - External Table over the Parquet files
-- Dataset: US Population by ZIP Code
-- Source:  https://learn.microsoft.com/azure/open-datasets/dataset-us-population-zip
-- Storage: abs://censusdatacontainer@azureopendatastorage.blob.core.windows.net/release/us_population_zip/  (public, anonymous read - no credential required)
-- Platform: Azure SQL Database (Data Virtualization enabled by default)
-- =============================================================================
-- Goal: expose the remote Parquet as a regular table via an external data
--       source + file format + CREATE EXTERNAL TABLE. End users query it with
--       plain SELECT - no OPENROWSET, no storage URLs.
-- Run this script connected to the [UsPopulationByZip] database (created in 01).
-- =============================================================================

-- =============================================================================
-- Step 1: External data source (points at the dataset's storage folder)
-- =============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.external_data_sources WHERE name = 'UsPopulationByZipDS')
    CREATE EXTERNAL DATA SOURCE UsPopulationByZipDS
    WITH (
        LOCATION = 'abs://censusdatacontainer@azureopendatastorage.blob.core.windows.net/release/us_population_zip'
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
IF OBJECT_ID('dbo.UsPopulationByZip_External') IS NOT NULL
    DROP EXTERNAL TABLE dbo.UsPopulationByZip_External;
GO

CREATE EXTERNAL TABLE dbo.UsPopulationByZip_External
(
    [decennialTime] VARCHAR(50),
    [zipCode]       VARCHAR(50),
    [population]    INT,
    [race]          VARCHAR(50),
    [sex]           VARCHAR(50),
    [minAge]        INT,
    [maxAge]        INT
)
WITH (
    DATA_SOURCE = UsPopulationByZipDS,
    LOCATION    = '/',
    FILE_FORMAT = ParquetFormat
);
GO

-- Statistics give the optimizer accurate cardinality estimates. External
-- tables only support FULLSCAN (the engine scans the remote data once).
CREATE STATISTICS ST_UsPopulationByZip_zipCode ON dbo.UsPopulationByZip_External ([zipCode]) WITH FULLSCAN;
GO

-- =============================================================================
-- Step 4: Query the external table - just like a regular table
-- =============================================================================
SELECT TOP 50 *
FROM dbo.UsPopulationByZip_External;
GO

-- Inspect the external table definition
SELECT c.column_id, c.name, t.name AS data_type, c.max_length
FROM sys.columns AS c
JOIN sys.types AS t ON c.user_type_id = t.user_type_id
WHERE c.object_id = OBJECT_ID('dbo.UsPopulationByZip_External')
ORDER BY c.column_id;
GO
