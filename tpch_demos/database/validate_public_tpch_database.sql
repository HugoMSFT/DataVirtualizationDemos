/*
Run in SQLCMD mode and supply:
  LAYOUT        = columnstore, rowstore, or external
  TARGET_SCHEMA = dbo for imported/restored data, ext for public Parquet
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE
    @layout nvarchar(20) = LOWER(LTRIM(RTRIM(N'$(LAYOUT)'))),
    @target_schema sysname = N'$(TARGET_SCHEMA)';

IF @layout NOT IN (N'columnstore', N'rowstore', N'external')
    THROW 50801, 'LAYOUT must be columnstore, rowstore, or external.', 1;

IF (@layout = N'external' AND @target_schema <> N'ext')
   OR (@layout <> N'external' AND @target_schema <> N'dbo')
    THROW 50802, 'Use TARGET_SCHEMA=ext for external and dbo otherwise.', 1;

IF SCHEMA_ID(@target_schema) IS NULL
    THROW 50803, 'The target schema does not exist.', 1;

IF @layout = N'external'
BEGIN
    IF
    (
        SELECT COUNT(*)
        FROM sys.external_tables AS t
        JOIN sys.schemas AS s
          ON s.schema_id = t.schema_id
        WHERE s.name = @target_schema
    ) <> 8
        THROW 50804, 'Expected eight external tables.', 1;
END;
ELSE
BEGIN
    IF
    (
        SELECT COUNT(*)
        FROM sys.tables AS t
        JOIN sys.schemas AS s
          ON s.schema_id = t.schema_id
        WHERE s.name = @target_schema
          AND t.is_external = 0
          AND t.is_ms_shipped = 0
    ) <> 8
        THROW 50805, 'Expected eight internal tables.', 1;
END;

CREATE TABLE #expected_rows
(
    table_name sysname NOT NULL PRIMARY KEY,
    expected_rows bigint NOT NULL
);

INSERT #expected_rows (table_name, expected_rows)
VALUES
    (N'customer', 1500000),
    (N'lineitem', 59999496),
    (N'nation', 25),
    (N'orders', 15000000),
    (N'part', 2000000),
    (N'partsupp', 8000000),
    (N'region', 5),
    (N'supplier', 100000);

CREATE TABLE #actual_rows
(
    table_name sysname NOT NULL PRIMARY KEY,
    expected_rows bigint NOT NULL,
    actual_rows bigint NOT NULL
);

DECLARE
    @table_name sysname,
    @expected_count bigint,
    @actual_count bigint,
    @sql nvarchar(max);

DECLARE table_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT table_name, expected_rows
FROM #expected_rows
ORDER BY table_name;

OPEN table_cursor;
FETCH NEXT FROM table_cursor INTO @table_name, @expected_count;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql =
        N'SELECT @rows = COUNT_BIG(*) FROM ' +
        QUOTENAME(@target_schema) + N'.' + QUOTENAME(@table_name) +
        N' OPTION (MAXDOP 4);';

    EXEC sys.sp_executesql
        @sql,
        N'@rows bigint OUTPUT',
        @rows = @actual_count OUTPUT;

    INSERT #actual_rows (table_name, expected_rows, actual_rows)
    VALUES (@table_name, @expected_count, @actual_count);

    FETCH NEXT FROM table_cursor INTO @table_name, @expected_count;
END;

CLOSE table_cursor;
DEALLOCATE table_cursor;

IF EXISTS
(
    SELECT 1
    FROM #actual_rows
    WHERE expected_rows <> actual_rows
)
    THROW 50806, 'One or more public tables have an unexpected row count.', 1;

IF @layout = N'columnstore'
   AND
   (
       SELECT COUNT(*)
       FROM sys.indexes AS i
       JOIN sys.tables AS t
         ON t.object_id = i.object_id
       JOIN sys.schemas AS s
         ON s.schema_id = t.schema_id
       WHERE s.name = @target_schema
         AND t.is_external = 0
         AND i.type = 5
   ) <> 8
    THROW 50807, 'Expected eight clustered columnstore indexes.', 1;

IF @layout = N'rowstore'
BEGIN
    IF EXISTS
    (
        SELECT 1
        FROM sys.indexes AS i
        JOIN sys.tables AS t
          ON t.object_id = i.object_id
        JOIN sys.schemas AS s
          ON s.schema_id = t.schema_id
        WHERE s.name = @target_schema
          AND t.is_external = 0
          AND i.type IN (5, 6)
    )
        THROW 50808, 'The rowstore database contains a columnstore index.', 1;

    IF
    (
        SELECT COUNT(*)
        FROM sys.indexes AS i
        JOIN sys.tables AS t
          ON t.object_id = i.object_id
        JOIN sys.schemas AS s
          ON s.schema_id = t.schema_id
        WHERE s.name = @target_schema
          AND t.is_external = 0
          AND i.index_id > 0
          AND i.is_hypothetical = 0
    ) <> 14
        THROW 50809, 'Expected 14 rowstore indexes.', 1;

    IF
    (
        SELECT COUNT(*)
        FROM sys.foreign_keys AS fk
        JOIN sys.tables AS t
          ON t.object_id = fk.parent_object_id
        JOIN sys.schemas AS s
          ON s.schema_id = t.schema_id
        WHERE s.name = @target_schema
    ) <> 10
        THROW 50810, 'Expected 10 enabled and trusted foreign keys.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM sys.foreign_keys AS fk
        JOIN sys.tables AS t
          ON t.object_id = fk.parent_object_id
        JOIN sys.schemas AS s
          ON s.schema_id = t.schema_id
        WHERE s.name = @target_schema
          AND (fk.is_disabled = 1 OR fk.is_not_trusted = 1)
    )
        THROW 50814, 'A rowstore foreign key is disabled or untrusted.', 1;
END;

IF @layout = N'external'
BEGIN
    IF EXISTS
    (
        SELECT 1
        FROM sys.external_tables AS et
        JOIN sys.schemas AS s
          ON s.schema_id = et.schema_id
        WHERE s.name = @target_schema
          AND et.location <>
              N'tpch_parquet/tpchsf10_rowstore/dbo.' + et.name +
              N'/*.parquet'
    )
        THROW 50811, 'An external table points to an unexpected path.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.external_data_sources
        WHERE name = N'TPCHParquetBlob'
          AND location =
              N'abs://tpch@tpcpublicstorage.blob.core.windows.net/'
          AND COALESCE(credential_id, 0) = 0
    )
        THROW 50812, 'The anonymous public data source is invalid.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.external_file_formats
        WHERE name = N'TPCHParquetFormat'
          AND format_type = N'PARQUET'
    )
        THROW 50813, 'The Parquet external file format is invalid.', 1;
END;

SELECT
    DB_NAME() AS database_name,
    @layout AS layout_name,
    @target_schema AS schema_name,
    table_name,
    expected_rows,
    actual_rows,
    N'MATCH' AS validation_status
FROM #actual_rows
ORDER BY table_name;
