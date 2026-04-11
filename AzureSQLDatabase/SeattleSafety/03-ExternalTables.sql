-- =============================================================================
-- Demo: External Data Source & External Tables
-- Dataset: Seattle Safety (Fire Department 911 Dispatches)
-- Source: https://learn.microsoft.com/en-us/azure/open-datasets/dataset-seattle-safety
-- Platform: Azure SQL Database (with Data Virtualization enabled)
-- =============================================================================
-- After ad-hoc exploration with OPENROWSET, this script creates persistent
-- external objects so the dataset can be queried like a regular table —
-- no OPENROWSET syntax needed by end users.
-- =============================================================================

-- =============================================================================
-- Step 1: Create an External Data Source
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
-- Step 2: Create an External File Format
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
-- Step 3: Create a schema for external objects (keeps things tidy)
-- =============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'ext')
    EXEC('CREATE SCHEMA ext');
GO

-- =============================================================================
-- Step 4: Create the External Table
-- =============================================================================

-- The external table looks and feels like a regular table.
-- Users can query it with plain SELECT — no OPENROWSET, no URLs.

IF OBJECT_ID('ext.SeattleSafety') IS NOT NULL
    DROP EXTERNAL TABLE ext.SeattleSafety;
GO

CREATE EXTERNAL TABLE ext.SeattleSafety
(
    [address]      VARCHAR(500),
    [category]     VARCHAR(100),
    [dataSubtype]  VARCHAR(50),
    [dataType]     VARCHAR(50),
    [dateTime]     DATETIME2,
    [latitude]     FLOAT,
    [longitude]    FLOAT
)
WITH (
    DATA_SOURCE    = SeattleSafetyDS,
    LOCATION       = '/',
    FILE_FORMAT    = ParquetFileFormat
);
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
FROM ext.SeattleSafety
ORDER BY dateTime DESC;
GO

-- =============================================================================
-- Step 6: Hybrid query — join external data with a local lookup table
-- =============================================================================

-- Create a small local reference table
IF OBJECT_ID('dbo.CategoryPriority') IS NOT NULL
    DROP TABLE dbo.CategoryPriority;
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
FROM ext.SeattleSafety AS s
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
WHERE c.object_id = OBJECT_ID('ext.SeattleSafety')
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
-- Cleanup (optional)
-- =============================================================================
-- DROP EXTERNAL TABLE ext.SeattleSafety;
-- DROP EXTERNAL FILE FORMAT ParquetFileFormat;
-- DROP EXTERNAL DATA SOURCE SeattleSafetyDS;
-- DROP TABLE IF EXISTS dbo.CategoryPriority;
-- GO
