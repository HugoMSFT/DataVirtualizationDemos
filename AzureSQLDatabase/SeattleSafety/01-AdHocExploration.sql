-- =============================================================================
-- Demo: Ad-Hoc Query Exploration with OPENROWSET
-- Dataset: Seattle Safety (Fire Department 911 Dispatches)
-- Source: https://learn.microsoft.com/en-us/azure/open-datasets/dataset-seattle-safety
-- Platform: Azure SQL Database (with Data Virtualization enabled)
-- =============================================================================
-- This demo starts from an empty Azure SQL Database and shows how to use
-- OPENROWSET to query a public Parquet dataset directly — no ingestion needed.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Step 0: Prerequisites
-- Make sure Data Virtualization is enabled on your Azure SQL Database.
-- This is a server-level setting, you can enable it via the Azure Portal
-- or with T-SQL (requires server admin):
-- 
--   EXEC sp_configure 'data virtualization enabled', 1;
--   RECONFIGURE;
-- -----------------------------------------------------------------------------

-- =============================================================================
-- Step 1: First look — Query the dataset directly from Azure Blob Storage
-- =============================================================================

-- The Seattle Safety dataset is stored as Parquet in Azure Open Datasets.
-- Storage account: azureopendatastorage
-- Container:       citydatacontainer
-- Path:            Safety/Release/city=Seattle/
-- No credentials needed — this is a publicly accessible dataset.

SELECT TOP 10 *
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
-- Step 3: Explore the data — what's in here?
-- =============================================================================

-- Check distinct categories (types of 911 calls)
SELECT category, COUNT(*) AS incident_count
FROM OPENROWSET(
    BULK 'abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=Seattle/*.parquet',
    FORMAT = 'PARQUET'
) AS [SeattleSafety]
GROUP BY category
ORDER BY incident_count DESC;
GO

-- What date range does the dataset cover?
SELECT 
    MIN(dateTime) AS earliest_record,
    MAX(dateTime) AS latest_record,
    COUNT(*)      AS total_records
FROM OPENROWSET(
    BULK 'abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=Seattle/*.parquet',
    FORMAT = 'PARQUET'
) AS [SeattleSafety];
GO

-- =============================================================================
-- Step 4: Use a WITH clause to define/override the schema explicitly
-- =============================================================================

-- Parquet files are self-describing — the schema is embedded in the file,
-- so you don't need a WITH clause. But you CAN use WITH when you want to:
--   - Rename columns
--   - Cast to specific types
--   - Select only a subset of columns (pushdown optimization)

SELECT TOP 20 *
FROM OPENROWSET(
    BULK 'abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=Seattle/*.parquet',
    FORMAT = 'PARQUET'
) WITH (
    [address]      VARCHAR(500),
    [category]     VARCHAR(100),
    [dataSubtype]  VARCHAR(50),
    [dataType]     VARCHAR(50),
    [dateTime]     DATETIME2,
    [latitude]     FLOAT,
    [longitude]    FLOAT
) AS [SeattleSafety];
GO

-- =============================================================================
-- Step 5: Analytical exploration — quick insights
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

-- Top 10 addresses with the most incidents
SELECT TOP 10
    address,
    COUNT(*) AS incident_count
FROM OPENROWSET(
    BULK 'abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=Seattle/*.parquet',
    FORMAT = 'PARQUET'
) AS [SeattleSafety]
WHERE address IS NOT NULL
GROUP BY address
ORDER BY incident_count DESC;
GO

-- =============================================================================
-- Step 6: Inspect file metadata with filepath() and filename()
-- =============================================================================

-- filename() returns the name of the Parquet file each row came from.
-- Useful to understand how the data is physically organized.

SELECT TOP 10
    [SeattleSafety].filename() AS [source_file],
    category,
    dateTime
FROM OPENROWSET(
    BULK 'abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=Seattle/*.parquet',
    FORMAT = 'PARQUET'
) AS [SeattleSafety];
GO

-- How many rows per file? See the distribution across Parquet files.
SELECT 
    [SeattleSafety].filename() AS [source_file],
    COUNT(*)                   AS row_count
FROM OPENROWSET(
    BULK 'abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=Seattle/*.parquet',
    FORMAT = 'PARQUET'
) AS [SeattleSafety]
GROUP BY [SeattleSafety].filename()
ORDER BY row_count DESC;
GO

-- filepath() returns the full relative path of the file.
-- When using wildcards, filepath(N) returns the Nth wildcard match.
-- This is powerful for partition elimination — filter on path segments
-- without scanning the entire dataset.

SELECT TOP 10
    [SeattleSafety].filepath()  AS [full_path],
    [SeattleSafety].filepath(1) AS [wildcard_match],
    category,
    dateTime
FROM OPENROWSET(
    BULK 'abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=Seattle/*.parquet',
    FORMAT = 'PARQUET'
) AS [SeattleSafety];
GO

-- Use filepath() in a WHERE clause for partition elimination.
-- Move the wildcard up to city=* so filepath(1) captures the city name.
-- Filtering on filepath(1) = 'Seattle' means only files under that
-- partition folder are scanned — the engine skips all other cities.

SELECT TOP 10
    [SeattleSafety].filepath(1) AS [path_segment],
    [SeattleSafety].filename()  AS [file_name],
    category,
    dateTime
FROM OPENROWSET(
    BULK 'abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=*/*.parquet',
    FORMAT = 'PARQUET'
) AS [SeattleSafety]
WHERE [SeattleSafety].filepath(1) = 'Seattle';
GO
