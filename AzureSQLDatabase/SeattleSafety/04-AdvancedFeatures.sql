-- =============================================================================
-- Demo: Advanced Features — Geospatial & Introspection DMVs
-- Dataset: Seattle Safety (Fire Department 911 Dispatches)
-- Source: https://learn.microsoft.com/en-us/azure/open-datasets/dataset-seattle-safety
-- Platform: Azure SQL Database (Data Virtualization enabled by default)
-- =============================================================================
-- This script shows advanced capabilities you can use on virtualized data:
-- geospatial analysis and execution plan / DMV introspection.
-- Prerequisite: Run 03-ExternalTables.sql (creates dbo.SeattleSafety_External).
-- =============================================================================

-- =============================================================================
-- Step 1: Schema discovery via DMV (alternative to sp_describe_first_result_set)
-- =============================================================================

-- sys.dm_exec_describe_first_result_set is the DMV equivalent —
-- useful when you want to JOIN/filter the metadata programmatically.

SELECT 
    name,
    system_type_name,
    is_nullable,
    max_length
FROM sys.dm_exec_describe_first_result_set(
    N'SELECT * FROM OPENROWSET(
        BULK ''abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=Seattle/*.parquet'',
        FORMAT = ''PARQUET''
    ) AS x',
    NULL,
    NULL
);
GO

-- =============================================================================
-- Step 2: Geospatial queries on virtualized data
-- =============================================================================

-- Convert lat/long into SQL Server geography points — directly from Parquet.
-- No need to ingest the data first.

SELECT TOP 20
    category,
    address,
    geography::Point(latitude, longitude, 4326) AS Location
FROM dbo.SeattleSafety_External
WHERE latitude IS NOT NULL
  AND longitude IS NOT NULL;
GO

-- Downtown Seattle bounding-box aggregation
-- Analyze incident density in the downtown core without loading any data.
SELECT
    category,
    COUNT(*) AS IncidentCount
FROM dbo.SeattleSafety_External
WHERE latitude  BETWEEN 47.55 AND 47.65
  AND longitude BETWEEN -122.35 AND -122.25
GROUP BY category
ORDER BY IncidentCount DESC;
GO

-- Distance calculation: incidents within 1 km of the Space Needle
-- (reference point: 47.6205, -122.3493).
-- The WHERE clause bounds the result so we're actually demonstrating spatial
-- filtering, not just "show me the 20 closest points".
DECLARE @ref geography = geography::Point(47.6205, -122.3493, 4326);

SELECT TOP 20
    category,
    address,
    dateTime,
    geography::Point(latitude, longitude, 4326).STDistance(@ref) / 1000.0 AS distance_km
FROM dbo.SeattleSafety_External
WHERE latitude IS NOT NULL
  AND longitude IS NOT NULL
  AND geography::Point(latitude, longitude, 4326).STDistance(@ref) <= 1000 -- 1 km
ORDER BY distance_km ASC;
GO

-- =============================================================================
-- Step 3: Execution plan introspection
-- =============================================================================

-- After running queries against external tables, check if the engine
-- pushed predicates down to the remote scan (partition elimination, etc.)

-- Find recent query plans that reference the external table
SELECT TOP 5
    qs.last_execution_time,
    qs.execution_count,
    SUBSTRING(st.text, 1, 200) AS query_text,
    qp.query_plan
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) AS qp
WHERE st.text LIKE '%SeattleSafety%'
  AND st.text NOT LIKE '%dm_exec_query_stats%'   -- exclude this query itself
ORDER BY qs.last_execution_time DESC;
GO

-- =============================================================================
-- Step 4: Predicate pushdown evidence (sys.dm_exec_external_work)
-- =============================================================================
-- sys.dm_exec_external_work shows details about remote data scans: how many
-- bytes the engine actually pulled from blob storage. Comparing an unfiltered
-- query to a filtered one on the same external table shows predicate
-- pushdown in action — fewer bytes read when the filter can be pushed down.

IF OBJECT_ID('sys.dm_exec_external_work') IS NULL
BEGIN
    PRINT 'sys.dm_exec_external_work is not available on this SKU — skipping.';
END
ELSE
BEGIN
    -- Baseline: full aggregate, no WHERE
    SELECT COUNT(*) AS rows_all FROM dbo.SeattleSafety_External;

    -- Filtered: single category. If pushdown works, bytes_processed for this
    -- execution should be smaller than for the baseline above.
    SELECT COUNT(*) AS rows_medic
    FROM dbo.SeattleSafety_External
    WHERE category = 'Medic Response';

    -- Show the two most recent external-work rows side by side.
    SELECT TOP 5
        start_time,
        end_time,
        session_id,
        request_id,
        bytes_processed,
        rows_processed
    FROM sys.dm_exec_external_work
    ORDER BY start_time DESC;
END
GO
