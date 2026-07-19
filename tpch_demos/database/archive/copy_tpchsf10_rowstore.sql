USE master;
GO

SET NOCOUNT ON;

IF DB_ID(N'tpchsf10_columnstore') IS NULL
    THROW 50021, 'Source database is missing.', 1;

IF DB_ID(N'tpchsf10_rowstore') IS NULL
    THROW 50022, 'Target database is missing.', 1;

IF EXISTS
(
    SELECT 1
    FROM tpchsf10_rowstore.sys.tables
    WHERE is_ms_shipped = 0
)
    THROW 50023, 'Target database is not empty.', 1;
GO

USE tpchsf10_rowstore;
GO

RAISERROR(N'Copying region', 10, 1) WITH NOWAIT;
SELECT *
INTO dbo.region
FROM tpchsf10_columnstore.dbo.region
OPTION (MAXDOP 4);
CHECKPOINT;
GO

RAISERROR(N'Copying nation', 10, 1) WITH NOWAIT;
SELECT *
INTO dbo.nation
FROM tpchsf10_columnstore.dbo.nation
OPTION (MAXDOP 4);
CHECKPOINT;
GO

RAISERROR(N'Copying supplier', 10, 1) WITH NOWAIT;
SELECT *
INTO dbo.supplier
FROM tpchsf10_columnstore.dbo.supplier
OPTION (MAXDOP 4);
CHECKPOINT;
GO

RAISERROR(N'Copying customer', 10, 1) WITH NOWAIT;
SELECT *
INTO dbo.customer
FROM tpchsf10_columnstore.dbo.customer
OPTION (MAXDOP 4);
CHECKPOINT;
GO

RAISERROR(N'Copying part', 10, 1) WITH NOWAIT;
SELECT *
INTO dbo.part
FROM tpchsf10_columnstore.dbo.part
OPTION (MAXDOP 4);
CHECKPOINT;
GO

RAISERROR(N'Copying partsupp', 10, 1) WITH NOWAIT;
SELECT *
INTO dbo.partsupp
FROM tpchsf10_columnstore.dbo.partsupp
OPTION (MAXDOP 4);
CHECKPOINT;
GO

RAISERROR(N'Copying orders', 10, 1) WITH NOWAIT;
SELECT *
INTO dbo.orders
FROM tpchsf10_columnstore.dbo.orders
OPTION (MAXDOP 4);
CHECKPOINT;
GO

RAISERROR(N'Copying lineitem', 10, 1) WITH NOWAIT;
SELECT *
INTO dbo.lineitem
FROM tpchsf10_columnstore.dbo.lineitem
OPTION (MAXDOP 4);
CHECKPOINT;
GO

SELECT
    t.name AS table_name,
    SUM(p.row_count) AS row_count
FROM sys.tables AS t
JOIN sys.dm_db_partition_stats AS p
    ON p.object_id = t.object_id
   AND p.index_id IN (0, 1)
WHERE t.is_ms_shipped = 0
GROUP BY t.name
ORDER BY t.name;
GO
