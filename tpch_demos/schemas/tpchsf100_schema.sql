-- Generated from [tpchsf100] on 2026-07-19T22:35:08.0842556Z
-- Schema only; table data is stored in the adjacent Parquet files.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
GO

IF SCHEMA_ID(N'rs') IS NULL EXEC(N'CREATE SCHEMA [rs]');
GO

IF SCHEMA_ID(N'ext') IS NULL EXEC(N'CREATE SCHEMA [ext]');
GO

CREATE TABLE [dbo].[region]
(
    [r_regionkey] [int] NOT NULL,
    [r_name] [char](25) NULL,
    [r_comment] [varchar](152) NULL
);
GO

CREATE TABLE [rs].[region]
(
    [r_regionkey] [int] NOT NULL,
    [r_name] [char](25) NULL,
    [r_comment] [varchar](152) NULL
);
GO

CREATE TABLE [rs].[nation]
(
    [n_nationkey] [int] NOT NULL,
    [n_name] [char](25) NULL,
    [n_regionkey] [int] NULL,
    [n_comment] [varchar](152) NULL
);
GO

CREATE TABLE [dbo].[nation]
(
    [n_nationkey] [int] NOT NULL,
    [n_name] [char](25) NULL,
    [n_regionkey] [int] NULL,
    [n_comment] [varchar](152) NULL
);
GO

CREATE TABLE [dbo].[supplier]
(
    [s_suppkey] [int] NOT NULL,
    [s_nationkey] [int] NULL,
    [s_comment] [varchar](102) NULL,
    [s_name] [char](25) NULL,
    [s_address] [varchar](40) NULL,
    [s_phone] [char](15) NULL,
    [s_acctbal] [decimal](12,2) NULL
);
GO

CREATE TABLE [rs].[supplier]
(
    [s_suppkey] [int] NOT NULL,
    [s_nationkey] [int] NULL,
    [s_comment] [varchar](102) NULL,
    [s_name] [char](25) NULL,
    [s_address] [varchar](40) NULL,
    [s_phone] [char](15) NULL,
    [s_acctbal] [decimal](12,2) NULL
);
GO

CREATE TABLE [rs].[customer]
(
    [c_custkey] [bigint] NOT NULL,
    [c_mktsegment] [char](10) NULL,
    [c_nationkey] [int] NULL,
    [c_name] [varchar](25) NULL,
    [c_address] [varchar](40) NULL,
    [c_phone] [char](15) NULL,
    [c_acctbal] [decimal](12,2) NULL,
    [c_comment] [varchar](118) NULL
);
GO

CREATE TABLE [dbo].[customer]
(
    [c_custkey] [bigint] NOT NULL,
    [c_mktsegment] [char](10) NULL,
    [c_nationkey] [int] NULL,
    [c_name] [varchar](25) NULL,
    [c_address] [varchar](40) NULL,
    [c_phone] [char](15) NULL,
    [c_acctbal] [decimal](12,2) NULL,
    [c_comment] [varchar](118) NULL
);
GO

CREATE TABLE [dbo].[part]
(
    [p_partkey] [bigint] NOT NULL,
    [p_type] [varchar](25) NULL,
    [p_size] [int] NULL,
    [p_brand] [char](10) NULL,
    [p_name] [varchar](55) NULL,
    [p_container] [char](10) NULL,
    [p_mfgr] [char](25) NULL,
    [p_retailprice] [decimal](12,2) NULL,
    [p_comment] [varchar](23) NULL
);
GO

CREATE TABLE [rs].[part]
(
    [p_partkey] [bigint] NOT NULL,
    [p_type] [varchar](25) NULL,
    [p_size] [int] NULL,
    [p_brand] [char](10) NULL,
    [p_name] [varchar](55) NULL,
    [p_container] [char](10) NULL,
    [p_mfgr] [char](25) NULL,
    [p_retailprice] [decimal](12,2) NULL,
    [p_comment] [varchar](23) NULL
);
GO

