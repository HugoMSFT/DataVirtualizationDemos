-- =============================================================================
-- Step 4.a - Ingest with OPENROWSET into a Local Table
-- Dataset: New York City Safety Data (311 calls)
-- Source:  https://learn.microsoft.com/azure/open-datasets/dataset-new-york-city-safety
-- Storage: abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=NewYorkCity/  (public, anonymous read - no credential required)
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

IF DB_ID(N'NewYorkCitySafety') IS NULL
    CREATE DATABASE [NewYorkCitySafety];
GO

-- -----------------------------------------------------------------------------
-- IMPORTANT: Azure SQL Database does NOT support USE to switch databases.
--   Open a NEW query window connected to [NewYorkCitySafety] and run everything below.
--   (On SQL Server / Managed Instance you can simply uncomment the USE line.)
-- -----------------------------------------------------------------------------
-- USE [NewYorkCitySafety];
-- GO

-- =============================================================================
-- Step 2: Ingest the data with OPENROWSET (SELECT ... INTO)
-- =============================================================================

DROP TABLE IF EXISTS dbo.NewYorkCitySafety_Local;
GO

SELECT *
INTO dbo.NewYorkCitySafety_Local
FROM OPENROWSET(
    BULK 'abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=NewYorkCity/*.parquet',
    FORMAT = 'PARQUET'
) AS [src];
GO

-- Verify the ingestion
SELECT COUNT(*) AS total_rows FROM dbo.NewYorkCitySafety_Local;
GO

SELECT TOP 10 * FROM dbo.NewYorkCitySafety_Local;
GO

-- Inspect the types SQL Server inferred from the Parquet metadata.
EXEC sp_help 'dbo.NewYorkCitySafety_Local';
GO

-- =============================================================================
-- Step 3: Add indexes for better query performance
-- =============================================================================
CREATE CLUSTERED INDEX CIX_NewYorkCitySafety_dateTime
    ON dbo.NewYorkCitySafety_Local ([dateTime]);
GO

CREATE NONCLUSTERED INDEX IX_NewYorkCitySafety_category
    ON dbo.NewYorkCitySafety_Local ([category]);
GO

-- =============================================================================
-- Step 4: Analytical query - Incident volume by response category
-- =============================================================================
SELECT category, COUNT(*) AS incident_count
FROM dbo.NewYorkCitySafety_Local
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
    BULK 'abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=NewYorkCity/*.parquet',
    FORMAT = 'PARQUET'
) AS [src]
GROUP BY category
ORDER BY incident_count DESC;
GO

-- Local: same query against the ingested, indexed table
SELECT category, COUNT(*) AS incident_count
FROM dbo.NewYorkCitySafety_Local
GROUP BY category
ORDER BY incident_count DESC;
GO

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- =============================================================================
-- Cleanup (optional)
-- =============================================================================
-- DROP TABLE IF EXISTS dbo.NewYorkCitySafety_Local;
-- GO
