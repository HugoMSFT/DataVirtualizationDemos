-- =============================================================================
-- Step 4.b - External Table over the Parquet files
-- Dataset: US Labor Force Statistics
-- Source:  https://learn.microsoft.com/azure/open-datasets/dataset-us-labor-force
-- Storage: abs://laborstatisticscontainer@azureopendatastorage.blob.core.windows.net/lfs/  (public, anonymous read - no credential required)
-- Platform: Azure SQL Database (Data Virtualization enabled by default)
-- =============================================================================
-- Goal: expose the remote Parquet as a regular table via an external data
--       source + file format + CREATE EXTERNAL TABLE. End users query it with
--       plain SELECT - no OPENROWSET, no storage URLs.
-- Run this script connected to the [UsLaborForceStatistics] database (created in 01).
-- =============================================================================

-- =============================================================================
-- Step 1: External data source (points at the dataset's storage folder)
-- =============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.external_data_sources WHERE name = 'UsLaborForceStatisticsDS')
    CREATE EXTERNAL DATA SOURCE UsLaborForceStatisticsDS
    WITH (
        LOCATION = 'abs://laborstatisticscontainer@azureopendatastorage.blob.core.windows.net/lfs'
    );
GO

-- =============================================================================
-- Step 2: External file format (Parquet)
-- =============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.external_file_formats WHERE name = 'ParquetFormat')
    CREATE EXTERNAL FILE FORMAT ParquetFormat
    WITH (
        FORMAT_TYPE = PARQUET
    );
GO

-- =============================================================================
-- Step 3: External table (explicit schema - matches the Parquet physical types)
-- =============================================================================
-- LOCATION '/' is relative to the data source and reads every Parquet file
-- under the folder (PolyBase skips paths beginning with '_' or '.').
IF OBJECT_ID('dbo.UsLaborForceStatistics_External') IS NOT NULL
    DROP EXTERNAL TABLE dbo.UsLaborForceStatistics_External;
GO

CREATE EXTERNAL TABLE dbo.UsLaborForceStatistics_External
(
    [series_id]        VARCHAR(50),
    [year]             INT,
    [period]           VARCHAR(50),
    [value]            REAL,
    [footnote_codes]   VARCHAR(100),
    [lfst_code]        INT,
    [periodicity_code] VARCHAR(50),
    [series_title]     VARCHAR(512),
    [absn_code]        INT,
    [activity_code]    INT,
    [ages_code]        INT,
    [cert_code]        INT,
    [class_code]       INT,
    [duration_code]    INT,
    [education_code]   INT,
    [entr_code]        INT,
    [expr_code]        INT,
    [hheader_code]     INT,
    [hour_code]        INT,
    [indy_code]        INT,
    [jdes_code]        INT,
    [look_code]        INT,
    [mari_code]        INT,
    [mjhs_code]        INT,
    [occupation_code]  INT,
    [orig_code]        INT,
    [pcts_code]        INT,
    [race_code]        INT,
    [rjnw_code]        INT,
    [rnlf_code]        INT,
    [rwns_code]        INT,
    [seek_code]        INT,
    [sexs_code]        INT,
    [tdat_code]        INT,
    [vets_code]        INT,
    [wkst_code]        INT,
    [born_code]        INT,
    [chld_code]        INT,
    [disa_code]        INT,
    [seasonal]         VARCHAR(50)
)
WITH (
    DATA_SOURCE = UsLaborForceStatisticsDS,
    LOCATION    = '/',
    FILE_FORMAT = ParquetFormat
);
GO

-- Statistics give the optimizer accurate cardinality estimates. External
-- tables only support FULLSCAN (the engine scans the remote data once).
CREATE STATISTICS ST_UsLaborForceStatistics_series_id ON dbo.UsLaborForceStatistics_External ([series_id]) WITH FULLSCAN;
CREATE STATISTICS ST_UsLaborForceStatistics_year ON dbo.UsLaborForceStatistics_External ([year]) WITH FULLSCAN;
CREATE STATISTICS ST_UsLaborForceStatistics_period ON dbo.UsLaborForceStatistics_External ([period]) WITH FULLSCAN;
GO

-- =============================================================================
-- Step 4: Query the external table - just like a regular table
-- =============================================================================
SELECT TOP 50 *
FROM dbo.UsLaborForceStatistics_External;
GO

-- Inspect the external table definition
SELECT c.column_id, c.name, t.name AS data_type, c.max_length
FROM sys.external_table_columns AS c
JOIN sys.types AS t ON c.user_type_id = t.user_type_id
WHERE c.object_id = OBJECT_ID('dbo.UsLaborForceStatistics_External')
ORDER BY c.column_id;
GO