CREATE TABLE [rs].[partsupp]
(
    [ps_partkey] [bigint] NOT NULL,
    [ps_suppkey] [int] NOT NULL,
    [ps_supplycost] [decimal](12,2) NOT NULL,
    [ps_availqty] [int] NULL,
    [ps_comment] [varchar](199) NULL
);
GO

CREATE TABLE [dbo].[partsupp]
(
    [ps_partkey] [bigint] NOT NULL,
    [ps_suppkey] [int] NOT NULL,
    [ps_supplycost] [decimal](12,2) NOT NULL,
    [ps_availqty] [int] NULL,
    [ps_comment] [varchar](199) NULL
);
GO

CREATE TABLE [dbo].[orders]
(
    [o_orderdate] [date] NOT NULL,
    [o_orderkey] [bigint] NOT NULL,
    [o_custkey] [bigint] NOT NULL,
    [o_orderpriority] [char](15) NULL,
    [o_shippriority] [int] NULL,
    [o_clerk] [char](15) NULL,
    [o_orderstatus] [char](1) NULL,
    [o_totalprice] [decimal](12,2) NULL,
    [o_comment] [varchar](79) NULL
);
GO

CREATE TABLE [rs].[orders]
(
    [o_orderdate] [date] NOT NULL,
    [o_orderkey] [bigint] NOT NULL,
    [o_custkey] [bigint] NOT NULL,
    [o_orderpriority] [char](15) NULL,
    [o_shippriority] [int] NULL,
    [o_clerk] [char](15) NULL,
    [o_orderstatus] [char](1) NULL,
    [o_totalprice] [decimal](12,2) NULL,
    [o_comment] [varchar](79) NULL
);
GO

CREATE TABLE [rs].[lineitem]
(
    [l_shipdate] [date] NOT NULL,
    [l_orderkey] [bigint] NOT NULL,
    [l_discount] [decimal](12,2) NOT NULL,
    [l_extendedprice] [decimal](12,2) NOT NULL,
    [l_suppkey] [int] NOT NULL,
    [l_quantity] [bigint] NOT NULL,
    [l_returnflag] [char](1) NULL,
    [l_partkey] [bigint] NOT NULL,
    [l_linestatus] [char](1) NULL,
    [l_tax] [decimal](12,2) NOT NULL,
    [l_commitdate] [date] NULL,
    [l_receiptdate] [date] NULL,
    [l_shipmode] [char](10) NULL,
    [l_linenumber] [bigint] NOT NULL,
    [l_shipinstruct] [char](25) NULL,
    [l_comment] [varchar](44) NULL
);
GO

CREATE TABLE [dbo].[lineitem]
(
    [l_shipdate] [date] NOT NULL,
    [l_orderkey] [bigint] NOT NULL,
    [l_discount] [decimal](12,2) NOT NULL,
    [l_extendedprice] [decimal](12,2) NOT NULL,
    [l_suppkey] [int] NOT NULL,
    [l_quantity] [bigint] NOT NULL,
    [l_returnflag] [char](1) NULL,
    [l_partkey] [bigint] NOT NULL,
    [l_linestatus] [char](1) NULL,
    [l_tax] [decimal](12,2) NOT NULL,
    [l_commitdate] [date] NULL,
    [l_receiptdate] [date] NULL,
    [l_shipmode] [char](10) NULL,
    [l_linenumber] [bigint] NOT NULL,
    [l_shipinstruct] [char](25) NULL,
    [l_comment] [varchar](44) NULL
);
GO

ALTER TABLE [rs].[partsupp] ADD CONSTRAINT [partsupp_pk] PRIMARY KEY CLUSTERED ([ps_partkey] ASC, [ps_suppkey] ASC);
GO

ALTER TABLE [dbo].[partsupp] ADD CONSTRAINT [partsupp_pk] PRIMARY KEY NONCLUSTERED ([ps_partkey] ASC, [ps_suppkey] ASC);
GO

