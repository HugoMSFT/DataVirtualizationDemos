-- =============================================================================
-- Performance Tests: Compare current vs optimized approaches
-- Run AFTER 05-DataTiering.sql has been fully executed.
-- Prerequisite: SeattleSafetyTieringDS, ParquetFileFormat, and all objects
--               from 05-DataTiering.sql must exist.
-- =============================================================================

SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

-- =============================================================================
-- Test 1: Hot ingestion — YEAR() filter vs direct folder OPENROWSET
-- =============================================================================
-- CURRENT: Scans the full external table and filters with YEAR(dateTime).
-- YEAR() wraps the column and prevents predicate pushdown — all rows are
-- pulled remotely before the filter is applied.

-- Current approach (slow — scans all data, filters locally)
SELECT COUNT(*) AS current_approach_rows
FROM dbo.SeattleSafety_External
WHERE YEAR(dateTime) = 2023;
GO

-- Optimized: OPENROWSET targeting only the year=2023 folder.
-- No function on the column, no full scan — reads only one folder.
SELECT COUNT(*) AS optimized_approach_rows
FROM OPENROWSET(
    BULK 'year=2023/*.parquet',
    FORMAT = 'PARQUET',
    DATA_SOURCE = 'SeattleSafetyTieringDS'
) AS [src];
GO

-- =============================================================================
-- Test 2: Cold OPENROWSET — schema inference vs explicit WITH clause
-- =============================================================================
-- CURRENT: No WITH clause, so SQL Server infers the schema by reading
-- Parquet metadata on every query.

-- Current approach (schema inference on each execution)
SELECT category, COUNT(*) AS cnt
FROM OPENROWSET(
    BULK 'year=2022/*.parquet',
    FORMAT = 'PARQUET',
    DATA_SOURCE = 'SeattleSafetyTieringDS'
) AS [SeattleSafety]
GROUP BY category
ORDER BY cnt DESC;
GO

-- Optimized: Explicit WITH clause avoids schema inference overhead
-- and ensures only the needed columns are deserialized from Parquet.
SELECT category, COUNT(*) AS cnt
FROM OPENROWSET(
    BULK 'year=2022/*.parquet',
    FORMAT = 'PARQUET',
    DATA_SOURCE = 'SeattleSafetyTieringDS'
) WITH (
    [category] VARCHAR(100)
) AS [SeattleSafety]
GROUP BY category
ORDER BY cnt DESC;
GO

-- =============================================================================
-- Test 3: External table WITH statistics vs WITHOUT statistics
-- =============================================================================
-- Statistics give the optimizer accurate cardinality estimates, improving
-- memory grants and join strategies. External tables only support FULLSCAN
-- (no SAMPLE), so the first CREATE STATISTICS triggers one full remote scan.

-- Check current statistics on the cold external table
SELECT s.name AS stat_name, c.name AS column_name
FROM sys.stats s
JOIN sys.stats_columns sc ON s.object_id = sc.object_id AND s.stats_id = sc.stats_id
JOIN sys.columns c ON sc.object_id = c.object_id AND sc.column_id = c.column_id
WHERE s.object_id = OBJECT_ID('dbo.SeattleSafety_Cold');
GO

-- Enable actual execution plan (Ctrl+M) before running these.
-- Run BEFORE creating stats: note the estimated vs actual row counts on
-- the external-table scan — the optimizer is guessing.
SELECT category, COUNT(*) AS cnt
FROM dbo.SeattleSafety_Cold
GROUP BY category
ORDER BY cnt DESC;
GO

-- Create statistics if they don't exist (external tables support FULLSCAN only)
IF NOT EXISTS (SELECT 1 FROM sys.stats WHERE name = 'ST_Cold_DateTime' AND object_id = OBJECT_ID('dbo.SeattleSafety_Cold'))
    CREATE STATISTICS ST_Cold_DateTime ON dbo.SeattleSafety_Cold ([dateTime]) WITH FULLSCAN;
IF NOT EXISTS (SELECT 1 FROM sys.stats WHERE name = 'ST_Cold_Category' AND object_id = OBJECT_ID('dbo.SeattleSafety_Cold'))
    CREATE STATISTICS ST_Cold_Category ON dbo.SeattleSafety_Cold ([category]) WITH FULLSCAN;
GO

-- Now re-run the same query with stats in place. Compare the two plans:
-- the estimated row count on the external-table scan should be much closer
-- to the actual row count than it was in the "before" run.
SELECT category, COUNT(*) AS cnt
FROM dbo.SeattleSafety_Cold
GROUP BY category
ORDER BY cnt DESC;
GO

-- =============================================================================
-- Test 4: Partition elimination — filepath() filter effectiveness
-- =============================================================================
-- Compare full scan vs filtered scan on the OPENROWSET view.

-- Full scan (all years)
SELECT COUNT(*) AS all_years_count
FROM dbo.vw_SeattleSafety_Cold;
GO

-- Partition elimination (single year)
SELECT COUNT(*) AS single_year_count
FROM dbo.vw_SeattleSafety_Cold
WHERE year_folder = '2022';
GO

-- Multiple years with partition elimination
SELECT COUNT(*) AS two_years_count
FROM dbo.vw_SeattleSafety_Cold
WHERE year_folder IN ('2021', '2022');
GO

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- =============================================================================
-- Summary: After running, compare elapsed times in the Messages tab.
-- =============================================================================
-- Test 1: Direct folder OPENROWSET should be significantly faster than YEAR()
-- Test 2: Explicit WITH clause should be slightly faster (less inference)
-- Test 3: With statistics, execution plans should show better estimates
-- Test 4: Partition elimination should scale linearly with # of years filtered
-- =============================================================================
