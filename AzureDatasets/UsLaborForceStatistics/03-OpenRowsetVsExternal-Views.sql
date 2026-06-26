-- =============================================================================
-- Step 4.c - OPENROWSET vs External Table (compare with views)
-- Dataset: US Labor Force Statistics
-- Source:  https://learn.microsoft.com/azure/open-datasets/dataset-us-labor-force
-- Storage: abs://laborstatisticscontainer@azureopendatastorage.blob.core.windows.net/lfs/  (public, anonymous read - no credential required)
-- Platform: Azure SQL Database (Data Virtualization enabled by default)
-- =============================================================================
-- Goal: wrap BOTH access methods in views with identical shapes so they can be
--       compared side by side.
--         * dbo.vw_UsLaborForceStatistics_OpenRowset  -> OPENROWSET (ad-hoc, schema via WITH)
--         * dbo.vw_UsLaborForceStatistics_External    -> the external table from script 02
-- Prerequisite: run 02-ExternalTable.sql first (creates dbo.UsLaborForceStatistics_External).
-- Run this script connected to the [UsLaborForceStatistics] database.
-- =============================================================================

-- =============================================================================
-- Step 1: View over OPENROWSET
-- =============================================================================
CREATE OR ALTER VIEW dbo.vw_UsLaborForceStatistics_OpenRowset
AS
SELECT
    [series_id],
    [year],
    [period],
    [value],
    [footnote_codes],
    [lfst_code],
    [periodicity_code],
    [series_title],
    [absn_code],
    [activity_code],
    [ages_code],
    [cert_code],
    [class_code],
    [duration_code],
    [education_code],
    [entr_code],
    [expr_code],
    [hheader_code],
    [hour_code],
    [indy_code],
    [jdes_code],
    [look_code],
    [mari_code],
    [mjhs_code],
    [occupation_code],
    [orig_code],
    [pcts_code],
    [race_code],
    [rjnw_code],
    [rnlf_code],
    [rwns_code],
    [seek_code],
    [sexs_code],
    [tdat_code],
    [vets_code],
    [wkst_code],
    [born_code],
    [chld_code],
    [disa_code],
    [seasonal]
FROM OPENROWSET(
    BULK 'abs://laborstatisticscontainer@azureopendatastorage.blob.core.windows.net/lfs/*.parquet',
    FORMAT = 'PARQUET'
) WITH (
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
) AS [src];
GO

-- =============================================================================
-- Step 2: View over the external table
-- =============================================================================
CREATE OR ALTER VIEW dbo.vw_UsLaborForceStatistics_External
AS
SELECT * FROM dbo.UsLaborForceStatistics_External;
GO

-- =============================================================================
-- Step 3: Same shape, two engines - row counts should match
-- =============================================================================
SELECT COUNT(*) AS rows_via_openrowset FROM dbo.vw_UsLaborForceStatistics_OpenRowset;
GO
SELECT COUNT(*) AS rows_via_external   FROM dbo.vw_UsLaborForceStatistics_External;
GO

-- =============================================================================
-- Step 4: Compare - Observations and average value by series
-- =============================================================================
-- This dataset is not folder-partitioned, so the comparison highlights the
-- other trade-offs: the external table supports CREATE STATISTICS and shows
-- up in catalog views, while the OPENROWSET view pins the schema via WITH
-- (no re-inference) and can be edited without DDL on the external object.

SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

-- OPENROWSET view
SELECT TOP 20
    series_title,
    COUNT(*)                              AS observations,
    CAST(AVG(value) AS DECIMAL(18,3))     AS avg_value
FROM dbo.vw_UsLaborForceStatistics_OpenRowset
GROUP BY series_title
ORDER BY observations DESC;
GO

-- External-table view
SELECT TOP 20
    series_title,
    COUNT(*)                              AS observations,
    CAST(AVG(value) AS DECIMAL(18,3))     AS avg_value
FROM dbo.vw_UsLaborForceStatistics_External
GROUP BY series_title
ORDER BY observations DESC;
GO

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- =============================================================================
-- Cleanup (optional)
-- =============================================================================
-- DROP VIEW IF EXISTS dbo.vw_UsLaborForceStatistics_OpenRowset;
-- DROP VIEW IF EXISTS dbo.vw_UsLaborForceStatistics_External;
-- GO
