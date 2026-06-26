-- =============================================================================
-- Step 4.c - OPENROWSET vs External Table (compare with views)
-- Dataset: Public Holidays
-- Source:  https://learn.microsoft.com/azure/open-datasets/dataset-public-holidays
-- Storage: abs://holidaydatacontainer@azureopendatastorage.blob.core.windows.net/Processed/  (public, anonymous read - no credential required)
-- Platform: Azure SQL Database (Data Virtualization enabled by default)
-- =============================================================================
-- Goal: wrap BOTH access methods in views with identical shapes so they can be
--       compared side by side.
--         * dbo.vw_PublicHolidays_OpenRowset  -> OPENROWSET (ad-hoc, schema via WITH)
--         * dbo.vw_PublicHolidays_External    -> the external table from script 02
-- Prerequisite: run 02-ExternalTable.sql first (creates dbo.PublicHolidays_External).
-- Run this script connected to the [PublicHolidays] database.
-- =============================================================================

-- =============================================================================
-- Step 1: View over OPENROWSET
-- =============================================================================
CREATE OR ALTER VIEW dbo.vw_PublicHolidays_OpenRowset
AS
SELECT
    [countryOrRegion],
    [holidayName],
    [normalizeHolidayName],
    [isPaidTimeOff],
    [countryRegionCode],
    [date]
FROM OPENROWSET(
    BULK 'abs://holidaydatacontainer@azureopendatastorage.blob.core.windows.net/Processed/*.parquet',
    FORMAT = 'PARQUET'
) WITH (
    [countryOrRegion]      VARCHAR(256),
    [holidayName]          VARCHAR(512),
    [normalizeHolidayName] VARCHAR(512),
    [isPaidTimeOff]        BIT,
    [countryRegionCode]    VARCHAR(50),
    [date]                 DATETIME2(7)
) AS [src];
GO

-- =============================================================================
-- Step 2: View over the external table
-- =============================================================================
CREATE OR ALTER VIEW dbo.vw_PublicHolidays_External
AS
SELECT * FROM dbo.PublicHolidays_External;
GO

-- =============================================================================
-- Step 3: Same shape, two engines - row counts should match
-- =============================================================================
SELECT COUNT(*) AS rows_via_openrowset FROM dbo.vw_PublicHolidays_OpenRowset;
GO
SELECT COUNT(*) AS rows_via_external   FROM dbo.vw_PublicHolidays_External;
GO

-- =============================================================================
-- Step 4: Compare - Number of holidays by country/region
-- =============================================================================
-- This dataset is not folder-partitioned, so the comparison highlights the
-- other trade-offs: the external table supports CREATE STATISTICS and shows
-- up in catalog views, while the OPENROWSET view pins the schema via WITH
-- (no re-inference) and can be edited without DDL on the external object.

SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

-- OPENROWSET view
SELECT TOP 20 countryOrRegion, COUNT(*) AS holiday_count
FROM dbo.vw_PublicHolidays_OpenRowset
GROUP BY countryOrRegion
ORDER BY holiday_count DESC;
GO

-- External-table view
SELECT TOP 20 countryOrRegion, COUNT(*) AS holiday_count
FROM dbo.vw_PublicHolidays_External
GROUP BY countryOrRegion
ORDER BY holiday_count DESC;
GO

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- =============================================================================
-- Cleanup (optional)
-- =============================================================================
-- DROP VIEW IF EXISTS dbo.vw_PublicHolidays_OpenRowset;
-- DROP VIEW IF EXISTS dbo.vw_PublicHolidays_External;
-- GO