CREATE CLUSTERED COLUMNSTORE INDEX [cust_cs] ON [dbo].[customer];
GO

CREATE UNIQUE NONCLUSTERED INDEX [customer_pk] ON [dbo].[customer] ([c_custkey] ASC);
GO

CREATE UNIQUE NONCLUSTERED INDEX [customer_pk] ON [rs].[customer] ([c_custkey] ASC);
GO

CREATE CLUSTERED COLUMNSTORE INDEX [lineit_cs] ON [dbo].[lineitem];
GO

CREATE NONCLUSTERED INDEX [lineitem_pk] ON [dbo].[lineitem] ([l_orderkey] ASC);
GO

CREATE NONCLUSTERED INDEX [lineitem_pk] ON [rs].[lineitem] ([l_orderkey] ASC);
GO

CREATE CLUSTERED COLUMNSTORE INDEX [nation_cs] ON [dbo].[nation];
GO

CREATE UNIQUE NONCLUSTERED INDEX [nation_pk] ON [dbo].[nation] ([n_nationkey] ASC);
GO

CREATE UNIQUE NONCLUSTERED INDEX [nation_pk] ON [rs].[nation] ([n_nationkey] ASC);
GO

CREATE CLUSTERED COLUMNSTORE INDEX [ord_cs] ON [dbo].[orders];
GO

CREATE UNIQUE NONCLUSTERED INDEX [orders_pk] ON [dbo].[orders] ([o_orderkey] ASC);
GO

CREATE UNIQUE NONCLUSTERED INDEX [orders_pk] ON [rs].[orders] ([o_orderkey] ASC);
GO

CREATE CLUSTERED COLUMNSTORE INDEX [part_cs] ON [dbo].[part];
GO

CREATE UNIQUE NONCLUSTERED INDEX [part_pk] ON [dbo].[part] ([p_partkey] ASC);
GO

CREATE UNIQUE NONCLUSTERED INDEX [part_pk] ON [rs].[part] ([p_partkey] ASC);
GO

CREATE CLUSTERED COLUMNSTORE INDEX [psupp_cs] ON [dbo].[partsupp];
GO

CREATE CLUSTERED COLUMNSTORE INDEX [region_cs] ON [dbo].[region];
GO

CREATE UNIQUE NONCLUSTERED INDEX [region_pk] ON [dbo].[region] ([r_regionkey] ASC);
GO

CREATE UNIQUE NONCLUSTERED INDEX [region_pk] ON [rs].[region] ([r_regionkey] ASC);
GO

CREATE CLUSTERED COLUMNSTORE INDEX [suppl_cs] ON [dbo].[supplier];
GO

CREATE UNIQUE NONCLUSTERED INDEX [supplier_pk] ON [dbo].[supplier] ([s_suppkey] ASC);
GO

CREATE UNIQUE NONCLUSTERED INDEX [supplier_pk] ON [rs].[supplier] ([s_suppkey] ASC);
GO

ALTER TABLE [dbo].[customer] WITH NOCHECK ADD CONSTRAINT [customer_nation_fk] FOREIGN KEY ([c_nationkey]) REFERENCES [dbo].[nation] ([n_nationkey]);
GO
ALTER TABLE [dbo].[customer] CHECK CONSTRAINT [customer_nation_fk];
GO

ALTER TABLE [rs].[customer] WITH CHECK ADD CONSTRAINT [customer_nation_fk] FOREIGN KEY ([c_nationkey]) REFERENCES [rs].[nation] ([n_nationkey]);
GO
ALTER TABLE [rs].[customer] CHECK CONSTRAINT [customer_nation_fk];
GO

ALTER TABLE [rs].[lineitem] WITH CHECK ADD CONSTRAINT [lineitem_order_fk] FOREIGN KEY ([l_orderkey]) REFERENCES [rs].[orders] ([o_orderkey]);
GO
ALTER TABLE [rs].[lineitem] CHECK CONSTRAINT [lineitem_order_fk];
GO

