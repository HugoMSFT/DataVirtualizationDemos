-- =============================================================================
-- Demo: Data Tiering — Hot/Cold Pattern with OPENROWSET & External Tables
-- Dataset: Seattle Safety (Fire Department 911 Dispatches), 2003–2023
-- Storage: https://publiclake.blob.core.windows.net/seattlesafety (public)
-- Platform: Azure SQL Database (Data Virtualization enabled by default)
-- =============================================================================
--
-- This script demonstrates a data tiering strategy:
--
--   HOT  → Latest year (2023) ingested into a local table for fast queries.
--            Indexed, cached, sub-second response times.
--
--   COLD → All historical data (2003–2022) stays in blob storage, accessed
--            via an OPENROWSET-based view with filepath() for partition
--            elimination — only the folders matching a filter are scanned.
--
-- The data is year-partitioned in Azure Blob Storage:
--   /year=YYYY/YYYY_data.parquet
--
-- Two cold-tier objects are created:
--   1. External table (dbo.SeattleSafety_Cold) — supports CREATE STATISTICS
--      for better query optimizer estimates.
--   2. OPENROWSET view (dbo.vw_SeattleSafety_Cold) — supports filepath()
--      partition elimination, which external tables cannot do in views.
--
-- A unified view (dbo.vw_SeattleSafety_All) transparently combines both tiers.
--
-- This script is STANDALONE — it does not depend on 02-IngestData.sql.
-- Hot data is pulled directly from the partitioned source via folder-filtered
-- OPENROWSET.
--
-- =============================================================================

-- =============================================================================
-- Step 0: Clean up previous demo run (drop everything so we can start fresh)
-- =============================================================================
-- Drop in reverse dependency order: views first, then tables, then external
-- objects. This ensures no errors from dependent objects.

DROP VIEW  IF EXISTS dbo.vw_SeattleSafety_All;
GO
DROP VIEW  IF EXISTS dbo.vw_SeattleSafety_Cold;
GO
DROP TABLE IF EXISTS dbo.SeattleSafety_Hot;
GO
IF OBJECT_ID('dbo.SeattleSafety_Cold') IS NOT NULL
    DROP EXTERNAL TABLE dbo.SeattleSafety_Cold;
GO

-- =============================================================================
-- Step 1: Create the external data source and file format
-- =============================================================================

-- The external data source encapsulates the blob storage location.
-- A separate name keeps this demo independent from SeattleSafetyDS
-- in 03-ExternalTables.sql (which points to Azure Open Datasets).

IF NOT EXISTS (SELECT 1 FROM sys.external_data_sources WHERE name = 'SeattleSafetyTieringDS')
BEGIN
    CREATE EXTERNAL DATA SOURCE SeattleSafetyTieringDS
    WITH (
        LOCATION = 'abs://publiclake.blob.core.windows.net/seattlesafety/'
    );
END
GO

-- Parquet file format — reused across external tables and OPENROWSET calls.
IF NOT EXISTS (SELECT 1 FROM sys.external_file_formats WHERE name = 'ParquetFileFormat')
BEGIN
    CREATE EXTERNAL FILE FORMAT ParquetFileFormat
    WITH (
        FORMAT_TYPE = PARQUET
    );
END
GO

-- =============================================================================
-- Step 2: Ingest HOT data (2023) into a local table
-- =============================================================================
-- Pull the latest year directly from the partitioned source by targeting the
-- year=2023 folder with OPENROWSET — no dependency on 02-IngestData.sql.
-- Because the BULK path points at a single year folder, the engine only
-- reads that folder's Parquet files.

SELECT *
INTO   dbo.SeattleSafety_Hot
FROM   OPENROWSET(
           BULK        'year=2023/*.parquet',
           FORMAT      = 'PARQUET',
           DATA_SOURCE = 'SeattleSafetyTieringDS'
       ) AS [src];
GO

-- Clustered index on dateTime for time-range queries.
CREATE CLUSTERED INDEX CIX_SeattleSafety_Hot_DateTime
    ON dbo.SeattleSafety_Hot ([dateTime]);
GO

-- Nonclustered index on category for filtering by incident type.
CREATE NONCLUSTERED INDEX IX_SeattleSafety_Hot_Category
    ON dbo.SeattleSafety_Hot ([category]);
GO

-- Verify: only 2023 data, check the row count.
SELECT
    DATEPART(YEAR, dateTime) AS [Year],
    COUNT(*)                 AS row_count
FROM   dbo.SeattleSafety_Hot
GROUP BY DATEPART(YEAR, dateTime)
ORDER BY [Year];
GO

-- =============================================================================
-- Step 3: Create COLD tier — external table + OPENROWSET view
-- =============================================================================
-- We create TWO objects for the cold tier, each serving a different purpose:
--
--   1. External table (dbo.SeattleSafety_Cold)
--      • Supports CREATE STATISTICS for better optimizer estimates.
--      • Queryable like a regular table: SELECT * FROM dbo.SeattleSafety_Cold
--      • Cannot use filepath() inside views (alias restrictions).
--
--   2. OPENROWSET view (dbo.vw_SeattleSafety_Cold)
--      • Exposes filepath(1) as [year_folder] for partition elimination.
--      • Filtering on year_folder = '2022' skips all other year folders.
--      • Used by the unified view (dbo.vw_SeattleSafety_All).

