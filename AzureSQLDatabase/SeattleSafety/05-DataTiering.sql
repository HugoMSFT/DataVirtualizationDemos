-- =============================================================================
-- Demo: Data Tiering — Hot/Cold Pattern with OPENROWSET & External Tables
-- Dataset: Seattle Safety (Fire Department 911 Dispatches)
-- Source: https://learn.microsoft.com/en-us/azure/open-datasets/dataset-seattle-safety
-- Platform: Azure SQL Database (with Data Virtualization enabled)
-- =============================================================================
-- This script demonstrates a data tiering strategy:
--   HOT  → Recent data (2025-2026) ingested into local tables for fast queries.
--   COLD → Historical data stays in the public dataset, accessed via external
--          tables — one per year — to keep storage costs low.
--
-- OPENROWSET is used as an ingestion tool with a WHERE filter to land only
-- the data you need locally.
--
-- Prerequisite: Run 03-ExternalTables.sql (creates SeattleSafetyDS and
--               ParquetFileFormat).
-- =============================================================================

-- =============================================================================
-- Step 1: Ingest HOT data (2025-2026) using OPENROWSET as an ingestion tool
-- =============================================================================

-- Use OPENROWSET + WHERE to selectively ingest only the recent data.
-- This avoids loading the entire dataset — only hot rows land in your database.

DROP TABLE IF EXISTS dbo.SeattleSafety_Hot;
GO

SELECT *
INTO dbo.SeattleSafety_Hot
FROM OPENROWSET(
    BULK 'abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=Seattle/*.parquet',
    FORMAT = 'PARQUET'
) AS [src]
WHERE dateTime >= '2025-01-01';
GO

-- Verify: how much data did we ingest?
SELECT 
    YEAR(dateTime) AS [Year],
    COUNT(*)       AS row_count
FROM dbo.SeattleSafety_Hot
GROUP BY YEAR(dateTime)
ORDER BY [Year];
GO

-- Add indexes on the hot table for fast queries
CREATE CLUSTERED INDEX CIX_Hot_DateTime ON dbo.SeattleSafety_Hot ([dateTime]);
GO

CREATE NONCLUSTERED INDEX IX_Hot_Category ON dbo.SeattleSafety_Hot ([category]);
GO

-- =============================================================================
-- Step 2: Create COLD external tables — one per year
-- =============================================================================

-- Each external table represents one year of historical data.
-- The data stays in the public Azure Blob Storage — no local storage needed.
--
-- NOTE: This public dataset isn't physically partitioned by year on disk,
-- so all external tables point to the same path. In a real-world scenario,
-- each year's data would live in its own folder (e.g., /archive/2024/) and
-- each external table would point to that specific path.

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'cold')
    EXEC('CREATE SCHEMA cold');
GO

-- 2024
IF OBJECT_ID('cold.SeattleSafety_2024') IS NOT NULL
    DROP EXTERNAL TABLE cold.SeattleSafety_2024;
GO

CREATE EXTERNAL TABLE cold.SeattleSafety_2024
(
    [address]      VARCHAR(500),
    [category]     VARCHAR(100),
    [dataSubtype]  VARCHAR(50),
    [dataType]     VARCHAR(50),
    [dateTime]     DATETIME2,
    [latitude]     FLOAT,
    [longitude]    FLOAT
)
WITH (
    DATA_SOURCE  = SeattleSafetyDS,
    LOCATION     = '/',
    FILE_FORMAT  = ParquetFileFormat
);
GO

-- 2023
IF OBJECT_ID('cold.SeattleSafety_2023') IS NOT NULL
    DROP EXTERNAL TABLE cold.SeattleSafety_2023;
GO

CREATE EXTERNAL TABLE cold.SeattleSafety_2023
(
    [address]      VARCHAR(500),
    [category]     VARCHAR(100),
    [dataSubtype]  VARCHAR(50),
    [dataType]     VARCHAR(50),
    [dateTime]     DATETIME2,
    [latitude]     FLOAT,
    [longitude]    FLOAT
)
WITH (
    DATA_SOURCE  = SeattleSafetyDS,
    LOCATION     = '/',
    FILE_FORMAT  = ParquetFileFormat
);
GO

-- 2022
IF OBJECT_ID('cold.SeattleSafety_2022') IS NOT NULL
    DROP EXTERNAL TABLE cold.SeattleSafety_2022;
