SET NOCOUNT ON;

IF EXISTS
(
    SELECT 1
    FROM sys.external_data_sources
    WHERE name = N'TPCHParquetBlob'
)
    THROW 50401, 'External data source TPCHParquetBlob already exists.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.external_file_formats
    WHERE name = N'TPCHParquetFormat'
)
    THROW 50402, 'External file format TPCHParquetFormat already exists.', 1;
GO

CREATE EXTERNAL DATA SOURCE [TPCHParquetBlob]
WITH
(
    LOCATION = N'abs://tpch@tpcpublicstorage.blob.core.windows.net/'
);
GO

CREATE EXTERNAL FILE FORMAT [TPCHParquetFormat]
WITH
(
    FORMAT_TYPE = PARQUET
);
GO