ALTER TABLE [dbo].[lineitem] WITH NOCHECK ADD CONSTRAINT [lineitem_order_fk] FOREIGN KEY ([l_orderkey]) REFERENCES [dbo].[orders] ([o_orderkey]);
GO
ALTER TABLE [dbo].[lineitem] CHECK CONSTRAINT [lineitem_order_fk];
GO

ALTER TABLE [dbo].[lineitem] WITH NOCHECK ADD CONSTRAINT [lineitem_partkey_fk] FOREIGN KEY ([l_partkey]) REFERENCES [dbo].[part] ([p_partkey]);
GO
ALTER TABLE [dbo].[lineitem] CHECK CONSTRAINT [lineitem_partkey_fk];
GO

ALTER TABLE [rs].[lineitem] WITH CHECK ADD CONSTRAINT [lineitem_partkey_fk] FOREIGN KEY ([l_partkey]) REFERENCES [rs].[part] ([p_partkey]);
GO
ALTER TABLE [rs].[lineitem] CHECK CONSTRAINT [lineitem_partkey_fk];
GO

ALTER TABLE [dbo].[lineitem] WITH NOCHECK ADD CONSTRAINT [lineitem_partsupp_fk] FOREIGN KEY ([l_partkey], [l_suppkey]) REFERENCES [dbo].[partsupp] ([ps_partkey], [ps_suppkey]);
GO
ALTER TABLE [dbo].[lineitem] CHECK CONSTRAINT [lineitem_partsupp_fk];
GO

ALTER TABLE [rs].[lineitem] WITH CHECK ADD CONSTRAINT [lineitem_partsupp_fk] FOREIGN KEY ([l_partkey], [l_suppkey]) REFERENCES [rs].[partsupp] ([ps_partkey], [ps_suppkey]);
GO
ALTER TABLE [rs].[lineitem] CHECK CONSTRAINT [lineitem_partsupp_fk];
GO

ALTER TABLE [rs].[lineitem] WITH CHECK ADD CONSTRAINT [lineitem_suppkey_fk] FOREIGN KEY ([l_suppkey]) REFERENCES [rs].[supplier] ([s_suppkey]);
GO
ALTER TABLE [rs].[lineitem] CHECK CONSTRAINT [lineitem_suppkey_fk];
GO

ALTER TABLE [dbo].[lineitem] WITH NOCHECK ADD CONSTRAINT [lineitem_suppkey_fk] FOREIGN KEY ([l_suppkey]) REFERENCES [dbo].[supplier] ([s_suppkey]);
GO
ALTER TABLE [dbo].[lineitem] CHECK CONSTRAINT [lineitem_suppkey_fk];
GO

ALTER TABLE [dbo].[nation] WITH NOCHECK ADD CONSTRAINT [nation_region_fk] FOREIGN KEY ([n_regionkey]) REFERENCES [dbo].[region] ([r_regionkey]);
GO
ALTER TABLE [dbo].[nation] CHECK CONSTRAINT [nation_region_fk];
GO

ALTER TABLE [rs].[nation] WITH CHECK ADD CONSTRAINT [nation_region_fk] FOREIGN KEY ([n_regionkey]) REFERENCES [rs].[region] ([r_regionkey]);
GO
ALTER TABLE [rs].[nation] CHECK CONSTRAINT [nation_region_fk];
GO

ALTER TABLE [dbo].[orders] WITH NOCHECK ADD CONSTRAINT [order_customer_fk] FOREIGN KEY ([o_custkey]) REFERENCES [dbo].[customer] ([c_custkey]);
GO
ALTER TABLE [dbo].[orders] CHECK CONSTRAINT [order_customer_fk];
GO

ALTER TABLE [rs].[orders] WITH CHECK ADD CONSTRAINT [order_customer_fk] FOREIGN KEY ([o_custkey]) REFERENCES [rs].[customer] ([c_custkey]);
GO
ALTER TABLE [rs].[orders] CHECK CONSTRAINT [order_customer_fk];
GO