GO

CREATE EXTERNAL TABLE cold.SeattleSafety_2022
(
    [address]      VARCHAR(500),
    [category]     VARCHAR(100),
    [dataSubtype]  VARCHAR(50),
    [dataType]     VARCHAR(50),
    [dateTime]     DATETIME2,
    [latitude]     FLOAT,
    [longitude]    FLOAT
)
WITH (
    DATA_SOURCE  = SeattleSafetyDS,
    LOCATION     = '/',
    FILE_FORMAT  = ParquetFileFormat
);
GO

-- =============================================================================
-- Step 3: Create a unified view — seamless access across tiers
-- =============================================================================

-- The view unions hot (local) and cold (external) data transparently.
-- Consumers just query dbo.vw_SeattleSafety_All — they don't need to know
-- where the data physically lives.

CREATE OR ALTER VIEW dbo.vw_SeattleSafety_All
AS
-- HOT tier: local table (2025-2026), fast, indexed
SELECT [address], [category], [dataSubtype], [dataType],
       [dateTime], [latitude], [longitude],
       'Hot' AS [tier]
FROM dbo.SeattleSafety_Hot

UNION ALL

-- COLD tier: 2024
SELECT [address], [category], [dataSubtype], [dataType],
       [dateTime], [latitude], [longitude],
       'Cold-2024' AS [tier]
FROM cold.SeattleSafety_2024
WHERE dateTime >= '2024-01-01' AND dateTime < '2025-01-01'

UNION ALL

-- COLD tier: 2023
SELECT [address], [category], [dataSubtype], [dataType],
       [dateTime], [latitude], [longitude],
       'Cold-2023' AS [tier]
FROM cold.SeattleSafety_2023
WHERE dateTime >= '2023-01-01' AND dateTime < '2024-01-01'

UNION ALL

-- COLD tier: 2022
SELECT [address], [category], [dataSubtype], [dataType],
       [dateTime], [latitude], [longitude],
       'Cold-2022' AS [tier]
FROM cold.SeattleSafety_2022
WHERE dateTime >= '2022-01-01' AND dateTime < '2023-01-01';
GO

-- =============================================================================
-- Step 4: Query the unified view — hot + cold, one query
-- =============================================================================

-- The [tier] column shows where each row is coming from
SELECT TOP 20 tier, dateTime, category, address
FROM dbo.vw_SeattleSafety_All
ORDER BY dateTime DESC;
GO

-- Aggregate across all tiers transparently
SELECT 
    tier,
    COUNT(*)        AS incident_count,
    MIN(dateTime)   AS earliest,
    MAX(dateTime)   AS latest
FROM dbo.vw_SeattleSafety_All
GROUP BY tier
ORDER BY earliest DESC;
GO

-- Year-over-year trend — spans hot and cold data seamlessly
SELECT 
    YEAR(dateTime)  AS [Year],
    MONTH(dateTime) AS [Month],
    COUNT(*)        AS incident_count
FROM dbo.vw_SeattleSafety_All
GROUP BY YEAR(dateTime), MONTH(dateTime)
ORDER BY [Year] DESC, [Month] DESC;
GO

-- =============================================================================
-- Step 5: Show the tiering benefit — compare hot vs cold performance
-- =============================================================================

SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

-- Fast: hot tier (local, indexed)
SELECT category, COUNT(*) AS cnt
FROM dbo.SeattleSafety_Hot
GROUP BY category
ORDER BY cnt DESC;
GO

-- Slower: cold tier (remote Parquet scan)
SELECT category, COUNT(*) AS cnt
FROM cold.SeattleSafety_2024
WHERE dateTime >= '2024-01-01' AND dateTime < '2025-01-01'
GROUP BY category
ORDER BY cnt DESC;
GO

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- =============================================================================
-- Cleanup (optional)
-- =============================================================================
-- DROP VIEW IF EXISTS dbo.vw_SeattleSafety_All;
-- DROP TABLE IF EXISTS dbo.SeattleSafety_Hot;
-- DROP EXTERNAL TABLE cold.SeattleSafety_2024;
-- DROP EXTERNAL TABLE cold.SeattleSafety_2023;
-- DROP EXTERNAL TABLE cold.SeattleSafety_2022;
-- DROP SCHEMA cold;
-- GO
