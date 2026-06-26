-- =============================================================================
-- Step 4.a - Ingest with OPENROWSET into a Local Table
-- Dataset: Chicago Safety Data (311 calls)
-- Source:  https://learn.microsoft.com/azure/open-datasets/dataset-chicago-safety
-- Storage: abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=Chicago/  (public, anonymous read - no credential required)
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

IF DB_ID(N'ChicagoSafety') IS NULL
    CREATE DATABASE [ChicagoSafety];
GO

-- -----------------------------------------------------------------------------
-- IMPORTANT: Azure SQL Database does NOT support USE to switch databases.
--   Open a NEW query window connected to [ChicagoSafety] and run everything below.
--   (On SQL Server / Managed Instance you can simply uncomment the USE line.)
-- -----------------------------------------------------------------------------
-- USE [ChicagoSafety];
-- GO

-- =============================================================================
-- Step 2: Ingest the data with OPENROWSET (SELECT ... INTO)
-- =============================================================================

DROP TABLE IF EXISTS dbo.ChicagoSafety_Local;
GO

SELECT *
INTO dbo.ChicagoSafety_Local
FROM OPENROWSET(
    BULK 'abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=Chicago/*.parquet',
    FORMAT = 'PARQUET'
) AS [src];
GO

-- Verify the ingestion
SELECT COUNT(*) AS total_rows FROM dbo.ChicagoSafety_Local;
GO

SELECT TOP 10 * FROM dbo.ChicagoSafety_Local;
GO

-- Inspect the types SQL Server inferred from the Parquet metadata.
EXEC sp_help 'dbo.ChicagoSafety_Local';
GO

-- =============================================================================
-- Step 3: Add indexes for better query performance
-- =============================================================================
CREATE CLUSTERED INDEX CIX_ChicagoSafety_dateTime
    ON dbo.ChicagoSafety_Local ([dateTime]);
GO

CREATE NONCLUSTERED INDEX IX_ChicagoSafety_category
    ON dbo.ChicagoSafety_Local ([category]);
GO

-- =============================================================================
-- Step 4: Analytical query - Incident volume by response category
-- =============================================================================
SELECT category, COUNT(*) AS incident_count
FROM dbo.ChicagoSafety_Local
GROUP BY category
ORDER BY incident_count DESC;
GO

-- =============================================================================
-- Step 5: Performance comparison - remote (OPENROWSET) vs local table
-- =============================================================================
SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

-- Remote: reads Parquet over the network every time
SELECT category, COUNT(*) AS incident_count
FROM OPENROWSET(
    BULK 'abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=Chicago/*.parquet',
    FORMAT = 'PARQUET'
) AS [src]
GROUP BY category
ORDER BY incident_count DESC;
GO

-- Local: same query against the ingested, indexed table
SELECT category, COUNT(*) AS incident_count
FROM dbo.ChicagoSafety_Local
GROUP BY category
ORDER BY incident_count DESC;
GO

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- =============================================================================
-- Cleanup (optional)
-- =============================================================================
-- DROP TABLE IF EXISTS dbo.ChicagoSafety_Local;
-- GO
