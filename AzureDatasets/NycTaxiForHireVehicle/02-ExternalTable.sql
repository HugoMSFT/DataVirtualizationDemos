-- =============================================================================
-- Step 4.b - External Table over the Parquet files
-- Dataset: NYC Taxi & Limousine - For-Hire Vehicle Trips
-- Source:  https://learn.microsoft.com/azure/open-datasets/dataset-taxi-for-hire-vehicle
-- Storage: abs://nyctlc@azureopendatastorage.blob.core.windows.net/fhv/  (public, anonymous read - no credential required)
-- Platform: Azure SQL Database (Data Virtualization enabled by default)
-- =============================================================================
-- Goal: expose the remote Parquet as a regular table via an external data
--       source + file format + CREATE EXTERNAL TABLE. End users query it with
--       plain SELECT - no OPENROWSET, no storage URLs.
-- Run this script connected to the [NycTaxiForHireVehicle] database (created in 01).
-- =============================================================================

-- =============================================================================
-- Step 1: External data source (points at the dataset's storage folder)
-- =============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.external_data_sources WHERE name = 'NycTaxiForHireVehicleDS')
    CREATE EXTERNAL DATA SOURCE NycTaxiForHireVehicleDS
    WITH (
        LOCATION = 'abs://nyctlc@azureopendatastorage.blob.core.windows.net/fhv'
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
-- This source is folder-partitioned (puYear=, puMonth=). The storage also contains zero-byte
-- directory-marker blobs at each partition level; the data virtualization
-- engine treats them as directories. If your environment instead raises a
-- file-read error, either point LOCATION at one partition subfolder, or use
-- the OPENROWSET view in script 03 (it globs '*.parquet' and skips markers).
IF OBJECT_ID('dbo.NycTaxiForHireVehicle_External') IS NOT NULL
    DROP EXTERNAL TABLE dbo.NycTaxiForHireVehicle_External;
GO

CREATE EXTERNAL TABLE dbo.NycTaxiForHireVehicle_External
(
    [dispatchBaseNum] VARCHAR(50),
    [pickupDateTime]  DATETIME2(7),
    [dropOffDateTime] DATETIME2(7),
    [puLocationId]    VARCHAR(50),
    [doLocationId]    VARCHAR(50),
    [srFlag]          VARCHAR(50)
)
WITH (
    DATA_SOURCE = NycTaxiForHireVehicleDS,
    LOCATION    = '/',
    FILE_FORMAT = ParquetFormat
);
GO

-- NOTE: CREATE STATISTICS WITH FULLSCAN would scan the ENTIRE remote dataset
--       (10s of GB for this source). Enable only if you need it:
-- CREATE STATISTICS ST_NycTaxiForHireVehicle_pickupDateTime ON dbo.NycTaxiForHireVehicle_External ([pickupDateTime]) WITH FULLSCAN;
-- CREATE STATISTICS ST_NycTaxiForHireVehicle_dispatchBaseNum ON dbo.NycTaxiForHireVehicle_External ([dispatchBaseNum]) WITH FULLSCAN;
-- GO

-- =============================================================================
-- Step 4: Query the external table - just like a regular table
-- =============================================================================
SELECT TOP 50 *
FROM dbo.NycTaxiForHireVehicle_External
ORDER BY [pickupDateTime] DESC;
GO

-- Inspect the external table definition
SELECT c.column_id, c.name, t.name AS data_type, c.max_length
FROM sys.columns AS c
JOIN sys.types AS t ON c.user_type_id = t.user_type_id
WHERE c.object_id = OBJECT_ID('dbo.NycTaxiForHireVehicle_External')
ORDER BY c.column_id;
GO
