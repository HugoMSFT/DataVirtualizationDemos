-- =============================================================================
-- Step 4.a - Ingest with OPENROWSET into a Local Table
-- Dataset: US Local Area Unemployment Statistics
-- Source:  https://learn.microsoft.com/azure/open-datasets/dataset-us-local-unemployment
-- Storage: abs://laborstatisticscontainer@azureopendatastorage.blob.core.windows.net/laus/  (public, anonymous read - no credential required)
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

IF DB_ID(N'UsLocalAreaUnemployment') IS NULL
    CREATE DATABASE [UsLocalAreaUnemployment];
GO

-- -----------------------------------------------------------------------------
-- IMPORTANT: Azure SQL Database does NOT support USE to switch databases.
--   Open a NEW query window connected to [UsLocalAreaUnemployment] and run everything below.
--   (On SQL Server / Managed Instance you can simply uncomment the USE line.)
-- -----------------------------------------------------------------------------
-- USE [UsLocalAreaUnemployment];
-- GO

-- =============================================================================
-- Step 2: Ingest the data with OPENROWSET (SELECT ... INTO)
-- =============================================================================

DROP TABLE IF EXISTS dbo.UsLocalAreaUnemployment_Local;
GO

SELECT *
INTO dbo.UsLocalAreaUnemployment_Local
FROM OPENROWSET(
    BULK 'abs://laborstatisticscontainer@azureopendatastorage.blob.core.windows.net/laus/*.parquet',
    FORMAT = 'PARQUET'
) AS [src];
GO

-- Verify the ingestion
SELECT COUNT(*) AS total_rows FROM dbo.UsLocalAreaUnemployment_Local;
GO

SELECT TOP 10 * FROM dbo.UsLocalAreaUnemployment_Local;
GO

-- Inspect the types SQL Server inferred from the Parquet metadata.
EXEC sp_help 'dbo.UsLocalAreaUnemployment_Local';
GO

-- =============================================================================
-- Step 3: Add indexes for better query performance
-- =============================================================================
CREATE CLUSTERED INDEX CIX_UsLocalAreaUnemployment_series_id_year_period
    ON dbo.UsLocalAreaUnemployment_Local ([series_id], [year], [period]);
GO

-- =============================================================================
-- Step 4: Analytical query - Observations and average value by area
-- =============================================================================
SELECT TOP 20
    area_text,
    COUNT(*)                              AS observations,
    CAST(AVG(value) AS DECIMAL(18,3))     AS avg_value
FROM dbo.UsLocalAreaUnemployment_Local
GROUP BY area_text
ORDER BY observations DESC;
GO

-- =============================================================================
-- Step 5: Performance comparison - remote (OPENROWSET) vs local table
-- =============================================================================
SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

-- Remote: reads Parquet over the network every time
SELECT TOP 20
    area_text,
    COUNT(*)                              AS observations,
    CAST(AVG(value) AS DECIMAL(18,3))     AS avg_value
FROM OPENROWSET(
    BULK 'abs://laborstatisticscontainer@azureopendatastorage.blob.core.windows.net/laus/*.parquet',
    FORMAT = 'PARQUET'
) AS [src]
GROUP BY area_text
ORDER BY observations DESC;
GO

-- Local: same query against the ingested, indexed table
SELECT TOP 20
    area_text,
    COUNT(*)                              AS observations,
    CAST(AVG(value) AS DECIMAL(18,3))     AS avg_value
FROM dbo.UsLocalAreaUnemployment_Local
GROUP BY area_text
ORDER BY observations DESC;
GO

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- =============================================================================
-- Cleanup (optional)
-- =============================================================================
-- DROP TABLE IF EXISTS dbo.UsLocalAreaUnemployment_Local;
-- GO
