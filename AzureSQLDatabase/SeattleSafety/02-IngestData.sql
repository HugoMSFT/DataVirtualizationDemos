-- =============================================================================
-- Demo: Ingest Data from OPENROWSET into a Local Table
-- Dataset: Seattle Safety (Fire Department 911 Dispatches)
-- Source: https://learn.microsoft.com/en-us/azure/open-datasets/dataset-seattle-safety
-- Platform: Azure SQL Database (Data Virtualization enabled by default)
-- =============================================================================
-- After exploring the dataset ad-hoc, this script shows how to ingest the
-- data into a local table for full SQL engine capabilities (indexes, stats, etc.)
-- =============================================================================

-- =============================================================================
-- Step 1: Ingest everything with SELECT INTO
-- =============================================================================

-- SELECT INTO creates a new table from the query results.
-- This is the fastest way to land the full dataset into your database.

DROP TABLE IF EXISTS dbo.SeattleSafety_Local;
GO

SELECT *
INTO dbo.SeattleSafety_Local
FROM OPENROWSET(
    BULK 'abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=Seattle/*.parquet',
    FORMAT = 'PARQUET'
) AS [SeattleSafety];
GO

-- Verify the ingestion
SELECT COUNT(*) AS total_rows FROM dbo.SeattleSafety_Local;
GO

SELECT TOP 10 * FROM dbo.SeattleSafety_Local;
GO

-- SELECT INTO inferred the column types from the Parquet metadata.
-- Run sp_help to see what SQL Server decided — note the types, nullability,
-- and max_length. In 03-ExternalTables.sql we'll define these explicitly.
EXEC sp_help 'dbo.SeattleSafety_Local';
GO

-- =============================================================================
-- Step 2: Add indexes for better query performance
-- =============================================================================

-- Clustered index on dateTime for time-based queries
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'CIX_SeattleSafety_Local_DateTime' AND object_id = OBJECT_ID('dbo.SeattleSafety_Local'))
    CREATE CLUSTERED INDEX CIX_SeattleSafety_Local_DateTime
        ON dbo.SeattleSafety_Local ([dateTime]);
GO

-- Nonclustered index on category for filtering by incident type
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SeattleSafety_Local_Category' AND object_id = OBJECT_ID('dbo.SeattleSafety_Local'))
    CREATE NONCLUSTERED INDEX IX_SeattleSafety_Local_Category
        ON dbo.SeattleSafety_Local ([category]);
GO

-- =============================================================================
-- Step 3: Query locally — full SQL engine power
-- =============================================================================

SELECT
    category,
    COUNT(*) AS incident_count,
    MIN(dateTime) AS first_incident,
    MAX(dateTime) AS last_incident
FROM dbo.SeattleSafety_Local
GROUP BY category
ORDER BY incident_count DESC;
GO

-- =============================================================================
-- Step 4: Performance comparison — remote vs local
-- =============================================================================
-- Note: the SELECT INTO in Step 1 already primed the remote storage caches
-- on the Azure side, so the remote query below is a best-case warm run.
-- On a cold database the gap between remote and local is even larger.

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
FROM dbo.SeattleSafety_Local
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
-- DROP TABLE IF EXISTS dbo.SeattleSafety_Local;
-- GO
-- =============================================================================
