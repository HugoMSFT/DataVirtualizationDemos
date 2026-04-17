-- =============================================================================
-- Demo: External Data Source & External Tables
-- Dataset: Seattle Safety (Fire Department 911 Dispatches)
-- Source: https://learn.microsoft.com/en-us/azure/open-datasets/dataset-seattle-safety
-- Platform: Azure SQL Database (Data Virtualization enabled by default)
-- =============================================================================
-- After ad-hoc exploration with OPENROWSET, this script creates persistent
-- external objects so the dataset can be queried like a regular table —
-- no OPENROWSET syntax needed by end users.
-- =============================================================================

-- =============================================================================
-- Step 1: OPENROWSET with an explicit WITH schema clause
-- =============================================================================
-- In 01 we let SQL Server infer the schema from Parquet metadata. That's
-- convenient for exploration but has two drawbacks:
--   • The engine reads Parquet footers on every query to re-discover the shape.
--   • Inferred types can be wider than needed (e.g. NVARCHAR(4000)).
-- The WITH clause lets you pin column names and types explicitly, which is
-- faster and also lets you project only the columns you need.

SELECT TOP 100 *
FROM OPENROWSET(
    BULK 'abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=Seattle/*.parquet',
    FORMAT = 'PARQUET'
) WITH (
    [dateTime] DATETIME2,
    [category] VARCHAR(100),
    [address]  VARCHAR(500),
    [latitude] FLOAT,
    [longitude] FLOAT
) AS [SeattleSafety]
ORDER BY [dateTime] DESC;
GO

-- =============================================================================
-- Step 2: Create an External Data Source
-- =============================================================================

-- An External Data Source encapsulates the connection info (location, credentials).
-- Once created, queries reference the data source name instead of the full URL.

IF NOT EXISTS (SELECT 1 FROM sys.external_data_sources WHERE name = 'SeattleSafetyDS')
BEGIN
    CREATE EXTERNAL DATA SOURCE SeattleSafetyDS
    WITH (
        LOCATION = 'abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=Seattle'
    );
END
GO

-- =============================================================================
-- Step 3: Create an External File Format
-- =============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.external_file_formats WHERE name = 'ParquetFileFormat')
BEGIN
    CREATE EXTERNAL FILE FORMAT ParquetFileFormat
    WITH (
        FORMAT_TYPE = PARQUET
    );
END
GO

-- =============================================================================
-- Step 4: Create the External Table
-- =============================================================================

-- The external table looks and feels like a regular table.
-- Users can query it with plain SELECT — no OPENROWSET, no URLs.

IF OBJECT_ID('dbo.SeattleSafety_External') IS NOT NULL
    DROP EXTERNAL TABLE dbo.SeattleSafety_External;
GO

CREATE EXTERNAL TABLE dbo.SeattleSafety_External
(
    [dataType]           VARCHAR(50),
    [dataSubtype]        VARCHAR(50),
    [dateTime]           DATETIME2,
    [category]           VARCHAR(100),
    [subcategory]        VARCHAR(200),
    [status]             VARCHAR(100),
    [address]            VARCHAR(500),
    [latitude]           FLOAT,
    [longitude]          FLOAT,
    [source]             VARCHAR(200),
    [extendedProperties] VARCHAR(4000)
)
WITH (
    DATA_SOURCE    = SeattleSafetyDS,
    LOCATION       = '/',
    FILE_FORMAT    = ParquetFileFormat
);
GO

-- Create statistics on commonly queried columns to improve query plans.
-- External tables only support FULLSCAN (no SAMPLE) — the engine scans the
-- full remote dataset once to build the histogram. Worth it for stable
-- cardinality estimates, memory grants, and join strategies.

CREATE STATISTICS ST_SeattleSafety_DateTime ON dbo.SeattleSafety_External ([dateTime]) WITH FULLSCAN;
CREATE STATISTICS ST_SeattleSafety_Category ON dbo.SeattleSafety_External ([category]) WITH FULLSCAN;
CREATE STATISTICS ST_SeattleSafety_Address  ON dbo.SeattleSafety_External ([address])  WITH FULLSCAN;
GO

-- =============================================================================
-- Step 5: Query the external table — just like a regular table
-- =============================================================================

SELECT TOP 50
    dateTime,
    category,
    address,
    latitude,
    longitude
FROM dbo.SeattleSafety_External
ORDER BY dateTime DESC;
GO

-- =============================================================================
-- Step 6: Hybrid query — join external data with a local lookup table
-- =============================================================================

-- Create a small local reference table
DROP TABLE IF EXISTS dbo.CategoryPriority;
GO

CREATE TABLE dbo.CategoryPriority
(
    category   VARCHAR(100) PRIMARY KEY,
    priority   INT,
    severity   VARCHAR(20)
);
GO

INSERT INTO dbo.CategoryPriority (category, priority, severity) VALUES
('Medic Response',        1, 'Critical'),
('Aid Response',          2, 'High'),
('Auto Fire Alarm',       3, 'Medium'),
('MVI - Loss Stuck',      3, 'Medium'),
('Rubbish Fire',          4, 'Low'),
('Low Acuity Response',   5, 'Low');
GO

-- Join virtualized Parquet data with local relational data — no ETL needed.
-- This is the "hybrid query" pattern: lake + relational in a single query.
SELECT TOP 50
    s.dateTime,
    s.category,
    s.address,
    p.priority,
    p.severity,
    s.latitude,
    s.longitude
FROM dbo.SeattleSafety_External AS s
LEFT JOIN dbo.CategoryPriority AS p
    ON s.category = p.category
ORDER BY s.dateTime DESC;
GO

-- =============================================================================
-- Step 7: Schema introspection on external objects
-- =============================================================================

-- See the columns defined in the external table
SELECT
    c.column_id,
    c.name,
    c.max_length,
    t.name AS data_type
FROM sys.external_table_columns AS c
JOIN sys.types AS t ON c.user_type_id = t.user_type_id
WHERE c.object_id = OBJECT_ID('dbo.SeattleSafety_External')
ORDER BY c.column_id;
GO

-- List all external data sources in the database
SELECT name, location
FROM sys.external_data_sources;
GO

-- List all external tables in the database
SELECT s.name AS [schema], t.name AS [table]
FROM sys.external_tables AS t
JOIN sys.schemas AS s ON t.schema_id = s.schema_id;
GO

-- =============================================================================
-- Cleanup (optional) — 04-AdvancedFeatures.sql depends on the objects above.
-- Only uncomment the block below if you are DONE with script 04.
-- ParquetFileFormat and SeattleSafetyDS are kept intentionally (04 uses them).
-- =============================================================================
-- IF OBJECT_ID('dbo.SeattleSafety_External') IS NOT NULL
--     DROP EXTERNAL TABLE dbo.SeattleSafety_External;
-- DROP TABLE IF EXISTS dbo.CategoryPriority;
-- IF EXISTS (SELECT 1 FROM sys.external_file_formats WHERE name = 'ParquetFileFormat')
--     DROP EXTERNAL FILE FORMAT ParquetFileFormat;
-- IF EXISTS (SELECT 1 FROM sys.external_data_sources WHERE name = 'SeattleSafetyDS')
--     DROP EXTERNAL DATA SOURCE SeattleSafetyDS;
-- GO
