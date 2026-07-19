USE master;
GO

SET NOCOUNT ON;

IF DB_ID(N'tpchsf100') IS NOT NULL
    THROW 50041, 'The old database name still exists.', 1;

IF DB_ID(N'tpchsf10_columnstore') IS NULL
    THROW 50042, 'The columnstore source database is missing.', 1;

IF DB_ID(N'tpchsf10_rowstore') IS NULL
    THROW 50043, 'The rowstore target database is missing.', 1;

CREATE TABLE #data_comparison
(
    table_name sysname NOT NULL,
    source_rows bigint NOT NULL,
    target_rows bigint NOT NULL,
    source_checksum int NULL,
    target_checksum int NULL
);

DECLARE
    @table_name sysname,
    @sql nvarchar(max),
    @source_rows bigint,
    @target_rows bigint,
    @source_checksum int,
    @target_checksum int;

DECLARE table_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT name
FROM tpchsf10_columnstore.sys.tables
WHERE is_ms_shipped = 0
ORDER BY name;

OPEN table_cursor;
FETCH NEXT FROM table_cursor INTO @table_name;

WHILE @@FETCH_STATUS = 0
BEGIN
    RAISERROR(N'Checksumming %s', 10, 1, @table_name) WITH NOWAIT;

    SET @sql = N'
        SELECT
            @rows = COUNT_BIG(*),
            @checksum = CHECKSUM_AGG(BINARY_CHECKSUM(*))
        FROM tpchsf10_columnstore.dbo.' + QUOTENAME(@table_name) + N'
        OPTION (MAXDOP 4);';

    EXEC sys.sp_executesql
        @sql,
        N'@rows bigint OUTPUT, @checksum int OUTPUT',
        @rows = @source_rows OUTPUT,
        @checksum = @source_checksum OUTPUT;

    SET @sql = N'
        SELECT
            @rows = COUNT_BIG(*),
            @checksum = CHECKSUM_AGG(BINARY_CHECKSUM(*))
        FROM tpchsf10_rowstore.dbo.' + QUOTENAME(@table_name) + N'
        OPTION (MAXDOP 4);';

    EXEC sys.sp_executesql
        @sql,
        N'@rows bigint OUTPUT, @checksum int OUTPUT',
        @rows = @target_rows OUTPUT,
        @checksum = @target_checksum OUTPUT;

    INSERT #data_comparison
    (
        table_name,
        source_rows,
        target_rows,
        source_checksum,
        target_checksum
    )
    VALUES
    (
        @table_name,
        @source_rows,
        @target_rows,
        @source_checksum,
        @target_checksum
    );

    FETCH NEXT FROM table_cursor INTO @table_name;
END;

CLOSE table_cursor;
DEALLOCATE table_cursor;

SELECT
    table_name,
    source_rows,
    target_rows,
    source_checksum,
    target_checksum,
    CASE
        WHEN source_rows = target_rows
         AND source_checksum = target_checksum
        THEN N'MATCH'
        ELSE N'MISMATCH'
    END AS validation_status
FROM #data_comparison
ORDER BY table_name;

IF EXISTS
(
    SELECT 1
    FROM #data_comparison
    WHERE source_rows <> target_rows
       OR source_checksum <> target_checksum
       OR (source_checksum IS NULL AND target_checksum IS NOT NULL)
       OR (source_checksum IS NOT NULL AND target_checksum IS NULL)
)
    THROW 50044, 'Source and target data validation failed.', 1;
GO

CREATE TABLE #source_columns
(
    table_name sysname NOT NULL,
    column_id int NOT NULL,
    column_name sysname NOT NULL,
    system_type_id tinyint NOT NULL,
    max_length smallint NOT NULL,
    precision_value tinyint NOT NULL,
    scale_value tinyint NOT NULL,
    collation_name sysname NULL,
    is_nullable bit NOT NULL,
    is_identity bit NOT NULL,
    is_computed bit NOT NULL
);

CREATE TABLE #target_columns
(
    table_name sysname NOT NULL,
    column_id int NOT NULL,
    column_name sysname NOT NULL,
    system_type_id tinyint NOT NULL,
    max_length smallint NOT NULL,
    precision_value tinyint NOT NULL,
    scale_value tinyint NOT NULL,
    collation_name sysname NULL,
    is_nullable bit NOT NULL,
    is_identity bit NOT NULL,
    is_computed bit NOT NULL
);

INSERT #source_columns
SELECT
    t.name,
    c.column_id,
    c.name,
    c.system_type_id,
    c.max_length,
    c.precision,
    c.scale,
    c.collation_name,
    c.is_nullable,
    c.is_identity,
    c.is_computed
