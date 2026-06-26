-- =============================================================================
-- Step 4.c - OPENROWSET vs External Table (compare with views)
-- Dataset: US State Employment, Hours and Earnings
-- Source:  https://learn.microsoft.com/azure/open-datasets/dataset-us-state-employment-earnings
-- Storage: abs://laborstatisticscontainer@azureopendatastorage.blob.core.windows.net/ehe_state/  (public, anonymous read - no credential required)
-- Platform: Azure SQL Database (Data Virtualization enabled by default)
-- =============================================================================
-- Goal: wrap BOTH access methods in views with identical shapes so they can be
--       compared side by side.
--         * dbo.vw_UsStateEmploymentEarnings_OpenRowset  -> OPENROWSET (ad-hoc, schema via WITH)
--         * dbo.vw_UsStateEmploymentEarnings_External    -> the external table from script 02
-- Prerequisite: run 02-ExternalTable.sql first (creates dbo.UsStateEmploymentEarnings_External).
-- Run this script connected to the [UsStateEmploymentEarnings] database.
-- =============================================================================

-- =============================================================================
-- Step 1: View over OPENROWSET
-- =============================================================================
CREATE OR ALTER VIEW dbo.vw_UsStateEmploymentEarnings_OpenRowset
AS
SELECT
    [area_code],
    [state_code],
    [data_type_code],
    [industry_code],
    [supersector_code],
    [series_id],
    [year],
    [period],
    [value],
    [footnote_codes],
    [seasonal],
    [supersector_name],
    [industry_name],
    [data_type_text],
    [state_name],
    [area_name]
FROM OPENROWSET(
    BULK 'abs://laborstatisticscontainer@azureopendatastorage.blob.core.windows.net/ehe_state/*.parquet',
    FORMAT = 'PARQUET'
) WITH (
    [area_code]        VARCHAR(50),
    [state_code]       VARCHAR(50),
    [data_type_code]   VARCHAR(50),
    [industry_code]    VARCHAR(50),
    [supersector_code] VARCHAR(50),
    [series_id]        VARCHAR(50),
    [year]             INT,
    [period]           VARCHAR(50),
    [value]            REAL,
    [footnote_codes]   VARCHAR(100),
    [seasonal]         VARCHAR(50),
    [supersector_name] VARCHAR(512),
    [industry_name]    VARCHAR(512),
    [data_type_text]   VARCHAR(512),
    [state_name]       VARCHAR(512),
    [area_name]        VARCHAR(512)
) AS [src];
GO

-- =============================================================================
-- Step 2: View over the external table
-- =============================================================================
CREATE OR ALTER VIEW dbo.vw_UsStateEmploymentEarnings_External
AS
SELECT * FROM dbo.UsStateEmploymentEarnings_External;
GO

-- =============================================================================
-- Step 3: Same shape, two engines - row counts should match
-- =============================================================================
SELECT COUNT(*) AS rows_via_openrowset FROM dbo.vw_UsStateEmploymentEarnings_OpenRowset;
GO
SELECT COUNT(*) AS rows_via_external   FROM dbo.vw_UsStateEmploymentEarnings_External;
GO

-- =============================================================================
-- Step 4: Compare - Observations by state
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
    state_name,
    COUNT(*)                              AS observations,
    CAST(AVG(value) AS DECIMAL(18,3))     AS avg_value
FROM dbo.vw_UsStateEmploymentEarnings_OpenRowset
GROUP BY state_name
ORDER BY observations DESC;
GO

-- External-table view
SELECT TOP 20
    state_name,
    COUNT(*)                              AS observations,
    CAST(AVG(value) AS DECIMAL(18,3))     AS avg_value
FROM dbo.vw_UsStateEmploymentEarnings_External
GROUP BY state_name
ORDER BY observations DESC;
GO

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- =============================================================================
-- Cleanup (optional)
-- =============================================================================
-- DROP VIEW IF EXISTS dbo.vw_UsStateEmploymentEarnings_OpenRowset;
-- DROP VIEW IF EXISTS dbo.vw_UsStateEmploymentEarnings_External;
-- GO
