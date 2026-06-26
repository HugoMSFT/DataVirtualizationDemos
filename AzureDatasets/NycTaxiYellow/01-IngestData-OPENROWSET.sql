-- =============================================================================
-- Step 4.a - Ingest with OPENROWSET into a Local Table
-- Dataset: NYC Taxi & Limousine - Yellow Taxi Trips
-- Source:  https://learn.microsoft.com/azure/open-datasets/dataset-taxi-yellow
-- Storage: abs://nyctlc@azureopendatastorage.blob.core.windows.net/yellow/  (public, anonymous read - no credential required)
-- Platform: Azure SQL Database (Data Virtualization enabled by default)
-- =============================================================================
-- Goal: create a database named after the dataset and land the data into a
--       local table using OPENROWSET (schema inferred from the Parquet files).
-- =============================================================================

-- =============================================================================
-- Step 1: Create a database named after the dataset
-- =============================================================================
-- Run THIS batch while connected to the [master] database.
-- (Azure SQL Database creates a standalone database; on SQL Server / Managed
--  Instance the same statement works against the local instance.)

IF DB_ID(N'NycTaxiYellow') IS NULL
    CREATE DATABASE [NycTaxiYellow];
GO

-- -----------------------------------------------------------------------------
-- IMPORTANT: Azure SQL Database does NOT support USE to switch databases.
--   Open a NEW query window connected to [NycTaxiYellow] and run everything below.
--   (On SQL Server / Managed Instance you can simply uncomment the USE line.)
-- -----------------------------------------------------------------------------
-- USE [NycTaxiYellow];
-- GO

-- =============================================================================
-- Step 2: Ingest the data with OPENROWSET (SELECT ... INTO)
-- =============================================================================
-- NOTE: This is a very large dataset. To keep the demo practical, the
--       ingest below targets a SINGLE partition (one month). To load more,
--       widen the BULK path - e.g. 'puYear=2018/*.parquet' for a full year,
--       or 'puYear=*/puMonth=*/*.parquet' for everything (can be 10s of GB).

DROP TABLE IF EXISTS dbo.NycTaxiYellow_Local;
GO

SELECT *
INTO dbo.NycTaxiYellow_Local
FROM OPENROWSET(
    BULK 'abs://nyctlc@azureopendatastorage.blob.core.windows.net/yellow/puYear=2018/puMonth=6/*.parquet',
    FORMAT = 'PARQUET'
) AS [src];
GO

-- Verify the ingestion
SELECT COUNT(*) AS total_rows FROM dbo.NycTaxiYellow_Local;
GO

SELECT TOP 10 * FROM dbo.NycTaxiYellow_Local;
GO

-- Inspect the types SQL Server inferred from the Parquet metadata.
EXEC sp_help 'dbo.NycTaxiYellow_Local';
GO

-- =============================================================================
-- Step 3: Add indexes for better query performance
-- =============================================================================
CREATE CLUSTERED INDEX CIX_NycTaxiYellow_tpepPickupDateTime
    ON dbo.NycTaxiYellow_Local ([tpepPickupDateTime]);
GO

CREATE NONCLUSTERED INDEX IX_NycTaxiYellow_paymentType
    ON dbo.NycTaxiYellow_Local ([paymentType]);
GO

-- =============================================================================
-- Step 4: Analytical query - Trips, average fare and distance by payment type
-- =============================================================================
SELECT paymentType,
    COUNT(*)                            AS trips,
    CAST(AVG(fareAmount)  AS DECIMAL(10,2)) AS avg_fare,
    CAST(AVG(tripDistance) AS DECIMAL(10,2)) AS avg_miles
FROM dbo.NycTaxiYellow_Local
GROUP BY paymentType
ORDER BY trips DESC;
GO

-- =============================================================================
-- Step 5: Performance comparison - remote (OPENROWSET) vs local table
-- =============================================================================
SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

-- Remote: reads Parquet over the network every time
SELECT paymentType,
    COUNT(*)                            AS trips,
    CAST(AVG(fareAmount)  AS DECIMAL(10,2)) AS avg_fare,
    CAST(AVG(tripDistance) AS DECIMAL(10,2)) AS avg_miles
FROM OPENROWSET(
    BULK 'abs://nyctlc@azureopendatastorage.blob.core.windows.net/yellow/puYear=2018/puMonth=6/*.parquet',
    FORMAT = 'PARQUET'
) AS [src]
GROUP BY paymentType
ORDER BY trips DESC;
GO

-- Local: same query against the ingested, indexed table
SELECT paymentType,
    COUNT(*)                            AS trips,
    CAST(AVG(fareAmount)  AS DECIMAL(10,2)) AS avg_fare,
    CAST(AVG(tripDistance) AS DECIMAL(10,2)) AS avg_miles
FROM dbo.NycTaxiYellow_Local
GROUP BY paymentType
ORDER BY trips DESC;
GO

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- =============================================================================
-- Cleanup (optional)
-- =============================================================================
-- DROP TABLE IF EXISTS dbo.NycTaxiYellow_Local;
-- GO
