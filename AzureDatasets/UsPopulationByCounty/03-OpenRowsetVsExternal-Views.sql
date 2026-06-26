-- =============================================================================
-- Step 4.c - OPENROWSET vs External Table (compare with views)
-- Dataset: US Population by County
-- Source:  https://learn.microsoft.com/azure/open-datasets/dataset-us-population-county
-- Storage: abs://censusdatacontainer@azureopendatastorage.blob.core.windows.net/release/us_population_county/  (public, anonymous read - no credential required)
-- Platform: Azure SQL Database (Data Virtualization enabled by default)
-- =============================================================================
-- Goal: wrap BOTH access methods in views with identical shapes so they can be
--       compared side by side.
--         * dbo.vw_UsPopulationByCounty_OpenRowset  -> OPENROWSET (ad-hoc, schema via WITH)
--         * dbo.vw_UsPopulationByCounty_External    -> the external table from script 02
-- Prerequisite: run 02-ExternalTable.sql first (creates dbo.UsPopulationByCounty_External).
-- Run this script connected to the [UsPopulationByCounty] database.
-- =============================================================================

-- =============================================================================
-- Step 1: View over OPENROWSET
-- =============================================================================
CREATE OR ALTER VIEW dbo.vw_UsPopulationByCounty_OpenRowset
AS
SELECT
    [src].filepath(1) AS [censusYear],
    [decennialTime],
    [stateName],
    [countyName],
    [population],
    [race],
    [sex],
    [minAge],
    [maxAge]
FROM OPENROWSET(
    BULK 'abs://censusdatacontainer@azureopendatastorage.blob.core.windows.net/release/us_population_county/year=*/*.parquet',
    FORMAT = 'PARQUET'
) WITH (
    [decennialTime] VARCHAR(50),
    [stateName]     VARCHAR(256),
    [countyName]    VARCHAR(256),
    [population]    INT,
    [race]          VARCHAR(50),
    [sex]           VARCHAR(50),
    [minAge]        INT,
    [maxAge]        INT
) AS [src];
GO

-- =============================================================================
-- Step 2: View over the external table
-- =============================================================================
CREATE OR ALTER VIEW dbo.vw_UsPopulationByCounty_External
AS
SELECT * FROM dbo.UsPopulationByCounty_External;
GO

-- =============================================================================
-- Step 3: Same shape, two engines - row counts should match
-- =============================================================================
SELECT COUNT(*) AS rows_via_openrowset FROM dbo.vw_UsPopulationByCounty_OpenRowset;
GO
SELECT COUNT(*) AS rows_via_external   FROM dbo.vw_UsPopulationByCounty_External;
GO

-- =============================================================================
-- Step 4: Compare - Total 2010 population by state
-- =============================================================================
-- The OPENROWSET view exposes the partition folders via filepath(), which
-- enables PARTITION ELIMINATION: filtering on a partition column makes the
-- engine skip non-matching folders. An external table cannot expose
-- filepath() through a view, so it must scan everything.

SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

-- OPENROWSET view
SELECT TOP 20 stateName, SUM(CAST(population AS BIGINT)) AS total_population
FROM dbo.vw_UsPopulationByCounty_OpenRowset
WHERE censusYear = '2010'
GROUP BY stateName
ORDER BY total_population DESC;
GO

-- External-table view
SELECT TOP 20 stateName, SUM(CAST(population AS BIGINT)) AS total_population
FROM dbo.vw_UsPopulationByCounty_External
WHERE decennialTime = '2010'
GROUP BY stateName
ORDER BY total_population DESC;
GO

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- =============================================================================
-- Cleanup (optional)
-- =============================================================================
-- DROP VIEW IF EXISTS dbo.vw_UsPopulationByCounty_OpenRowset;
-- DROP VIEW IF EXISTS dbo.vw_UsPopulationByCounty_External;
-- GO
