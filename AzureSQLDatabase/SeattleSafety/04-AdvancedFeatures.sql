-- =============================================================================
-- Demo: Advanced Features — Geospatial & Introspection DMVs
-- Dataset: Seattle Safety (Fire Department 911 Dispatches)
-- Source: https://learn.microsoft.com/en-us/azure/open-datasets/dataset-seattle-safety
-- Platform: Azure SQL Database (with Data Virtualization enabled)
-- =============================================================================
-- This script shows advanced capabilities you can use on virtualized data:
-- geospatial analysis and execution plan / DMV introspection.
-- Prerequisite: Run 03-ExternalTables.sql (creates ext.SeattleSafety).
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
FROM ext.SeattleSafety
WHERE latitude IS NOT NULL
  AND longitude IS NOT NULL;
GO

-- Downtown Seattle bounding-box aggregation
-- Analyze incident density in the downtown core without loading any data.
SELECT
    category,
    COUNT(*) AS IncidentCount
FROM ext.SeattleSafety
WHERE latitude  BETWEEN 47.55 AND 47.65
  AND longitude BETWEEN -122.35 AND -122.25
GROUP BY category
ORDER BY IncidentCount DESC;
GO

-- Distance calculation: how far is each incident from a reference point?
-- (e.g., Space Needle at 47.6205, -122.3493)
SELECT TOP 20
    category,
    address,
    dateTime,
    geography::Point(latitude, longitude, 4326).STDistance(
        geography::Point(47.6205, -122.3493, 4326)
    ) / 1000.0 AS distance_km
FROM ext.SeattleSafety
WHERE latitude IS NOT NULL
  AND longitude IS NOT NULL
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
-- Step 4: External work DMV (if available on your SKU)
-- =============================================================================

-- sys.dm_exec_external_work shows details about remote data scans:
-- bytes read, rows returned, pushdown operations, etc.

IF OBJECT_ID('sys.dm_exec_external_work') IS NOT NULL
BEGIN
    SELECT TOP 50 *
    FROM sys.dm_exec_external_work
    ORDER BY start_time DESC;
END
GO
GO