ALTER TABLE [rs].[partsupp] WITH CHECK ADD CONSTRAINT [partsupp_part_fk] FOREIGN KEY ([ps_partkey]) REFERENCES [rs].[part] ([p_partkey]);
GO
ALTER TABLE [rs].[partsupp] CHECK CONSTRAINT [partsupp_part_fk];
GO

ALTER TABLE [dbo].[partsupp] WITH NOCHECK ADD CONSTRAINT [partsupp_part_fk] FOREIGN KEY ([ps_partkey]) REFERENCES [dbo].[part] ([p_partkey]);
GO
ALTER TABLE [dbo].[partsupp] CHECK CONSTRAINT [partsupp_part_fk];
GO

ALTER TABLE [dbo].[partsupp] WITH NOCHECK ADD CONSTRAINT [partsupp_supplier_fk] FOREIGN KEY ([ps_suppkey]) REFERENCES [dbo].[supplier] ([s_suppkey]);
GO
ALTER TABLE [dbo].[partsupp] CHECK CONSTRAINT [partsupp_supplier_fk];
GO

ALTER TABLE [rs].[partsupp] WITH CHECK ADD CONSTRAINT [partsupp_supplier_fk] FOREIGN KEY ([ps_suppkey]) REFERENCES [rs].[supplier] ([s_suppkey]);
GO
ALTER TABLE [rs].[partsupp] CHECK CONSTRAINT [partsupp_supplier_fk];
GO

ALTER TABLE [rs].[supplier] WITH CHECK ADD CONSTRAINT [supplier_nation_fk] FOREIGN KEY ([s_nationkey]) REFERENCES [rs].[nation] ([n_nationkey]);
GO
ALTER TABLE [rs].[supplier] CHECK CONSTRAINT [supplier_nation_fk];
GO

ALTER TABLE [dbo].[supplier] WITH NOCHECK ADD CONSTRAINT [supplier_nation_fk] FOREIGN KEY ([s_nationkey]) REFERENCES [dbo].[nation] ([n_nationkey]);
GO
ALTER TABLE [dbo].[supplier] CHECK CONSTRAINT [supplier_nation_fk];
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

CREATE EXTERNAL TABLE [ext].[region]
(
    [r_regionkey] [int] NOT NULL,
    [r_name] [char](25) NULL,
    [r_comment] [varchar](152) NULL
)
WITH
(
    LOCATION = N'tpch_parquet/tpchsf10_rowstore/dbo.region/*.parquet',
    DATA_SOURCE = [TPCHParquetBlob],
    FILE_FORMAT = [TPCHParquetFormat]
);
GO

CREATE EXTERNAL TABLE [ext].[nation]
(
    [n_nationkey] [int] NOT NULL,
    [n_name] [char](25) NULL,
    [n_regionkey] [int] NULL,
    [n_comment] [varchar](152) NULL
)
WITH
(
    LOCATION = N'tpch_parquet/tpchsf10_rowstore/dbo.nation/*.parquet',
    DATA_SOURCE = [TPCHParquetBlob],
    FILE_FORMAT = [TPCHParquetFormat]
);
GO

CREATE EXTERNAL TABLE [ext].[supplier]
(
    [s_suppkey] [int] NOT NULL,
    [s_nationkey] [int] NULL,
    [s_comment] [varchar](102) NULL,
    [s_name] [char](25) NULL,
    [s_address] [varchar](40) NULL,
    [s_phone] [char](15) NULL,
    [s_acctbal] [decimal](12,2) NULL
)
WITH
(
    LOCATION = N'tpch_parquet/tpchsf10_rowstore/dbo.supplier/*.parquet',
    DATA_SOURCE = [TPCHParquetBlob],
    FILE_FORMAT = [TPCHParquetFormat]
);
GO

