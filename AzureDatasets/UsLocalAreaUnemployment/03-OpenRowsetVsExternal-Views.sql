-- =============================================================================
-- Step 4.c - OPENROWSET vs External Table (compare with views)
-- Dataset: US Local Area Unemployment Statistics
-- Source:  https://learn.microsoft.com/azure/open-datasets/dataset-us-local-unemployment
-- Storage: abs://laborstatisticscontainer@azureopendatastorage.blob.core.windows.net/laus/  (public, anonymous read - no credential required)
-- Platform: Azure SQL Database (Data Virtualization enabled by default)
-- =============================================================================
-- Goal: wrap BOTH access methods in views with identical shapes so they can be
--       compared side by side.
--         * dbo.vw_UsLocalAreaUnemployment_OpenRowset  -> OPENROWSET (ad-hoc, schema via WITH)
--         * dbo.vw_UsLocalAreaUnemployment_External    -> the external table from script 02
-- Prerequisite: run 02-ExternalTable.sql first (creates dbo.UsLocalAreaUnemployment_External).
-- Run this script connected to the [UsLocalAreaUnemployment] database.
-- =============================================================================

-- =============================================================================
-- Step 1: View over OPENROWSET
-- =============================================================================
CREATE OR ALTER VIEW dbo.vw_UsLocalAreaUnemployment_OpenRowset
AS
SELECT
    [area_code],
    [area_type_code],
    [srd_code],
    [measure_code],
    [series_id],
    [year],
    [period],
    [value],
    [footnote_codes],
    [seasonal],
    [series_title],
    [measure_text],
    [srd_text],
    [areatype_text],
    [area_text]
FROM OPENROWSET(
    BULK 'abs://laborstatisticscontainer@azureopendatastorage.blob.core.windows.net/laus/*.parquet',
    FORMAT = 'PARQUET'
) WITH (
    [area_code]      VARCHAR(50),
    [area_type_code] VARCHAR(50),
    [srd_code]       VARCHAR(50),
    [measure_code]   VARCHAR(50),
    [series_id]      VARCHAR(50),
    [year]           INT,
    [period]         VARCHAR(50),
    [value]          REAL,
    [footnote_codes] VARCHAR(100),
    [seasonal]       VARCHAR(50),
    [series_title]   VARCHAR(512),
    [measure_text]   VARCHAR(512),
    [srd_text]       VARCHAR(512),
    [areatype_text]  VARCHAR(512),
    [area_text]      VARCHAR(512)
) AS [src];
GO

-- =============================================================================
-- Step 2: View over the external table
-- =============================================================================
CREATE OR ALTER VIEW dbo.vw_UsLocalAreaUnemployment_External
AS
SELECT * FROM dbo.UsLocalAreaUnemployment_External;
GO

-- =============================================================================
-- Step 3: Same shape, two engines - row counts should match
-- =============================================================================
SELECT COUNT(*) AS rows_via_openrowset FROM dbo.vw_UsLocalAreaUnemployment_OpenRowset;
GO
SELECT COUNT(*) AS rows_via_external   FROM dbo.vw_UsLocalAreaUnemployment_External;
GO

-- =============================================================================
-- Step 4: Compare - Observations and average value by area
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
    area_text,
    COUNT(*)                              AS observations,
    CAST(AVG(value) AS DECIMAL(18,3))     AS avg_value
FROM dbo.vw_UsLocalAreaUnemployment_OpenRowset
GROUP BY area_text
ORDER BY observations DESC;
GO

-- External-table view
SELECT TOP 20
    area_text,
    COUNT(*)                              AS observations,
    CAST(AVG(value) AS DECIMAL(18,3))     AS avg_value
FROM dbo.vw_UsLocalAreaUnemployment_External
GROUP BY area_text
ORDER BY observations DESC;
GO

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- =============================================================================
-- Cleanup (optional)
-- =============================================================================
-- DROP VIEW IF EXISTS dbo.vw_UsLocalAreaUnemployment_OpenRowset;
-- DROP VIEW IF EXISTS dbo.vw_UsLocalAreaUnemployment_External;
-- GO
