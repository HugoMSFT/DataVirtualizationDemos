-- =============================================================================
-- Consolidated Ingestion Script - Azure Open Datasets (Single Database)
-- Creates one table per dataset and ingests all datasets into one DB.
-- =============================================================================

IF DB_ID(N'AzureDatasetsUnified') IS NULL
    CREATE DATABASE [AzureDatasetsUnified];
GO

USE [AzureDatasetsUnified];
GO

-- =============================================================================
-- Safety Datasets
-- =============================================================================
DROP TABLE IF EXISTS dbo.BostonSafety_Local;
SELECT *
INTO dbo.BostonSafety_Local
FROM OPENROWSET(
    BULK 'abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=Boston/*.parquet',
    FORMAT = 'PARQUET'
) AS rows;
GO

DROP TABLE IF EXISTS dbo.ChicagoSafety_Local;
SELECT *
INTO dbo.ChicagoSafety_Local
FROM OPENROWSET(
    BULK 'abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=Chicago/*.parquet',
    FORMAT = 'PARQUET'
) AS rows;
GO

DROP TABLE IF EXISTS dbo.NewYorkCitySafety_Local;
SELECT *
INTO dbo.NewYorkCitySafety_Local
FROM OPENROWSET(
    BULK 'abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=NewYorkCity/*.parquet',
    FORMAT = 'PARQUET'
) AS rows;
GO

DROP TABLE IF EXISTS dbo.SanFranciscoSafety_Local;
SELECT *
INTO dbo.SanFranciscoSafety_Local
FROM OPENROWSET(
    BULK 'abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=SanFrancisco/*.parquet',
    FORMAT = 'PARQUET'
) AS rows;
GO

-- =============================================================================
-- NYC Taxi Datasets
-- =============================================================================
DROP TABLE IF EXISTS dbo.NycTaxiGreen_Local;
SELECT *
INTO dbo.NycTaxiGreen_Local
FROM OPENROWSET(
    BULK 'abs://nyctlc@azureopendatastorage.blob.core.windows.net/green/puYear=2018/puMonth=6/*.parquet',
    FORMAT = 'PARQUET'
) AS rows;
GO

DROP TABLE IF EXISTS dbo.NycTaxiYellow_Local;
SELECT *
INTO dbo.NycTaxiYellow_Local
FROM OPENROWSET(
    BULK 'abs://nyctlc@azureopendatastorage.blob.core.windows.net/yellow/puYear=2018/puMonth=6/*.parquet',
    FORMAT = 'PARQUET'
) AS rows;
GO

DROP TABLE IF EXISTS dbo.NycTaxiForHireVehicle_Local;
SELECT *
INTO dbo.NycTaxiForHireVehicle_Local
FROM OPENROWSET(
    BULK 'abs://nyctlc@azureopendatastorage.blob.core.windows.net/fhv/puYear=2018/puMonth=6/*.parquet',
    FORMAT = 'PARQUET'
) AS rows;
GO

-- =============================================================================
-- Holidays Dataset
-- =============================================================================
DROP TABLE IF EXISTS dbo.PublicHolidays_Local;
SELECT *
INTO dbo.PublicHolidays_Local
FROM OPENROWSET(
    BULK 'abs://holidaydatacontainer@azureopendatastorage.blob.core.windows.net/Processed/*.parquet',
    FORMAT = 'PARQUET'
) AS rows;
GO

-- =============================================================================
-- US Labor Statistics / Economic Datasets
-- =============================================================================
DROP TABLE IF EXISTS dbo.UsConsumerPriceIndex_Local;
SELECT *
INTO dbo.UsConsumerPriceIndex_Local
FROM OPENROWSET(
    BULK 'abs://laborstatisticscontainer@azureopendatastorage.blob.core.windows.net/cpi/*.parquet',
    FORMAT = 'PARQUET'
) AS rows;
GO

DROP TABLE IF EXISTS dbo.UsLaborForceStatistics_Local;
SELECT *
INTO dbo.UsLaborForceStatistics_Local
FROM OPENROWSET(
    BULK 'abs://laborstatisticscontainer@azureopendatastorage.blob.core.windows.net/lfs/*.parquet',
    FORMAT = 'PARQUET'
) AS rows;
GO

DROP TABLE IF EXISTS dbo.UsLocalAreaUnemployment_Local;
SELECT *
INTO dbo.UsLocalAreaUnemployment_Local
FROM OPENROWSET(
    BULK 'abs://laborstatisticscontainer@azureopendatastorage.blob.core.windows.net/laus/*.parquet',
    FORMAT = 'PARQUET'
) AS rows;
GO

DROP TABLE IF EXISTS dbo.UsNationalEmploymentEarnings_Local;
SELECT *
INTO dbo.UsNationalEmploymentEarnings_Local
FROM OPENROWSET(
    BULK 'abs://laborstatisticscontainer@azureopendatastorage.blob.core.windows.net/ehe_national/*.parquet',
    FORMAT = 'PARQUET'
) AS rows;
GO

