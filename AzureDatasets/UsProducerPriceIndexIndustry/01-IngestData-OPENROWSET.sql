-- =============================================================================
-- Step 4.a - Ingest with OPENROWSET into a Local Table
-- Dataset: US Producer Price Index - Industry
-- Source:  https://learn.microsoft.com/azure/open-datasets/dataset-us-producer-price-index-industry
-- Storage: abs://laborstatisticscontainer@azureopendatastorage.blob.core.windows.net/ppi_industry/  (public, anonymous read - no credential required)
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

IF DB_ID(N'UsProducerPriceIndexIndustry') IS NULL
    CREATE DATABASE [UsProducerPriceIndexIndustry];
GO

-- -----------------------------------------------------------------------------
-- IMPORTANT: Azure SQL Database does NOT support USE to switch databases.
--   Open a NEW query window connected to [UsProducerPriceIndexIndustry] and run everything below.
--   (On SQL Server / Managed Instance you can simply uncomment the USE line.)
-- -----------------------------------------------------------------------------
-- USE [UsProducerPriceIndexIndustry];
-- GO

-- =============================================================================
-- Step 2: Ingest the data with OPENROWSET (SELECT ... INTO)
-- =============================================================================

DROP TABLE IF EXISTS dbo.UsProducerPriceIndexIndustry_Local;
GO

SELECT *
INTO dbo.UsProducerPriceIndexIndustry_Local
FROM OPENROWSET(
    BULK 'abs://laborstatisticscontainer@azureopendatastorage.blob.core.windows.net/ppi_industry/*.parquet',
    FORMAT = 'PARQUET'
) AS [src];
GO

-- Verify the ingestion
SELECT COUNT(*) AS total_rows FROM dbo.UsProducerPriceIndexIndustry_Local;
GO

SELECT TOP 10 * FROM dbo.UsProducerPriceIndexIndustry_Local;
GO

-- Inspect the types SQL Server inferred from the Parquet metadata.
EXEC sp_help 'dbo.UsProducerPriceIndexIndustry_Local';
GO

-- =============================================================================
-- Step 3: Add indexes for better query performance
-- =============================================================================
CREATE CLUSTERED INDEX CIX_UsProducerPriceIndexIndustry_series_id_year_period
    ON dbo.UsProducerPriceIndexIndustry_Local ([series_id], [year], [period]);
GO

-- =============================================================================
-- Step 4: Analytical query - Observations by industry
-- =============================================================================
SELECT TOP 20
    industry_name,
    COUNT(*)                              AS observations,
    CAST(AVG(value) AS DECIMAL(18,3))     AS avg_value
FROM dbo.UsProducerPriceIndexIndustry_Local
GROUP BY industry_name
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
    industry_name,
    COUNT(*)                              AS observations,
    CAST(AVG(value) AS DECIMAL(18,3))     AS avg_value
FROM OPENROWSET(
    BULK 'abs://laborstatisticscontainer@azureopendatastorage.blob.core.windows.net/ppi_industry/*.parquet',
    FORMAT = 'PARQUET'
) AS [src]
GROUP BY industry_name
ORDER BY observations DESC;
GO

-- Local: same query against the ingested, indexed table
SELECT TOP 20
    industry_name,
    COUNT(*)                              AS observations,
    CAST(AVG(value) AS DECIMAL(18,3))     AS avg_value
FROM dbo.UsProducerPriceIndexIndustry_Local
GROUP BY industry_name
ORDER BY observations DESC;
GO

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- =============================================================================
-- Cleanup (optional)
-- =============================================================================
-- DROP TABLE IF EXISTS dbo.UsProducerPriceIndexIndustry_Local;
-- GO
