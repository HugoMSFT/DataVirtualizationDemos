-- =============================================================================
-- Step 4.a - Ingest with OPENROWSET into a Local Table
-- Dataset: San Francisco Safety Data (311 + fire calls)
-- Source:  https://learn.microsoft.com/azure/open-datasets/dataset-san-francisco-safety
-- Storage: abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=SanFrancisco/  (public, anonymous read - no credential required)
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

IF DB_ID(N'SanFranciscoSafety') IS NULL
    CREATE DATABASE [SanFranciscoSafety];
GO

-- -----------------------------------------------------------------------------
-- IMPORTANT: Azure SQL Database does NOT support USE to switch databases.
--   Open a NEW query window connected to [SanFranciscoSafety] and run everything below.
--   (On SQL Server / Managed Instance you can simply uncomment the USE line.)
-- -----------------------------------------------------------------------------
-- USE [SanFranciscoSafety];
-- GO

-- =============================================================================
-- Step 2: Ingest the data with OPENROWSET (SELECT ... INTO)
-- =============================================================================

DROP TABLE IF EXISTS dbo.SanFranciscoSafety_Local;
GO

SELECT *
INTO dbo.SanFranciscoSafety_Local
FROM OPENROWSET(
    BULK 'abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=SanFrancisco/*.parquet',
    FORMAT = 'PARQUET'
) AS [src];
GO

-- Verify the ingestion
SELECT COUNT(*) AS total_rows FROM dbo.SanFranciscoSafety_Local;
GO

SELECT TOP 10 * FROM dbo.SanFranciscoSafety_Local;
GO

-- Inspect the types SQL Server inferred from the Parquet metadata.
EXEC sp_help 'dbo.SanFranciscoSafety_Local';
GO

-- =============================================================================
-- Step 3: Add indexes for better query performance
-- =============================================================================
CREATE CLUSTERED INDEX CIX_SanFranciscoSafety_dateTime
    ON dbo.SanFranciscoSafety_Local ([dateTime]);
GO

CREATE NONCLUSTERED INDEX IX_SanFranciscoSafety_category
    ON dbo.SanFranciscoSafety_Local ([category]);
GO

-- =============================================================================
-- Step 4: Analytical query - Incident volume by response category
-- =============================================================================
SELECT category, COUNT(*) AS incident_count
FROM dbo.SanFranciscoSafety_Local
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
    BULK 'abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=SanFrancisco/*.parquet',
    FORMAT = 'PARQUET'
) AS [src]
GROUP BY category
ORDER BY incident_count DESC;
GO

-- Local: same query against the ingested, indexed table
SELECT category, COUNT(*) AS incident_count
FROM dbo.SanFranciscoSafety_Local
GROUP BY category
ORDER BY incident_count DESC;
GO

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- =============================================================================
-- Cleanup (optional)
-- =============================================================================
-- DROP TABLE IF EXISTS dbo.SanFranciscoSafety_Local;
-- GO