CREATE EXTERNAL TABLE [ext].[customer]
(
    [c_custkey] [bigint] NOT NULL,
    [c_mktsegment] [char](10) NULL,
    [c_nationkey] [int] NULL,
    [c_name] [varchar](25) NULL,
    [c_address] [varchar](40) NULL,
    [c_phone] [char](15) NULL,
    [c_acctbal] [decimal](12,2) NULL,
    [c_comment] [varchar](118) NULL
)
WITH
(
    LOCATION = N'tpch_parquet/tpchsf10_rowstore/dbo.customer/*.parquet',
    DATA_SOURCE = [TPCHParquetBlob],
    FILE_FORMAT = [TPCHParquetFormat]
);
GO

CREATE EXTERNAL TABLE [ext].[part]
(
    [p_partkey] [bigint] NOT NULL,
    [p_type] [varchar](25) NULL,
    [p_size] [int] NULL,
    [p_brand] [char](10) NULL,
    [p_name] [varchar](55) NULL,
    [p_container] [char](10) NULL,
    [p_mfgr] [char](25) NULL,
    [p_retailprice] [decimal](12,2) NULL,
    [p_comment] [varchar](23) NULL
)
WITH
(
    LOCATION = N'tpch_parquet/tpchsf10_rowstore/dbo.part/*.parquet',
    DATA_SOURCE = [TPCHParquetBlob],
    FILE_FORMAT = [TPCHParquetFormat]
);
GO

CREATE EXTERNAL TABLE [ext].[partsupp]
(
    [ps_partkey] [bigint] NOT NULL,
    [ps_suppkey] [int] NOT NULL,
    [ps_supplycost] [decimal](12,2) NOT NULL,
    [ps_availqty] [int] NULL,
    [ps_comment] [varchar](199) NULL
)
WITH
(
    LOCATION = N'tpch_parquet/tpchsf10_rowstore/dbo.partsupp/*.parquet',
    DATA_SOURCE = [TPCHParquetBlob],
    FILE_FORMAT = [TPCHParquetFormat]
);
GO

CREATE EXTERNAL TABLE [ext].[orders]
(
    [o_orderdate] [date] NOT NULL,
    [o_orderkey] [bigint] NOT NULL,
    [o_custkey] [bigint] NOT NULL,
    [o_orderpriority] [char](15) NULL,
    [o_shippriority] [int] NULL,
    [o_clerk] [char](15) NULL,
    [o_orderstatus] [char](1) NULL,
    [o_totalprice] [decimal](12,2) NULL,
    [o_comment] [varchar](79) NULL
)
WITH
(
    LOCATION = N'tpch_parquet/tpchsf10_rowstore/dbo.orders/*.parquet',
    DATA_SOURCE = [TPCHParquetBlob],
    FILE_FORMAT = [TPCHParquetFormat]
);
GO

CREATE EXTERNAL TABLE [ext].[lineitem]
(
    [l_shipdate] [date] NOT NULL,
    [l_orderkey] [bigint] NOT NULL,
    [l_discount] [decimal](12,2) NOT NULL,
    [l_extendedprice] [decimal](12,2) NOT NULL,
    [l_suppkey] [int] NOT NULL,
    [l_quantity] [bigint] NOT NULL,
    [l_returnflag] [char](1) NULL,
    [l_partkey] [bigint] NOT NULL,
    [l_linestatus] [char](1) NULL,
    [l_tax] [decimal](12,2) NOT NULL,
    [l_commitdate] [date] NULL,
    [l_receiptdate] [date] NULL,
    [l_shipmode] [char](10) NULL,
    [l_linenumber] [bigint] NOT NULL,
    [l_shipinstruct] [char](25) NULL,
    [l_comment] [varchar](44) NULL
)
WITH
(
    LOCATION = N'tpch_parquet/tpchsf10_rowstore/dbo.lineitem/*.parquet',
    DATA_SOURCE = [TPCHParquetBlob],
    FILE_FORMAT = [TPCHParquetFormat]
);
GO