-- External table — wildcard LOCATION covers all year=* folders.
CREATE EXTERNAL TABLE dbo.SeattleSafety_Cold
(
    [dataType]           VARCHAR(50),
    [dataSubtype]        VARCHAR(50),
    [dateTime]           DATETIME2,
    [category]           VARCHAR(100),
    [subcategory]        VARCHAR(200),
    [status]             VARCHAR(100),
    [address]            VARCHAR(500),
    [latitude]           FLOAT,
    [longitude]          FLOAT,
    [source]             VARCHAR(200),
    [extendedProperties] VARCHAR(4000)
)
WITH (
    DATA_SOURCE  = SeattleSafetyTieringDS,
    LOCATION     = 'year=*/',
    FILE_FORMAT  = ParquetFileFormat
);
GO

-- OPENROWSET-based view — partition elimination via filepath().
-- filepath(1) captures the first wildcard segment in the BULK path,
-- which is the year folder name (e.g., '2003', '2022').
-- Filtering on [year_folder] tells the engine to skip non-matching folders.
CREATE OR ALTER VIEW dbo.vw_SeattleSafety_Cold
AS
SELECT [dataType], [dataSubtype], [dateTime], [category],
       [subcategory], [status], [address], [latitude],
       [longitude], [source], [extendedProperties],
       [SeattleSafety].filepath(1) AS [year_folder]
FROM OPENROWSET(
    BULK 'year=*/*.parquet',
    FORMAT = 'PARQUET',
    DATA_SOURCE = 'SeattleSafetyTieringDS'
) AS [SeattleSafety];
GO

-- Quick verification — compare row counts from both cold objects.
-- They point to the same data, so counts should match.
SELECT COUNT(*) AS cold_rows_via_view      FROM dbo.vw_SeattleSafety_Cold;
GO
SELECT COUNT(*) AS cold_rows_via_ext_table FROM dbo.SeattleSafety_Cold;
GO

-- =============================================================================
-- Step 4: Create a unified view — seamless access across tiers
-- =============================================================================
-- This view is the consumer-facing interface. End users and applications
-- query dbo.vw_SeattleSafety_All without knowing (or caring) whether the
-- data comes from a local table or remote blob storage.
--
-- The [tier] column reveals the data source:
--   'Hot'       → local table (dbo.SeattleSafety_Hot), indexed, fast.
--   'Cold-YYYY' → remote Parquet via OPENROWSET, year-partitioned.

CREATE OR ALTER VIEW dbo.vw_SeattleSafety_All
AS
-- HOT tier: local table (2023) — fast, indexed
SELECT [address], [category], [dataSubtype], [dataType],
       [dateTime], [latitude], [longitude],
       'Hot' AS [tier]
FROM   dbo.SeattleSafety_Hot

UNION ALL

-- COLD tier: OPENROWSET view — year_folder enables partition elimination
SELECT [address], [category], [dataSubtype], [dataType],
       [dateTime], [latitude], [longitude],
       'Cold-' + [year_folder] AS [tier]
FROM   dbo.vw_SeattleSafety_Cold;
GO

-- =============================================================================
-- Step 5: Query the unified view — hot + cold in a single query
-- =============================================================================
-- Aggregate across all tiers — one query spans 20+ years of data
-- from both local storage and remote blob storage transparently.
SELECT
    tier,
    COUNT(*)      AS incident_count,
    MIN(dateTime) AS earliest,
    MAX(dateTime) AS latest
FROM   dbo.vw_SeattleSafety_All
GROUP BY tier
ORDER BY earliest DESC;
GO

-- =============================================================================
-- Step 6: Partition elimination in action — cold tier performance
-- =============================================================================
-- This step compares three query patterns to show the performance impact
-- of data locality (hot vs cold) and partition elimination (filepath filter).
-- Watch the "Messages" tab for elapsed time and logical reads.

SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

-- Query A: HOT tier — local table, indexed.
-- Expected: fastest — no network I/O, clustered index scan.
SELECT category, COUNT(*) AS cnt
FROM   dbo.SeattleSafety_Hot
GROUP BY category
ORDER BY cnt DESC;
GO

-- Query B: COLD tier WITHOUT partition elimination.
-- Scans ALL year folders from blob storage — slowest.
SELECT category, COUNT(*) AS cnt
FROM   dbo.vw_SeattleSafety_Cold
GROUP BY category
ORDER BY cnt DESC;
GO

-- Query C: COLD tier WITH partition elimination.
-- Filters on year_folder = '2022' — only the year=2022/ folder is scanned.
-- Compare the elapsed time to Query B above!
SELECT category, COUNT(*) AS cnt
FROM   dbo.vw_SeattleSafety_Cold
WHERE  year_folder = '2022'
GROUP BY category
ORDER BY cnt DESC;
GO

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- =============================================================================
-- Cleanup (optional) — re-run Step 0 to reset, or use the statements below.
-- Drop in reverse dependency order to avoid errors.
-- ParquetFileFormat is shared with 03-ExternalTables.sql; only drop it if
-- you're done with both demos.
-- =============================================================================

DROP VIEW  IF EXISTS dbo.vw_SeattleSafety_All;
GO
DROP VIEW  IF EXISTS dbo.vw_SeattleSafety_Cold;
GO
DROP TABLE IF EXISTS dbo.SeattleSafety_Hot;
GO
IF OBJECT_ID('dbo.SeattleSafety_Cold') IS NOT NULL
    DROP EXTERNAL TABLE dbo.SeattleSafety_Cold;
GO
IF EXISTS (SELECT 1 FROM sys.external_data_sources WHERE name = 'SeattleSafetyTieringDS')
    DROP EXTERNAL DATA SOURCE SeattleSafetyTieringDS;
GO
-- Only drop the file format if you're done with 03-ExternalTables.sql too:
-- IF EXISTS (SELECT 1 FROM sys.external_file_formats WHERE name = 'ParquetFileFormat')
--     DROP EXTERNAL FILE FORMAT ParquetFileFormat;
-- GO
