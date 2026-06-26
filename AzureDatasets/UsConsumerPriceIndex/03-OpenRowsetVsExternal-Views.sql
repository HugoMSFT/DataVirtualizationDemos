-- =============================================================================
-- Step 4.c - OPENROWSET vs External Table (compare with views)
-- Dataset: US Consumer Price Index
-- Source:  https://learn.microsoft.com/azure/open-datasets/dataset-us-consumer-price-index
-- Storage: abs://laborstatisticscontainer@azureopendatastorage.blob.core.windows.net/cpi/  (public, anonymous read - no credential required)
-- Platform: Azure SQL Database (Data Virtualization enabled by default)
-- =============================================================================
-- Goal: wrap BOTH access methods in views with identical shapes so they can be
--       compared side by side.
--         * dbo.vw_UsConsumerPriceIndex_OpenRowset  -> OPENROWSET (ad-hoc, schema via WITH)
--         * dbo.vw_UsConsumerPriceIndex_External    -> the external table from script 02
-- Prerequisite: run 02-ExternalTable.sql first (creates dbo.UsConsumerPriceIndex_External).
-- Run this script connected to the [UsConsumerPriceIndex] database.
-- =============================================================================

-- =============================================================================
-- Step 1: View over OPENROWSET
-- =============================================================================
CREATE OR ALTER VIEW dbo.vw_UsConsumerPriceIndex_OpenRowset
AS
SELECT
    [area_code],
    [item_code],
    [series_id],
    [year],
    [period],
    [value],
    [footnote_codes],
    [seasonal],
    [periodicity_code],
    [series_title],
    [item_name],
    [area_name]
FROM OPENROWSET(
    BULK 'abs://laborstatisticscontainer@azureopendatastorage.blob.core.windows.net/cpi/*.parquet',
    FORMAT = 'PARQUET'
) WITH (
    [area_code]        VARCHAR(50),
    [item_code]        VARCHAR(50),
    [series_id]        VARCHAR(50),
    [year]             INT,
    [period]           VARCHAR(50),
    [value]            REAL,
    [footnote_codes]   VARCHAR(100),
    [seasonal]         VARCHAR(50),
    [periodicity_code] VARCHAR(50),
    [series_title]     VARCHAR(512),
    [item_name]        VARCHAR(512),
    [area_name]        VARCHAR(512)
) AS [src];
GO

-- =============================================================================
-- Step 2: View over the external table
-- =============================================================================
CREATE OR ALTER VIEW dbo.vw_UsConsumerPriceIndex_External
AS
SELECT * FROM dbo.UsConsumerPriceIndex_External;
GO

-- =============================================================================
-- Step 3: Same shape, two engines - row counts should match
-- =============================================================================
SELECT COUNT(*) AS rows_via_openrowset FROM dbo.vw_UsConsumerPriceIndex_OpenRowset;
GO
SELECT COUNT(*) AS rows_via_external   FROM dbo.vw_UsConsumerPriceIndex_External;
GO

-- =============================================================================
-- Step 4: Compare - Observations and average index by area
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
    area_name,
    COUNT(*)                              AS observations,
    CAST(AVG(value) AS DECIMAL(18,3))     AS avg_value
FROM dbo.vw_UsConsumerPriceIndex_OpenRowset
GROUP BY area_name
ORDER BY observations DESC;
GO

-- External-table view
SELECT TOP 20
    area_name,
    COUNT(*)                              AS observations,
    CAST(AVG(value) AS DECIMAL(18,3))     AS avg_value
FROM dbo.vw_UsConsumerPriceIndex_External
GROUP BY area_name
ORDER BY observations DESC;
GO

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- =============================================================================
-- Cleanup (optional)
-- =============================================================================
-- DROP VIEW IF EXISTS dbo.vw_UsConsumerPriceIndex_OpenRowset;
-- DROP VIEW IF EXISTS dbo.vw_UsConsumerPriceIndex_External;
-- GO