FROM tpchsf10_columnstore.sys.tables AS t
JOIN tpchsf10_columnstore.sys.columns AS c
    ON c.object_id = t.object_id
WHERE t.is_ms_shipped = 0;

INSERT #target_columns
SELECT
    t.name,
    c.column_id,
    c.name,
    c.system_type_id,
    c.max_length,
    c.precision,
    c.scale,
    c.collation_name,
    c.is_nullable,
    c.is_identity,
    c.is_computed
FROM tpchsf10_rowstore.sys.tables AS t
JOIN tpchsf10_rowstore.sys.columns AS c
    ON c.object_id = t.object_id
WHERE t.is_ms_shipped = 0;

IF EXISTS
(
    SELECT *
    FROM #source_columns
    EXCEPT
    SELECT *
    FROM #target_columns
)
OR EXISTS
(
    SELECT *
    FROM #target_columns
    EXCEPT
    SELECT *
    FROM #source_columns
)
    THROW 50045, 'Source and target column definitions differ.', 1;

SELECT
    COUNT(DISTINCT table_name) AS table_count,
    COUNT(*) AS column_count,
    N'MATCH' AS validation_status
FROM #target_columns;
GO

USE tpchsf10_rowstore;
GO

CREATE TABLE #actual_indexes
(
    table_name sysname NOT NULL,
    index_name sysname NOT NULL,
    index_type nvarchar(60) NOT NULL,
    key_columns nvarchar(4000) NOT NULL,
    is_primary_key bit NOT NULL
);

CREATE TABLE #expected_indexes
(
    table_name sysname NOT NULL,
    index_name sysname NOT NULL,
    index_type nvarchar(60) NOT NULL,
    key_columns nvarchar(4000) NOT NULL,
    is_primary_key bit NOT NULL
);

INSERT #actual_indexes
SELECT
    t.name,
    i.name,
    i.type_desc,
    STRING_AGG(CONVERT(nvarchar(max), c.name), N',')
        WITHIN GROUP (ORDER BY ic.key_ordinal),
    i.is_primary_key
FROM sys.tables AS t
JOIN sys.indexes AS i
    ON i.object_id = t.object_id
JOIN sys.index_columns AS ic
    ON ic.object_id = i.object_id
   AND ic.index_id = i.index_id
   AND ic.key_ordinal > 0
JOIN sys.columns AS c
    ON c.object_id = ic.object_id
   AND c.column_id = ic.column_id
WHERE t.is_ms_shipped = 0
  AND i.index_id > 0
  AND i.is_hypothetical = 0
GROUP BY
    t.name,
    i.name,
    i.type_desc,
    i.is_primary_key;

INSERT #expected_indexes
VALUES
    (N'customer', N'customer_pk', N'CLUSTERED', N'c_custkey', 1),
    (N'lineitem', N'l_orderkey_ind', N'NONCLUSTERED', N'l_orderkey', 0),
    (N'lineitem', N'l_partkey_ind', N'NONCLUSTERED', N'l_partkey', 0),
    (N'lineitem', N'l_shipdate_ind', N'CLUSTERED', N'l_shipdate', 0),
    (N'nation', N'n_regionkey_ind', N'NONCLUSTERED', N'n_regionkey', 0),
    (N'nation', N'nation_pk', N'CLUSTERED', N'n_nationkey', 1),
    (N'orders', N'o_orderdate_ind', N'CLUSTERED', N'o_orderdate', 0),
    (N'orders', N'orders_pk', N'NONCLUSTERED', N'o_orderkey', 1),
    (N'part', N'part_pk', N'CLUSTERED', N'p_partkey', 1),
    (N'partsupp', N'partsupp_pk', N'CLUSTERED', N'ps_partkey,ps_suppkey', 1),
    (N'partsupp', N'ps_suppkey_ind', N'NONCLUSTERED', N'ps_suppkey', 0),
    (N'region', N'region_pk', N'CLUSTERED', N'r_regionkey', 1),
    (N'supplier', N's_nationkey_ind', N'NONCLUSTERED', N's_nationkey', 0),
    (N'supplier', N'supplier_pk', N'CLUSTERED', N's_suppkey', 1);

