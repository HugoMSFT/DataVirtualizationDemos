SET NOCOUNT ON;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.external_data_sources
    WHERE name = N'TPCHParquetBlob'
)
    THROW 50411, 'External data source TPCHParquetBlob is missing.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.external_file_formats
    WHERE name = N'TPCHParquetFormat'
)
    THROW 50412, 'External file format TPCHParquetFormat is missing.', 1;

IF SCHEMA_ID(N'$(TARGET_SCHEMA)') IS NOT NULL
    THROW 50413, 'Target external-table schema already exists.', 1;
GO

CREATE SCHEMA [$(TARGET_SCHEMA)];
GO

CREATE EXTERNAL TABLE [$(TARGET_SCHEMA)].[region]
(
    [r_regionkey] int NOT NULL,
    [r_name] char(25) NULL,
    [r_comment] varchar(152) NULL
)
WITH
(
    LOCATION = N'tpch_parquet/$(SOURCE_PREFIX)/dbo.region/*.parquet',
    DATA_SOURCE = [TPCHParquetBlob],
    FILE_FORMAT = [TPCHParquetFormat]
);
GO

CREATE EXTERNAL TABLE [$(TARGET_SCHEMA)].[nation]
(
    [n_nationkey] int NOT NULL,
    [n_name] char(25) NULL,
    [n_regionkey] int NULL,
    [n_comment] varchar(152) NULL
)
WITH
(
    LOCATION = N'tpch_parquet/$(SOURCE_PREFIX)/dbo.nation/*.parquet',
    DATA_SOURCE = [TPCHParquetBlob],
    FILE_FORMAT = [TPCHParquetFormat]
);
GO

CREATE EXTERNAL TABLE [$(TARGET_SCHEMA)].[supplier]
(
    [s_suppkey] int NOT NULL,
    [s_nationkey] int NULL,
    [s_comment] varchar(102) NULL,
    [s_name] char(25) NULL,
    [s_address] varchar(40) NULL,
    [s_phone] char(15) NULL,
    [s_acctbal] decimal(12,2) NULL
)
WITH
(
    LOCATION = N'tpch_parquet/$(SOURCE_PREFIX)/dbo.supplier/*.parquet',
    DATA_SOURCE = [TPCHParquetBlob],
    FILE_FORMAT = [TPCHParquetFormat]
);
GO

CREATE EXTERNAL TABLE [$(TARGET_SCHEMA)].[customer]
(
    [c_custkey] bigint NOT NULL,
    [c_mktsegment] char(10) NULL,
    [c_nationkey] int NULL,
    [c_name] varchar(25) NULL,
    [c_address] varchar(40) NULL,
    [c_phone] char(15) NULL,
    [c_acctbal] decimal(12,2) NULL,
    [c_comment] varchar(118) NULL
)
WITH
(
    LOCATION = N'tpch_parquet/$(SOURCE_PREFIX)/dbo.customer/*.parquet',
    DATA_SOURCE = [TPCHParquetBlob],
    FILE_FORMAT = [TPCHParquetFormat]
);
GO

CREATE EXTERNAL TABLE [$(TARGET_SCHEMA)].[part]
(
    [p_partkey] bigint NOT NULL,
    [p_type] varchar(25) NULL,
    [p_size] int NULL,
    [p_brand] char(10) NULL,
    [p_name] varchar(55) NULL,
    [p_container] char(10) NULL,
    [p_mfgr] char(25) NULL,
    [p_retailprice] decimal(12,2) NULL,
    [p_comment] varchar(23) NULL
)
WITH
(
    LOCATION = N'tpch_parquet/$(SOURCE_PREFIX)/dbo.part/*.parquet',
    DATA_SOURCE = [TPCHParquetBlob],
    FILE_FORMAT = [TPCHParquetFormat]
);
GO

CREATE EXTERNAL TABLE [$(TARGET_SCHEMA)].[partsupp]
(
    [ps_partkey] bigint NOT NULL,
    [ps_suppkey] int NOT NULL,
    [ps_supplycost] decimal(12,2) NOT NULL,
    [ps_availqty] int NULL,
    [ps_comment] varchar(199) NULL
)
WITH
(
    LOCATION = N'tpch_parquet/$(SOURCE_PREFIX)/dbo.partsupp/*.parquet',
    DATA_SOURCE = [TPCHParquetBlob],
    FILE_FORMAT = [TPCHParquetFormat]
);
GO

CREATE EXTERNAL TABLE [$(TARGET_SCHEMA)].[orders]
(
    [o_orderdate] date NOT NULL,
    [o_orderkey] bigint NOT NULL,
    [o_custkey] bigint NOT NULL,
    [o_orderpriority] char(15) NULL,
    [o_shippriority] int NULL,
    [o_clerk] char(15) NULL,
    [o_orderstatus] char(1) NULL,
    [o_totalprice] decimal(12,2) NULL,
    [o_comment] varchar(79) NULL
)
WITH
(
    LOCATION = N'tpch_parquet/$(SOURCE_PREFIX)/dbo.orders/*.parquet',
    DATA_SOURCE = [TPCHParquetBlob],
    FILE_FORMAT = [TPCHParquetFormat]
);
GO

CREATE EXTERNAL TABLE [$(TARGET_SCHEMA)].[lineitem]
(
    [l_shipdate] date NOT NULL,
    [l_orderkey] bigint NOT NULL,
    [l_discount] decimal(12,2) NOT NULL,
    [l_extendedprice] decimal(12,2) NOT NULL,
    [l_suppkey] int NOT NULL,
    [l_quantity] bigint NOT NULL,
    [l_returnflag] char(1) NULL,
    [l_partkey] bigint NOT NULL,
    [l_linestatus] char(1) NULL,
    [l_tax] decimal(12,2) NOT NULL,
    [l_commitdate] date NULL,
    [l_receiptdate] date NULL,
    [l_shipmode] char(10) NULL,
    [l_linenumber] bigint NOT NULL,
    [l_shipinstruct] char(25) NULL,
    [l_comment] varchar(44) NULL
)
WITH
(
    LOCATION = N'tpch_parquet/$(SOURCE_PREFIX)/dbo.lineitem/*.parquet',
    DATA_SOURCE = [TPCHParquetBlob],
    FILE_FORMAT = [TPCHParquetFormat]
);
GO
