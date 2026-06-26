-- =============================================================================
-- Step 4.a - Ingest with OPENROWSET into a Local Table
-- Dataset: Public Holidays
-- Source:  https://learn.microsoft.com/azure/open-datasets/dataset-public-holidays
-- Storage: abs://holidaydatacontainer@azureopendatastorage.blob.core.windows.net/Processed/  (public, anonymous read - no credential required)
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

IF DB_ID(N'PublicHolidays') IS NULL
    CREATE DATABASE [PublicHolidays];
GO

-- -----------------------------------------------------------------------------
-- IMPORTANT: Azure SQL Database does NOT support USE to switch databases.
--   Open a NEW query window connected to [PublicHolidays] and run everything below.
--   (On SQL Server / Managed Instance you can simply uncomment the USE line.)
-- -----------------------------------------------------------------------------
-- USE [PublicHolidays];
-- GO

-- =============================================================================
-- Step 2: Ingest the data with OPENROWSET (SELECT ... INTO)
-- =============================================================================

DROP TABLE IF EXISTS dbo.PublicHolidays_Local;
GO

SELECT *
INTO dbo.PublicHolidays_Local
FROM OPENROWSET(
    BULK 'abs://holidaydatacontainer@azureopendatastorage.blob.core.windows.net/Processed/*.parquet',
    FORMAT = 'PARQUET'
) AS [src];
GO

-- Verify the ingestion
SELECT COUNT(*) AS total_rows FROM dbo.PublicHolidays_Local;
GO

SELECT TOP 10 * FROM dbo.PublicHolidays_Local;
GO

-- Inspect the types SQL Server inferred from the Parquet metadata.
EXEC sp_help 'dbo.PublicHolidays_Local';
GO

-- =============================================================================
-- Step 3: Add indexes for better query performance
-- =============================================================================
CREATE CLUSTERED INDEX CIX_PublicHolidays_date
    ON dbo.PublicHolidays_Local ([date]);
GO

CREATE NONCLUSTERED INDEX IX_PublicHolidays_countryRegionCode
    ON dbo.PublicHolidays_Local ([countryRegionCode]);
GO

-- =============================================================================
-- Step 4: Analytical query - Number of holidays by country/region
-- =============================================================================
SELECT TOP 20 countryOrRegion, COUNT(*) AS holiday_count
FROM dbo.PublicHolidays_Local
GROUP BY countryOrRegion
ORDER BY holiday_count DESC;
GO

-- =============================================================================
-- Step 5: Performance comparison - remote (OPENROWSET) vs local table
-- =============================================================================
SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

-- Remote: reads Parquet over the network every time
SELECT TOP 20 countryOrRegion, COUNT(*) AS holiday_count
FROM OPENROWSET(
    BULK 'abs://holidaydatacontainer@azureopendatastorage.blob.core.windows.net/Processed/*.parquet',
    FORMAT = 'PARQUET'
) AS [src]
GROUP BY countryOrRegion
ORDER BY holiday_count DESC;
GO

-- Local: same query against the ingested, indexed table
SELECT TOP 20 countryOrRegion, COUNT(*) AS holiday_count
FROM dbo.PublicHolidays_Local
GROUP BY countryOrRegion
ORDER BY holiday_count DESC;
GO

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- =============================================================================
-- Cleanup (optional)
-- =============================================================================
-- DROP TABLE IF EXISTS dbo.PublicHolidays_Local;
-- GO
