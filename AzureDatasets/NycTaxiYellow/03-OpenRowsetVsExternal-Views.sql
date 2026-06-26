-- =============================================================================
-- Step 4.c - OPENROWSET vs External Table (compare with views)
-- Dataset: NYC Taxi & Limousine - Yellow Taxi Trips
-- Source:  https://learn.microsoft.com/azure/open-datasets/dataset-taxi-yellow
-- Storage: abs://nyctlc@azureopendatastorage.blob.core.windows.net/yellow/  (public, anonymous read - no credential required)
-- Platform: Azure SQL Database (Data Virtualization enabled by default)
-- =============================================================================
-- Goal: wrap BOTH access methods in views with identical shapes so they can be
--       compared side by side.
--         * dbo.vw_NycTaxiYellow_OpenRowset  -> OPENROWSET (ad-hoc, schema via WITH)
--         * dbo.vw_NycTaxiYellow_External    -> the external table from script 02
-- Prerequisite: run 02-ExternalTable.sql first (creates dbo.NycTaxiYellow_External).
-- Run this script connected to the [NycTaxiYellow] database.
-- =============================================================================

-- =============================================================================
-- Step 1: View over OPENROWSET
-- =============================================================================
CREATE OR ALTER VIEW dbo.vw_NycTaxiYellow_OpenRowset
AS
SELECT
    [src].filepath(1) AS [puYear],
    [src].filepath(2) AS [puMonth],
    [vendorID],
    [tpepPickupDateTime],
    [tpepDropoffDateTime],
    [passengerCount],
    [tripDistance],
    [puLocationId],
    [doLocationId],
    [startLon],
    [startLat],
    [endLon],
    [endLat],
    [rateCodeId],
    [storeAndFwdFlag],
    [paymentType],
    [fareAmount],
    [extra],
    [mtaTax],
    [improvementSurcharge],
    [tipAmount],
    [tollsAmount],
    [totalAmount]
FROM OPENROWSET(
    BULK 'abs://nyctlc@azureopendatastorage.blob.core.windows.net/yellow/puYear=*/puMonth=*/*.parquet',
    FORMAT = 'PARQUET'
) WITH (
    [vendorID]             VARCHAR(50),
    [tpepPickupDateTime]   DATETIME2(7),
    [tpepDropoffDateTime]  DATETIME2(7),
    [passengerCount]       INT,
    [tripDistance]         FLOAT,
    [puLocationId]         VARCHAR(50),
    [doLocationId]         VARCHAR(50),
    [startLon]             FLOAT,
    [startLat]             FLOAT,
    [endLon]               FLOAT,
    [endLat]               FLOAT,
    [rateCodeId]           INT,
    [storeAndFwdFlag]      VARCHAR(50),
    [paymentType]          VARCHAR(50),
    [fareAmount]           FLOAT,
    [extra]                FLOAT,
    [mtaTax]               FLOAT,
    [improvementSurcharge] VARCHAR(50),
    [tipAmount]            FLOAT,
    [tollsAmount]          FLOAT,
    [totalAmount]          FLOAT
) AS [src];
GO

-- =============================================================================
-- Step 2: View over the external table
-- =============================================================================
CREATE OR ALTER VIEW dbo.vw_NycTaxiYellow_External
AS
SELECT * FROM dbo.NycTaxiYellow_External;
GO

-- =============================================================================
-- Step 3: Same shape, two engines - row counts should match
-- =============================================================================
SELECT COUNT(*) AS rows_via_openrowset FROM dbo.vw_NycTaxiYellow_OpenRowset;
GO
SELECT COUNT(*) AS rows_via_external   FROM dbo.vw_NycTaxiYellow_External;
GO

-- =============================================================================
-- Step 4: Compare - Trips, average fare and distance by payment type
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
SELECT paymentType,
    COUNT(*)                            AS trips,
    CAST(AVG(fareAmount)  AS DECIMAL(10,2)) AS avg_fare,
    CAST(AVG(tripDistance) AS DECIMAL(10,2)) AS avg_miles
FROM dbo.vw_NycTaxiYellow_OpenRowset
WHERE puYear = '2018'
GROUP BY paymentType
ORDER BY trips DESC;
GO

-- External-table view
SELECT paymentType,
    COUNT(*)                            AS trips,
    CAST(AVG(fareAmount)  AS DECIMAL(10,2)) AS avg_fare,
    CAST(AVG(tripDistance) AS DECIMAL(10,2)) AS avg_miles
FROM dbo.vw_NycTaxiYellow_External
GROUP BY paymentType
ORDER BY trips DESC;
GO

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- =============================================================================
-- Cleanup (optional)
-- =============================================================================
-- DROP VIEW IF EXISTS dbo.vw_NycTaxiYellow_OpenRowset;
-- DROP VIEW IF EXISTS dbo.vw_NycTaxiYellow_External;
-- GO
