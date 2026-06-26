-- =============================================================================
-- Step 4.a - Ingest with OPENROWSET into a Local Table
-- Dataset: US Population by ZIP Code
-- Source:  https://learn.microsoft.com/azure/open-datasets/dataset-us-population-zip
-- Storage: abs://censusdatacontainer@azureopendatastorage.blob.core.windows.net/release/us_population_zip/  (public, anonymous read - no credential required)
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

IF DB_ID(N'UsPopulationByZip') IS NULL
    CREATE DATABASE [UsPopulationByZip];
GO

-- -----------------------------------------------------------------------------
-- IMPORTANT: Azure SQL Database does NOT support USE to switch databases.
--   Open a NEW query window connected to [UsPopulationByZip] and run everything below.
--   (On SQL Server / Managed Instance you can simply uncomment the USE line.)
-- -----------------------------------------------------------------------------
-- USE [UsPopulationByZip];
-- GO

-- =============================================================================
-- Step 2: Ingest the data with OPENROWSET (SELECT ... INTO)
-- =============================================================================

DROP TABLE IF EXISTS dbo.UsPopulationByZip_Local;
GO

SELECT *
INTO dbo.UsPopulationByZip_Local
FROM OPENROWSET(
    BULK 'abs://censusdatacontainer@azureopendatastorage.blob.core.windows.net/release/us_population_zip/year=*/*.parquet',
    FORMAT = 'PARQUET'
) AS [src];
GO

-- Verify the ingestion
SELECT COUNT(*) AS total_rows FROM dbo.UsPopulationByZip_Local;
GO

SELECT TOP 10 * FROM dbo.UsPopulationByZip_Local;
GO

-- Inspect the types SQL Server inferred from the Parquet metadata.
EXEC sp_help 'dbo.UsPopulationByZip_Local';
GO

-- =============================================================================
-- Step 3: Add indexes for better query performance
-- =============================================================================
CREATE CLUSTERED INDEX CIX_UsPopulationByZip_zipCode
    ON dbo.UsPopulationByZip_Local ([zipCode]);
GO

-- =============================================================================
-- Step 4: Analytical query - Total population by ZIP code
-- =============================================================================
SELECT TOP 20 zipCode, SUM(CAST(population AS BIGINT)) AS total_population
FROM dbo.UsPopulationByZip_Local
GROUP BY zipCode
ORDER BY total_population DESC;
GO

-- =============================================================================
-- Step 5: Performance comparison - remote (OPENROWSET) vs local table
-- =============================================================================
SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

-- Remote: reads Parquet over the network every time
SELECT TOP 20 zipCode, SUM(CAST(population AS BIGINT)) AS total_population
FROM OPENROWSET(
    BULK 'abs://censusdatacontainer@azureopendatastorage.blob.core.windows.net/release/us_population_zip/year=*/*.parquet',
    FORMAT = 'PARQUET'
) AS [src]
GROUP BY zipCode
ORDER BY total_population DESC;
GO

-- Local: same query against the ingested, indexed table
SELECT TOP 20 zipCode, SUM(CAST(population AS BIGINT)) AS total_population
FROM dbo.UsPopulationByZip_Local
GROUP BY zipCode
ORDER BY total_population DESC;
GO

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- =============================================================================
-- Cleanup (optional)
-- =============================================================================
-- DROP TABLE IF EXISTS dbo.UsPopulationByZip_Local;
-- GO
