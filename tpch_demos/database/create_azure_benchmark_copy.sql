USE [tpchsf100];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() <> N'tpchsf100'
    THROW 50521, 'Run this script only in tpchsf100.', 1;

IF SCHEMA_ID(N'rs') IS NOT NULL
    THROW 50522, 'Schema rs already exists.', 1;

IF
(
    SELECT COUNT(*)
    FROM sys.tables AS t
    JOIN sys.schemas AS s
      ON s.schema_id = t.schema_id
    WHERE s.name = N'dbo'
      AND t.is_ms_shipped = 0
      AND t.is_external = 0
) <> 8
    THROW 50523, 'Expected eight internal dbo source tables.', 1;

IF
(
    SELECT COUNT(*)
    FROM sys.indexes AS i
    JOIN sys.tables AS t
      ON t.object_id = i.object_id
    JOIN sys.schemas AS s
      ON s.schema_id = t.schema_id
    WHERE s.name = N'dbo'
      AND t.is_external = 0
      AND i.type = 5
) <> 8
    THROW 50524, 'Expected eight clustered columnstore dbo source tables.', 1;
GO

CREATE SCHEMA [rs];
GO

DECLARE @tables table
(
    ordinal int NOT NULL PRIMARY KEY,
    table_name sysname NOT NULL UNIQUE
);

INSERT @tables (ordinal, table_name)
VALUES
    (1, N'region'),
    (2, N'nation'),
    (3, N'supplier'),
    (4, N'customer'),
    (5, N'part'),
    (6, N'partsupp'),
    (7, N'orders'),
    (8, N'lineitem');

DECLARE
    @table_name sysname,
    @sql nvarchar(max),
    @source_rows bigint,
    @target_rows bigint;

DECLARE copy_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT table_name
FROM @tables
ORDER BY ordinal;

OPEN copy_cursor;
FETCH NEXT FROM copy_cursor INTO @table_name;

WHILE @@FETCH_STATUS = 0
BEGIN
    RAISERROR(N'Copying dbo.%s to rs.%s', 10, 1, @table_name, @table_name)
        WITH NOWAIT;

    SET @sql =
        N'SELECT * INTO rs.' + QUOTENAME(@table_name) +
        N' FROM dbo.' + QUOTENAME(@table_name) + N' OPTION (MAXDOP 4);';

    EXEC sys.sp_executesql @sql;

    SELECT @source_rows = SUM(row_count)
    FROM sys.dm_db_partition_stats
    WHERE object_id = OBJECT_ID(N'dbo.' + QUOTENAME(@table_name))
      AND index_id IN (0, 1);

    SELECT @target_rows = SUM(row_count)
    FROM sys.dm_db_partition_stats
    WHERE object_id = OBJECT_ID(N'rs.' + QUOTENAME(@table_name))
      AND index_id IN (0, 1);

    IF @source_rows <> @target_rows
        THROW 50525, 'Copied table row count differs from dbo.', 1;

    FETCH NEXT FROM copy_cursor INTO @table_name;
END;

CLOSE copy_cursor;
DEALLOCATE copy_cursor;

IF EXISTS
(
    SELECT 1
    FROM sys.tables AS t
    JOIN sys.schemas AS s
      ON s.schema_id = t.schema_id
    JOIN sys.indexes AS i
      ON i.object_id = t.object_id
    WHERE s.name = N'rs'
      AND t.is_external = 0
      AND i.index_id <> 0
)
    THROW 50526, 'A copied rs table unexpectedly contains an index.', 1;

SELECT
    t.name AS table_name,
    SUM(p.row_count) AS row_count,
    MAX(i.type_desc) AS base_storage
FROM sys.tables AS t
JOIN sys.schemas AS s
  ON s.schema_id = t.schema_id
JOIN sys.dm_db_partition_stats AS p
  ON p.object_id = t.object_id
 AND p.index_id IN (0, 1)
JOIN sys.indexes AS i
  ON i.object_id = t.object_id
 AND i.index_id = p.index_id
WHERE s.name = N'rs'
  AND t.is_external = 0
GROUP BY t.name
ORDER BY t.name;
GO
