USE [$(DATABASE_NAME)];
GO

SET NOCOUNT ON;

IF (SELECT COUNT(*) FROM sys.external_tables
    WHERE name LIKE N'__tpch_parquet_%') <> 8
    THROW 50231, 'Expected eight temporary Parquet external tables.', 1;

CREATE TABLE #row_counts
(
    table_name sysname NOT NULL,
    source_rows bigint NOT NULL,
    parquet_rows bigint NOT NULL
);

INSERT #row_counts
VALUES
    (N'customer',
     (SELECT COUNT_BIG(*) FROM dbo.customer),
     (SELECT COUNT_BIG(*) FROM dbo.__tpch_parquet_customer)),
    (N'lineitem',
     (SELECT COUNT_BIG(*) FROM dbo.lineitem),
     (SELECT COUNT_BIG(*) FROM dbo.__tpch_parquet_lineitem)),
    (N'nation',
     (SELECT COUNT_BIG(*) FROM dbo.nation),
     (SELECT COUNT_BIG(*) FROM dbo.__tpch_parquet_nation)),
    (N'orders',
     (SELECT COUNT_BIG(*) FROM dbo.orders),
     (SELECT COUNT_BIG(*) FROM dbo.__tpch_parquet_orders)),
    (N'part',
     (SELECT COUNT_BIG(*) FROM dbo.part),
     (SELECT COUNT_BIG(*) FROM dbo.__tpch_parquet_part)),
    (N'partsupp',
     (SELECT COUNT_BIG(*) FROM dbo.partsupp),
     (SELECT COUNT_BIG(*) FROM dbo.__tpch_parquet_partsupp)),
    (N'region',
     (SELECT COUNT_BIG(*) FROM dbo.region),
     (SELECT COUNT_BIG(*) FROM dbo.__tpch_parquet_region)),
    (N'supplier',
     (SELECT COUNT_BIG(*) FROM dbo.supplier),
     (SELECT COUNT_BIG(*) FROM dbo.__tpch_parquet_supplier));

SELECT
    DB_NAME() AS database_name,
    table_name,
    source_rows,
    parquet_rows,
    CASE WHEN source_rows = parquet_rows THEN N'MATCH' ELSE N'MISMATCH' END
        AS validation_status
FROM #row_counts
ORDER BY table_name;

IF EXISTS
(
    SELECT 1
    FROM #row_counts
    WHERE source_rows <> parquet_rows
)
    THROW 50232, 'Source and Parquet row counts differ.', 1;
GO
