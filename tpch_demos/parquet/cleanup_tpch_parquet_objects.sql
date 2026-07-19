USE [$(DATABASE_NAME)];
GO

SET NOCOUNT ON;

IF EXISTS (SELECT 1 FROM sys.external_tables
           WHERE name = N'__tpch_parquet_customer')
    DROP EXTERNAL TABLE dbo.__tpch_parquet_customer;
IF EXISTS (SELECT 1 FROM sys.external_tables
           WHERE name = N'__tpch_parquet_lineitem')
    DROP EXTERNAL TABLE dbo.__tpch_parquet_lineitem;
IF EXISTS (SELECT 1 FROM sys.external_tables
           WHERE name = N'__tpch_parquet_nation')
    DROP EXTERNAL TABLE dbo.__tpch_parquet_nation;
IF EXISTS (SELECT 1 FROM sys.external_tables
           WHERE name = N'__tpch_parquet_orders')
    DROP EXTERNAL TABLE dbo.__tpch_parquet_orders;
IF EXISTS (SELECT 1 FROM sys.external_tables
           WHERE name = N'__tpch_parquet_part')
    DROP EXTERNAL TABLE dbo.__tpch_parquet_part;
IF EXISTS (SELECT 1 FROM sys.external_tables
           WHERE name = N'__tpch_parquet_partsupp')
    DROP EXTERNAL TABLE dbo.__tpch_parquet_partsupp;
IF EXISTS (SELECT 1 FROM sys.external_tables
           WHERE name = N'__tpch_parquet_region')
    DROP EXTERNAL TABLE dbo.__tpch_parquet_region;
IF EXISTS (SELECT 1 FROM sys.external_tables
           WHERE name = N'__tpch_parquet_supplier')
    DROP EXTERNAL TABLE dbo.__tpch_parquet_supplier;

IF EXISTS (SELECT 1 FROM sys.external_file_formats
           WHERE name = N'__tpch_parquet_format')
    DROP EXTERNAL FILE FORMAT [__tpch_parquet_format];

IF EXISTS (SELECT 1 FROM sys.external_data_sources
           WHERE name = N'__tpch_blob_source')
    DROP EXTERNAL DATA SOURCE [__tpch_blob_source];

IF EXISTS (SELECT 1 FROM sys.database_scoped_credentials
           WHERE name = N'__tpch_blob_credential')
    DROP DATABASE SCOPED CREDENTIAL [__tpch_blob_credential];

SELECT
    DB_NAME() AS database_name,
    (SELECT COUNT(*) FROM sys.external_tables) AS external_tables,
    (SELECT COUNT(*) FROM sys.external_file_formats) AS external_file_formats,
    (SELECT COUNT(*) FROM sys.external_data_sources) AS external_data_sources,
    (SELECT COUNT(*) FROM sys.database_scoped_credentials) AS scoped_credentials;
GO
