-- =============================================================================
-- Step 4.b - External Table over the Parquet files
-- Dataset: NYC Taxi & Limousine - Yellow Taxi Trips
-- Source:  https://learn.microsoft.com/azure/open-datasets/dataset-taxi-yellow
-- Storage: abs://nyctlc@azureopendatastorage.blob.core.windows.net/yellow/  (public, anonymous read - no credential required)
-- Platform: Azure SQL Database (Data Virtualization enabled by default)
-- =============================================================================
-- Goal: expose the remote Parquet as a regular table via an external data
--       source + file format + CREATE EXTERNAL TABLE. End users query it with
--       plain SELECT - no OPENROWSET, no storage URLs.
-- Run this script connected to the [NycTaxiYellow] database (created in 01).
-- =============================================================================

-- =============================================================================
-- Step 1: External data source (points at the dataset's storage folder)
-- =============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.external_data_sources WHERE name = 'NycTaxiYellowDS')
    CREATE EXTERNAL DATA SOURCE NycTaxiYellowDS
    WITH (
        LOCATION = 'abs://nyctlc@azureopendatastorage.blob.core.windows.net/yellow'
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
IF OBJECT_ID('dbo.NycTaxiYellow_External') IS NOT NULL
    DROP EXTERNAL TABLE dbo.NycTaxiYellow_External;
GO

CREATE EXTERNAL TABLE dbo.NycTaxiYellow_External
(
    [vendorID]             VARCHAR(50),
    [tpepPickupDateTime]   DATETIME2(7),
    [tpepDropoffDateTime]  DATETIME2(7),
    [passengerCount]       INT,
    [tripDistance]         FLOAT,
    [puLocationId]         VARCHAR(50),
    [doLocationId]         VARCHAR(50),
    [startLon]             FLOAT,
    [startLat]             FLOAT,
    [endLon]               FLOAT,
    [endLat]               FLOAT,
    [rateCodeId]           INT,
    [storeAndFwdFlag]      VARCHAR(50),
    [paymentType]          VARCHAR(50),
    [fareAmount]           FLOAT,
    [extra]                FLOAT,
    [mtaTax]               FLOAT,
    [improvementSurcharge] VARCHAR(50),
    [tipAmount]            FLOAT,
    [tollsAmount]          FLOAT,
    [totalAmount]          FLOAT
)
WITH (
    DATA_SOURCE = NycTaxiYellowDS,
    LOCATION    = '/',
    FILE_FORMAT = ParquetFormat
);
GO

-- NOTE: CREATE STATISTICS WITH FULLSCAN would scan the ENTIRE remote dataset
--       (10s of GB for this source). Enable only if you need it:
-- CREATE STATISTICS ST_NycTaxiYellow_tpepPickupDateTime ON dbo.NycTaxiYellow_External ([tpepPickupDateTime]) WITH FULLSCAN;
-- CREATE STATISTICS ST_NycTaxiYellow_paymentType ON dbo.NycTaxiYellow_External ([paymentType]) WITH FULLSCAN;
-- GO

-- =============================================================================
-- Step 4: Query the external table - just like a regular table
-- =============================================================================
SELECT TOP 50 *
FROM dbo.NycTaxiYellow_External
ORDER BY [tpepPickupDateTime] DESC;
GO

-- Inspect the external table definition
SELECT c.column_id, c.name, t.name AS data_type, c.max_length
FROM sys.columns AS c
JOIN sys.types AS t ON c.user_type_id = t.user_type_id
WHERE c.object_id = OBJECT_ID('dbo.NycTaxiYellow_External')
ORDER BY c.column_id;
GO