IF EXISTS
(
    SELECT *
    FROM #actual_indexes
    EXCEPT
    SELECT *
    FROM #expected_indexes
)
OR EXISTS
(
    SELECT *
    FROM #expected_indexes
    EXCEPT
    SELECT *
    FROM #actual_indexes
)
    THROW 50046, 'The rowstore index set differs from the expected design.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.indexes AS i
    JOIN sys.tables AS t
        ON t.object_id = i.object_id
    WHERE t.is_ms_shipped = 0
      AND i.type IN (5, 6)
)
    THROW 50047, 'The rowstore database contains a columnstore index.', 1;

IF
(
    SELECT COUNT(*)
    FROM tpchsf10_columnstore.sys.indexes AS i
    JOIN tpchsf10_columnstore.sys.tables AS t
        ON t.object_id = i.object_id
    WHERE t.is_ms_shipped = 0
      AND i.type = 5
) <> 8
    THROW 50048, 'The source database no longer has eight clustered columnstore indexes.', 1;

SELECT *
FROM #actual_indexes
ORDER BY table_name, index_name;
GO

DECLARE
    @foreign_key_count int,
    @disabled_foreign_keys int,
    @untrusted_foreign_keys int;

SELECT
    @foreign_key_count = COUNT(*),
    @disabled_foreign_keys = COALESCE(SUM(CONVERT(int, is_disabled)), 0),
    @untrusted_foreign_keys = COALESCE(SUM(CONVERT(int, is_not_trusted)), 0)
FROM sys.foreign_keys
WHERE is_ms_shipped = 0;

IF @foreign_key_count <> 10
   OR @disabled_foreign_keys <> 0
   OR @untrusted_foreign_keys <> 0
    THROW 50049, 'Expected ten enabled and trusted foreign keys.', 1;

SELECT
    @foreign_key_count AS foreign_key_count,
    @disabled_foreign_keys AS disabled_foreign_keys,
    @untrusted_foreign_keys AS untrusted_foreign_keys,
    N'VALID' AS validation_status;
GO

IF EXISTS
(
    SELECT 1
    FROM sys.tables AS t
    JOIN sys.indexes AS i
        ON i.object_id = t.object_id
       AND i.index_id > 0
       AND i.is_hypothetical = 0
    OUTER APPLY sys.dm_db_stats_properties(i.object_id, i.index_id) AS sp
    WHERE t.is_ms_shipped = 0
      AND sp.last_updated IS NULL
)
    THROW 50050, 'One or more index statistics have not been generated.', 1;

SELECT
    t.name AS table_name,
    COUNT(*) AS index_statistics_count,
    MIN(sp.last_updated) AS oldest_index_statistics,
    MAX(sp.last_updated) AS newest_index_statistics
FROM sys.tables AS t
JOIN sys.indexes AS i
    ON i.object_id = t.object_id
   AND i.index_id > 0
   AND i.is_hypothetical = 0
CROSS APPLY sys.dm_db_stats_properties(i.object_id, i.index_id) AS sp
WHERE t.is_ms_shipped = 0
GROUP BY t.name
ORDER BY t.name;
GO

CREATE TABLE #storage
(
    database_name sysname NOT NULL,
    file_type nvarchar(60) NOT NULL,
    allocated_mb decimal(18, 2) NOT NULL,
    used_mb decimal(18, 2) NOT NULL,
    physical_name nvarchar(260) NOT NULL
);
GO

USE tpchsf10_columnstore;
GO

INSERT #storage
SELECT
    DB_NAME(),
    type_desc,
    CAST(size * 8.0 / 1024 AS decimal(18, 2)),
    CAST
    (
        CASE
            WHEN type_desc = N'ROWS'
                THEN FILEPROPERTY(name, N'SpaceUsed') * 8.0 / 1024
            ELSE
                (SELECT used_log_space_in_bytes / 1048576.0
                 FROM sys.dm_db_log_space_usage)
        END
        AS decimal(18, 2)
    ),
    physical_name
FROM sys.database_files;
GO

USE tpchsf10_rowstore;
GO

INSERT #storage
SELECT
    DB_NAME(),
    type_desc,
    CAST(size * 8.0 / 1024 AS decimal(18, 2)),
    CAST
    (
        CASE
            WHEN type_desc = N'ROWS'
                THEN FILEPROPERTY(name, N'SpaceUsed') * 8.0 / 1024
            ELSE
                (SELECT used_log_space_in_bytes / 1048576.0
                 FROM sys.dm_db_log_space_usage)
        END
        AS decimal(18, 2)
    ),
    physical_name
FROM sys.database_files;

SELECT
    database_name,
    file_type,
    allocated_mb,
    used_mb,
    physical_name
FROM #storage
ORDER BY database_name, file_type;
GO