DROP TABLE IF EXISTS dbo.UsProducerPriceIndexCommodities_Local;
SELECT *
INTO dbo.UsProducerPriceIndexCommodities_Local
FROM OPENROWSET(
    BULK 'abs://laborstatisticscontainer@azureopendatastorage.blob.core.windows.net/ppi_commodity/*.parquet',
    FORMAT = 'PARQUET'
) AS rows;
GO

DROP TABLE IF EXISTS dbo.UsProducerPriceIndexIndustry_Local;
SELECT *
INTO dbo.UsProducerPriceIndexIndustry_Local
FROM OPENROWSET(
    BULK 'abs://laborstatisticscontainer@azureopendatastorage.blob.core.windows.net/ppi_industry/*.parquet',
    FORMAT = 'PARQUET'
) AS rows;
GO

DROP TABLE IF EXISTS dbo.UsStateEmploymentEarnings_Local;
SELECT *
INTO dbo.UsStateEmploymentEarnings_Local
FROM OPENROWSET(
    BULK 'abs://laborstatisticscontainer@azureopendatastorage.blob.core.windows.net/ehe_state/*.parquet',
    FORMAT = 'PARQUET'
) AS rows;
GO

-- =============================================================================
-- US Census Datasets
-- =============================================================================
DROP TABLE IF EXISTS dbo.UsPopulationByCounty_Local;
SELECT *
INTO dbo.UsPopulationByCounty_Local
FROM OPENROWSET(
    BULK 'abs://censusdatacontainer@azureopendatastorage.blob.core.windows.net/release/us_population_county/year=*/*.parquet',
    FORMAT = 'PARQUET'
) AS rows;
GO

DROP TABLE IF EXISTS dbo.UsPopulationByZip_Local;
SELECT *
INTO dbo.UsPopulationByZip_Local
FROM OPENROWSET(
    BULK 'abs://censusdatacontainer@azureopendatastorage.blob.core.windows.net/release/us_population_zip/year=*/*.parquet',
    FORMAT = 'PARQUET'
) AS rows;
GO

-- Quick row-count sanity check for all loaded tables.
SELECT 'BostonSafety_Local' AS table_name, COUNT_BIG(*) AS row_count FROM dbo.BostonSafety_Local
UNION ALL SELECT 'ChicagoSafety_Local', COUNT_BIG(*) FROM dbo.ChicagoSafety_Local
UNION ALL SELECT 'NewYorkCitySafety_Local', COUNT_BIG(*) FROM dbo.NewYorkCitySafety_Local
UNION ALL SELECT 'SanFranciscoSafety_Local', COUNT_BIG(*) FROM dbo.SanFranciscoSafety_Local
UNION ALL SELECT 'NycTaxiGreen_Local', COUNT_BIG(*) FROM dbo.NycTaxiGreen_Local
UNION ALL SELECT 'NycTaxiYellow_Local', COUNT_BIG(*) FROM dbo.NycTaxiYellow_Local
UNION ALL SELECT 'NycTaxiForHireVehicle_Local', COUNT_BIG(*) FROM dbo.NycTaxiForHireVehicle_Local
UNION ALL SELECT 'PublicHolidays_Local', COUNT_BIG(*) FROM dbo.PublicHolidays_Local
UNION ALL SELECT 'UsConsumerPriceIndex_Local', COUNT_BIG(*) FROM dbo.UsConsumerPriceIndex_Local
UNION ALL SELECT 'UsLaborForceStatistics_Local', COUNT_BIG(*) FROM dbo.UsLaborForceStatistics_Local
UNION ALL SELECT 'UsLocalAreaUnemployment_Local', COUNT_BIG(*) FROM dbo.UsLocalAreaUnemployment_Local
UNION ALL SELECT 'UsNationalEmploymentEarnings_Local', COUNT_BIG(*) FROM dbo.UsNationalEmploymentEarnings_Local
UNION ALL SELECT 'UsProducerPriceIndexCommodities_Local', COUNT_BIG(*) FROM dbo.UsProducerPriceIndexCommodities_Local
UNION ALL SELECT 'UsProducerPriceIndexIndustry_Local', COUNT_BIG(*) FROM dbo.UsProducerPriceIndexIndustry_Local
UNION ALL SELECT 'UsStateEmploymentEarnings_Local', COUNT_BIG(*) FROM dbo.UsStateEmploymentEarnings_Local
UNION ALL SELECT 'UsPopulationByCounty_Local', COUNT_BIG(*) FROM dbo.UsPopulationByCounty_Local
UNION ALL SELECT 'UsPopulationByZip_Local', COUNT_BIG(*) FROM dbo.UsPopulationByZip_Local
ORDER BY table_name;
GO
