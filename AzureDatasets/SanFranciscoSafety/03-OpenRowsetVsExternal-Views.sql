-- =============================================================================
-- Step 4.c - OPENROWSET vs External Table (compare with views)
-- Dataset: San Francisco Safety Data (311 + fire calls)
-- Source:  https://learn.microsoft.com/azure/open-datasets/dataset-san-francisco-safety
-- Storage: abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=SanFrancisco/  (public, anonymous read - no credential required)
-- Platform: Azure SQL Database (Data Virtualization enabled by default)
-- =============================================================================
-- Goal: wrap BOTH access methods in views with identical shapes so they can be
--       compared side by side.
--         * dbo.vw_SanFranciscoSafety_OpenRowset  -> OPENROWSET (ad-hoc, schema via WITH)
--         * dbo.vw_SanFranciscoSafety_External    -> the external table from script 02
-- Prerequisite: run 02-ExternalTable.sql first (creates dbo.SanFranciscoSafety_External).
-- Run this script connected to the [SanFranciscoSafety] database.
-- =============================================================================

-- =============================================================================
-- Step 1: View over OPENROWSET
-- =============================================================================
CREATE OR ALTER VIEW dbo.vw_SanFranciscoSafety_OpenRowset
AS
SELECT
    [dataType],
    [dataSubtype],
    [dateTime],
    [category],
    [subcategory],
    [status],
    [address],
    [latitude],
    [longitude],
    [source],
    [extendedProperties]
FROM OPENROWSET(
    BULK 'abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=SanFrancisco/*.parquet',
    FORMAT = 'PARQUET'
) WITH (
    [dataType]           VARCHAR(50),
    [dataSubtype]        VARCHAR(50),
    [dateTime]           DATETIME2(7),
    [category]           VARCHAR(256),
    [subcategory]        VARCHAR(256),
    [status]             VARCHAR(256),
    [address]            VARCHAR(500),
    [latitude]           FLOAT,
    [longitude]          FLOAT,
    [source]             VARCHAR(50),
    [extendedProperties] VARCHAR(4000)
) AS [src];
GO

-- =============================================================================
-- Step 2: View over the external table
-- =============================================================================
CREATE OR ALTER VIEW dbo.vw_SanFranciscoSafety_External
AS
SELECT * FROM dbo.SanFranciscoSafety_External;
GO

-- =============================================================================
-- Step 3: Same shape, two engines - row counts should match
-- =============================================================================
SELECT COUNT(*) AS rows_via_openrowset FROM dbo.vw_SanFranciscoSafety_OpenRowset;
GO
SELECT COUNT(*) AS rows_via_external   FROM dbo.vw_SanFranciscoSafety_External;
GO

-- =============================================================================
-- Step 4: Compare - Incident volume by response category
-- =============================================================================
-- This dataset is not folder-partitioned, so the comparison highlights the
-- other trade-offs: the external table supports CREATE STATISTICS and shows
-- up in catalog views, while the OPENROWSET view pins the schema via WITH
-- (no re-inference) and can be edited without DDL on the external object.

SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

-- OPENROWSET view
SELECT category, COUNT(*) AS incident_count
FROM dbo.vw_SanFranciscoSafety_OpenRowset
GROUP BY category
ORDER BY incident_count DESC;
GO

-- External-table view
SELECT category, COUNT(*) AS incident_count
FROM dbo.vw_SanFranciscoSafety_External
GROUP BY category
ORDER BY incident_count DESC;
GO

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- =============================================================================
-- Cleanup (optional)
-- =============================================================================
-- DROP VIEW IF EXISTS dbo.vw_SanFranciscoSafety_OpenRowset;
-- DROP VIEW IF EXISTS dbo.vw_SanFranciscoSafety_External;
-- GO
