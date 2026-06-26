-- =============================================================================
-- Step 4.a - Ingest with OPENROWSET into a Local Table
-- Dataset: US Population by County
-- Source:  https://learn.microsoft.com/azure/open-datasets/dataset-us-population-county
-- Storage: abs://censusdatacontainer@azureopendatastorage.blob.core.windows.net/release/us_population_county/  (public, anonymous read - no credential required)
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

IF DB_ID(N'UsPopulationByCounty') IS NULL
    CREATE DATABASE [UsPopulationByCounty];
GO

-- -----------------------------------------------------------------------------
-- IMPORTANT: Azure SQL Database does NOT support USE to switch databases.
--   Open a NEW query window connected to [UsPopulationByCounty] and run everything below.
--   (On SQL Server / Managed Instance you can simply uncomment the USE line.)
-- -----------------------------------------------------------------------------
-- USE [UsPopulationByCounty];
-- GO

-- =============================================================================
-- Step 2: Ingest the data with OPENROWSET (SELECT ... INTO)
-- =============================================================================

DROP TABLE IF EXISTS dbo.UsPopulationByCounty_Local;
GO

SELECT *
INTO dbo.UsPopulationByCounty_Local
FROM OPENROWSET(
    BULK 'abs://censusdatacontainer@azureopendatastorage.blob.core.windows.net/release/us_population_county/year=*/*.parquet',
    FORMAT = 'PARQUET'
) AS [src];
GO

-- Verify the ingestion
SELECT COUNT(*) AS total_rows FROM dbo.UsPopulationByCounty_Local;
GO

SELECT TOP 10 * FROM dbo.UsPopulationByCounty_Local;
GO

-- Inspect the types SQL Server inferred from the Parquet metadata.
EXEC sp_help 'dbo.UsPopulationByCounty_Local';
GO

-- =============================================================================
-- Step 3: Add indexes for better query performance
-- =============================================================================
CREATE CLUSTERED INDEX CIX_UsPopulationByCounty_stateName_countyName
    ON dbo.UsPopulationByCounty_Local ([stateName], [countyName]);
GO

-- =============================================================================
-- Step 4: Analytical query - Total 2010 population by state
-- =============================================================================
SELECT TOP 20 stateName, SUM(CAST(population AS BIGINT)) AS total_population
FROM dbo.UsPopulationByCounty_Local
WHERE decennialTime = '2010'
GROUP BY stateName
ORDER BY total_population DESC;
GO

-- =============================================================================
-- Step 5: Performance comparison - remote (OPENROWSET) vs local table
-- =============================================================================
SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

-- Remote: reads Parquet over the network every time
SELECT TOP 20 stateName, SUM(CAST(population AS BIGINT)) AS total_population
FROM OPENROWSET(
    BULK 'abs://censusdatacontainer@azureopendatastorage.blob.core.windows.net/release/us_population_county/year=*/*.parquet',
    FORMAT = 'PARQUET'
) AS [src]
WHERE decennialTime = '2010'
GROUP BY stateName
ORDER BY total_population DESC;
GO

-- Local: same query against the ingested, indexed table
SELECT TOP 20 stateName, SUM(CAST(population AS BIGINT)) AS total_population
FROM dbo.UsPopulationByCounty_Local
WHERE decennialTime = '2010'
GROUP BY stateName
ORDER BY total_population DESC;
GO

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- =============================================================================
-- Cleanup (optional)
-- =============================================================================
-- DROP TABLE IF EXISTS dbo.UsPopulationByCounty_Local;
-- GO
