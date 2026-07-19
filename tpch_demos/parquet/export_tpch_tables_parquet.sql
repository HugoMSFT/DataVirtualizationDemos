USE [$(DATABASE_NAME)];
GO

SET NOCOUNT ON;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.external_data_sources
    WHERE name = N'__tpch_blob_source'
)
    THROW 50221, 'Temporary CETAS data source is missing.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.external_file_formats
    WHERE name = N'__tpch_parquet_format'
)
    THROW 50222, 'Temporary Parquet file format is missing.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.external_tables
    WHERE name LIKE N'__tpch_parquet_%'
)
    THROW 50223, 'One or more temporary Parquet external tables already exist.', 1;
GO

RAISERROR(N'Exporting region', 10, 1) WITH NOWAIT;
CREATE EXTERNAL TABLE dbo.__tpch_parquet_region
WITH
(
    LOCATION = N'$(BLOB_PREFIX)/dbo.region/',
    DATA_SOURCE = [__tpch_blob_source],
    FILE_FORMAT = [__tpch_parquet_format]
)
AS
SELECT *
FROM dbo.region;
GO

SELECT N'region' AS table_name, COUNT_BIG(*) AS exported_rows
FROM dbo.__tpch_parquet_region;
GO

RAISERROR(N'Exporting nation', 10, 1) WITH NOWAIT;
CREATE EXTERNAL TABLE dbo.__tpch_parquet_nation
WITH
(
    LOCATION = N'$(BLOB_PREFIX)/dbo.nation/',
    DATA_SOURCE = [__tpch_blob_source],
    FILE_FORMAT = [__tpch_parquet_format]
)
AS
SELECT *
FROM dbo.nation;
GO

SELECT N'nation' AS table_name, COUNT_BIG(*) AS exported_rows
FROM dbo.__tpch_parquet_nation;
GO

RAISERROR(N'Exporting supplier', 10, 1) WITH NOWAIT;
CREATE EXTERNAL TABLE dbo.__tpch_parquet_supplier
WITH
(
    LOCATION = N'$(BLOB_PREFIX)/dbo.supplier/',
    DATA_SOURCE = [__tpch_blob_source],
    FILE_FORMAT = [__tpch_parquet_format]
)
AS
SELECT *
FROM dbo.supplier;
GO

SELECT N'supplier' AS table_name, COUNT_BIG(*) AS exported_rows
FROM dbo.__tpch_parquet_supplier;
GO

RAISERROR(N'Exporting customer', 10, 1) WITH NOWAIT;
CREATE EXTERNAL TABLE dbo.__tpch_parquet_customer
WITH
(
    LOCATION = N'$(BLOB_PREFIX)/dbo.customer/',
    DATA_SOURCE = [__tpch_blob_source],
    FILE_FORMAT = [__tpch_parquet_format]
)
AS
SELECT *
FROM dbo.customer;
GO

SELECT N'customer' AS table_name, COUNT_BIG(*) AS exported_rows
FROM dbo.__tpch_parquet_customer;
GO

RAISERROR(N'Exporting part', 10, 1) WITH NOWAIT;
CREATE EXTERNAL TABLE dbo.__tpch_parquet_part
WITH
(
    LOCATION = N'$(BLOB_PREFIX)/dbo.part/',
    DATA_SOURCE = [__tpch_blob_source],
    FILE_FORMAT = [__tpch_parquet_format]
)
AS
SELECT *
FROM dbo.part;
GO

SELECT N'part' AS table_name, COUNT_BIG(*) AS exported_rows
FROM dbo.__tpch_parquet_part;
GO

RAISERROR(N'Exporting partsupp', 10, 1) WITH NOWAIT;
CREATE EXTERNAL TABLE dbo.__tpch_parquet_partsupp
WITH
(
    LOCATION = N'$(BLOB_PREFIX)/dbo.partsupp/',
    DATA_SOURCE = [__tpch_blob_source],
    FILE_FORMAT = [__tpch_parquet_format]
)
AS
SELECT *
FROM dbo.partsupp;
GO

SELECT N'partsupp' AS table_name, COUNT_BIG(*) AS exported_rows
FROM dbo.__tpch_parquet_partsupp;
GO

RAISERROR(N'Exporting orders', 10, 1) WITH NOWAIT;
CREATE EXTERNAL TABLE dbo.__tpch_parquet_orders
WITH
(
    LOCATION = N'$(BLOB_PREFIX)/dbo.orders/',
    DATA_SOURCE = [__tpch_blob_source],
    FILE_FORMAT = [__tpch_parquet_format]
)
AS
SELECT *
FROM dbo.orders;
GO

SELECT N'orders' AS table_name, COUNT_BIG(*) AS exported_rows
FROM dbo.__tpch_parquet_orders;
GO

RAISERROR(N'Exporting lineitem', 10, 1) WITH NOWAIT;
CREATE EXTERNAL TABLE dbo.__tpch_parquet_lineitem
WITH
(
    LOCATION = N'$(BLOB_PREFIX)/dbo.lineitem/',
    DATA_SOURCE = [__tpch_blob_source],
    FILE_FORMAT = [__tpch_parquet_format]
)
AS
SELECT *
FROM dbo.lineitem;
GO

SELECT N'lineitem' AS table_name, COUNT_BIG(*) AS exported_rows
FROM dbo.__tpch_parquet_lineitem;
GO
