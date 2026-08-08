-- =============================================================================
-- Demo: Ad-Hoc Query Exploration with OPENROWSET
-- Dataset: Seattle Safety (Fire Department 911 Dispatches)
-- Source: https://learn.microsoft.com/en-us/azure/open-datasets/dataset-seattle-safety
-- Platform: Azure SQL Database (Data Virtualization enabled by default)
-- =============================================================================
-- This demo starts from an empty Azure SQL Database and shows how to use
-- OPENROWSET to query a public Parquet dataset directly — no ingestion needed.
-- =============================================================================

-- =============================================================================
-- Step 1: First look — Query the dataset directly from Azure Blob Storage
-- =============================================================================

-- The Seattle Safety dataset is stored as Parquet in Azure Open Datasets.
-- Storage account: azureopendatastorage
-- Container:       citydatacontainer
-- Path:            Safety/Release/city=Seattle/
-- No credentials needed — this is a publicly accessible dataset.

SELECT COUNT(*) AS total_rows
FROM OPENROWSET(
    BULK 'abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=Seattle/*.parquet',
    FORMAT = 'PARQUET'
) AS [SeattleSafety];
GO

SELECT TOP 100 *
FROM OPENROWSET(
    BULK 'abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=Seattle/*.parquet',
    FORMAT = 'PARQUET'
) AS [SeattleSafety];
GO

-- =============================================================================
-- Step 2: Discover the schema — what columns and types are in this file?
-- =============================================================================

-- Use sp_describe_first_result_set to inspect the metadata of the query
-- without needing to know the schema in advance. Great for exploration!

EXEC sp_describe_first_result_set N'
SELECT *
FROM OPENROWSET(
    BULK ''abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=Seattle/*.parquet'',
    FORMAT = ''PARQUET''
) AS [SeattleSafety]';
GO

-- =============================================================================
-- Step 3: Analytical exploration — quick insights
-- =============================================================================

-- Monthly trend of incidents
SELECT 
    YEAR(dateTime)  AS [Year],
    MONTH(dateTime) AS [Month],
    COUNT(*)        AS incident_count
FROM OPENROWSET(
    BULK 'abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=Seattle/*.parquet',
    FORMAT = 'PARQUET'
) AS [SeattleSafety]
GROUP BY YEAR(dateTime), MONTH(dateTime)
ORDER BY [Year] DESC, [Month] DESC;
GO

-- =============================================================================
-- Step 4: Inspect file metadata with filepath() and filename()
-- =============================================================================
-- filepath() returns the full relative path of the file.
-- filename() returns the name of the Parquet file each row came from.
-- Useful to understand how the data is physically organized.

SELECT 
    [SeattleSafety].filename() AS [file_name],
    COUNT(*)                  AS [row_count]
FROM OPENROWSET(
    BULK 'abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=Seattle/*.parquet',
    FORMAT = 'PARQUET'
) AS [SeattleSafety]
GROUP BY [SeattleSafety].filename()
ORDER BY [file_name];
GO

-- =============================================================================
-- Up next
-- =============================================================================
-- Every query above paid the cost of reading Parquet from remote storage.
-- In 02-IngestData.sql we'll land the full dataset into a local table so
-- we get indexes, statistics, and buffer-pool caching — then compare.
