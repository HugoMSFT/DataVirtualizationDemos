-- =============================================================================
-- Demo: Ingest Data from OPENROWSET into a Local Table
-- Dataset: Seattle Safety (Fire Department 911 Dispatches)
-- Source: https://learn.microsoft.com/en-us/azure/open-datasets/dataset-seattle-safety
-- Platform: Azure SQL Database (with Data Virtualization enabled)
-- =============================================================================
-- After exploring the dataset ad-hoc, this script shows how to ingest the
-- data into a local table for full SQL engine capabilities (indexes, stats, etc.)
-- =============================================================================

-- =============================================================================
-- Step 1: Ingest everything with SELECT INTO
-- =============================================================================

-- SELECT INTO creates a new table from the query results.
-- This is the fastest way to land the full dataset into your database.

DROP TABLE IF EXISTS dbo.SeattleSafety;
GO

SELECT *
INTO dbo.SeattleSafety
FROM OPENROWSET(
    BULK 'abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=Seattle/*.parquet',
    FORMAT = 'PARQUET'
) AS [SeattleSafety];
GO -- 1,875,815 (35s)

-- Verify the ingestion
SELECT COUNT(*) AS total_rows FROM dbo.SeattleSafety;
GO

SELECT TOP 10 * FROM dbo.SeattleSafety;
GO

-- =============================================================================
-- Step 2: Add indexes and constraints for better query performance
-- =============================================================================

-- Add a clustered index on dateTime for time-based queries
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'CIX_SeattleSafety_DateTime' AND object_id = OBJECT_ID('dbo.SeattleSafety'))
    CREATE CLUSTERED INDEX CIX_SeattleSafety_DateTime 
        ON dbo.SeattleSafety ([dateTime]);
GO

-- Add a nonclustered index on category for filtering by incident type
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SeattleSafety_Category' AND object_id = OBJECT_ID('dbo.SeattleSafety'))
    CREATE NONCLUSTERED INDEX IX_SeattleSafety_Category 
        ON dbo.SeattleSafety ([category]);
GO

-- =============================================================================
-- Step 3: Now query locally — full SQL engine power
-- =============================================================================

-- Same analytical queries, but now running against local data with indexes
SELECT 
    category,
    COUNT(*) AS incident_count,
    MIN(dateTime) AS first_incident,
    MAX(dateTime) AS last_incident
FROM dbo.SeattleSafety
GROUP BY category
ORDER BY incident_count DESC;
GO

-- =============================================================================
-- Step 4: Performance comparison — remote vs local
-- =============================================================================

-- Turn on statistics to see the difference in execution time and I/O.
SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

-- Query 1: Remote — reads Parquet over the network every time
SELECT category, COUNT(*) AS incident_count
FROM OPENROWSET(
    BULK 'abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=Seattle/*.parquet',
    FORMAT = 'PARQUET'
) AS [SeattleSafety]
GROUP BY category
ORDER BY incident_count DESC;
GO

-- Query 2: Local — same query, but hitting the indexed local table
SELECT category, COUNT(*) AS incident_count
FROM dbo.SeattleSafety
GROUP BY category
ORDER BY incident_count DESC;
GO

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- Compare the "Messages" tab output: elapsed time, logical reads, etc.
-- Local queries benefit from indexes, caching, and no network latency.

-- =============================================================================
-- Cleanup (optional)
-- =============================================================================
-- DROP TABLE IF EXISTS dbo.SeattleSafety;
-- GO
