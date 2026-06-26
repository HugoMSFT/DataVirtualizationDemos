-- =============================================================================
-- Step 4.c - OPENROWSET vs External Table (compare with views)
-- Dataset: NYC Taxi & Limousine - For-Hire Vehicle Trips
-- Source:  https://learn.microsoft.com/azure/open-datasets/dataset-taxi-for-hire-vehicle
-- Storage: abs://nyctlc@azureopendatastorage.blob.core.windows.net/fhv/  (public, anonymous read - no credential required)
-- Platform: Azure SQL Database (Data Virtualization enabled by default)
-- =============================================================================
-- Goal: wrap BOTH access methods in views with identical shapes so they can be
--       compared side by side.
--         * dbo.vw_NycTaxiForHireVehicle_OpenRowset  -> OPENROWSET (ad-hoc, schema via WITH)
--         * dbo.vw_NycTaxiForHireVehicle_External    -> the external table from script 02
-- Prerequisite: run 02-ExternalTable.sql first (creates dbo.NycTaxiForHireVehicle_External).
-- Run this script connected to the [NycTaxiForHireVehicle] database.
-- =============================================================================

-- =============================================================================
-- Step 1: View over OPENROWSET
-- =============================================================================
CREATE OR ALTER VIEW dbo.vw_NycTaxiForHireVehicle_OpenRowset
AS
SELECT
    [src].filepath(1) AS [puYear],
    [src].filepath(2) AS [puMonth],
    [dispatchBaseNum],
    [pickupDateTime],
    [dropOffDateTime],
    [puLocationId],
    [doLocationId],
    [srFlag]
FROM OPENROWSET(
    BULK 'abs://nyctlc@azureopendatastorage.blob.core.windows.net/fhv/puYear=*/puMonth=*/*.parquet',
    FORMAT = 'PARQUET'
) WITH (
    [dispatchBaseNum] VARCHAR(50),
    [pickupDateTime]  DATETIME2(7),
    [dropOffDateTime] DATETIME2(7),
    [puLocationId]    VARCHAR(50),
    [doLocationId]    VARCHAR(50),
    [srFlag]          VARCHAR(50)
) AS [src];
GO

-- =============================================================================
-- Step 2: View over the external table
-- =============================================================================
CREATE OR ALTER VIEW dbo.vw_NycTaxiForHireVehicle_External
AS
SELECT * FROM dbo.NycTaxiForHireVehicle_External;
GO

-- =============================================================================
-- Step 3: Same shape, two engines - row counts should match
-- =============================================================================
SELECT COUNT(*) AS rows_via_openrowset FROM dbo.vw_NycTaxiForHireVehicle_OpenRowset;
GO
SELECT COUNT(*) AS rows_via_external   FROM dbo.vw_NycTaxiForHireVehicle_External;
GO

-- =============================================================================
-- Step 4: Compare - Trip volume by dispatching base
-- =============================================================================
-- WARNING: these two views span the FULL multi-GB dataset (all partitions).
-- The OPENROWSET view below keeps a partition filter so it stays cheap; the
-- external-table view has no partition column to filter on and will scan the
-- entire remote dataset - expect a long-running, higher-cost query.

-- The OPENROWSET view exposes the partition folders via filepath(), which
-- enables PARTITION ELIMINATION: filtering on a partition column makes the
-- engine skip non-matching folders. An external table cannot expose
-- filepath() through a view, so it must scan everything.

SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

-- OPENROWSET view
SELECT TOP 20 dispatchBaseNum, COUNT(*) AS trips
FROM dbo.vw_NycTaxiForHireVehicle_OpenRowset
WHERE puYear = '2018'
GROUP BY dispatchBaseNum
ORDER BY trips DESC;
GO

-- External-table view
SELECT TOP 20 dispatchBaseNum, COUNT(*) AS trips
FROM dbo.vw_NycTaxiForHireVehicle_External
GROUP BY dispatchBaseNum
ORDER BY trips DESC;
GO

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- =============================================================================
-- Cleanup (optional)
-- =============================================================================
-- DROP VIEW IF EXISTS dbo.vw_NycTaxiForHireVehicle_OpenRowset;
-- DROP VIEW IF EXISTS dbo.vw_NycTaxiForHireVehicle_External;
-- GO
