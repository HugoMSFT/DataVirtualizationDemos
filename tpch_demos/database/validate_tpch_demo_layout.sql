/*
Run in SQLCMD mode and supply:
  HAS_HP            = 1 for the VM layout, 0 for Azure SQL
  RS_INDEX_COUNT    = 14 for the VM layout, 8 for Azure SQL
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE
    @has_hp bit = TRY_CONVERT(bit, N'$(HAS_HP)'),
    @expected_rs_indexes int = TRY_CONVERT(int, N'$(RS_INDEX_COUNT)');

IF @has_hp IS NULL
    THROW 50701, 'HAS_HP must be 0 or 1.', 1;

IF @expected_rs_indexes IS NULL OR @expected_rs_indexes < 1
    THROW 50702, 'RS_INDEX_COUNT must be a positive integer.', 1;

IF SCHEMA_ID(N'dbo') IS NULL
   OR SCHEMA_ID(N'rs') IS NULL
   OR SCHEMA_ID(N'ext') IS NULL
    THROW 50703, 'One or more required schemas are missing.', 1;

IF @has_hp = 1 AND SCHEMA_ID(N'hp') IS NULL
    THROW 50704, 'The VM layout requires schema hp.', 1;

IF @has_hp = 0
   AND EXISTS
       (SELECT 1
        FROM sys.tables
        WHERE schema_id = SCHEMA_ID(N'hp')
          AND is_ms_shipped = 0)
    THROW 50705, 'The Azure layout must not contain hp tables.', 1;

CREATE TABLE #schema_summary
(
    schema_name sysname NOT NULL PRIMARY KEY,
    internal_tables int NOT NULL,
    external_tables int NOT NULL,
    indexes int NOT NULL,
    foreign_keys int NOT NULL,
    untrusted_foreign_keys int NOT NULL,
    disabled_foreign_keys int NOT NULL
);

INSERT #schema_summary
(
    schema_name,
    internal_tables,
    external_tables,
    indexes,
    foreign_keys,
    untrusted_foreign_keys,
    disabled_foreign_keys
)
SELECT
    expected.schema_name,
    (
        SELECT COUNT(*)
        FROM sys.tables AS t
        JOIN sys.schemas AS s
          ON s.schema_id = t.schema_id
        WHERE s.name = expected.schema_name
          AND t.is_external = 0
          AND t.is_ms_shipped = 0
    ),
    (
        SELECT COUNT(*)
        FROM sys.external_tables AS t
        JOIN sys.schemas AS s
          ON s.schema_id = t.schema_id
        WHERE s.name = expected.schema_name
    ),
    (
        SELECT COUNT(*)
        FROM sys.indexes AS i
        JOIN sys.tables AS t
          ON t.object_id = i.object_id
        JOIN sys.schemas AS s
          ON s.schema_id = t.schema_id
        WHERE s.name = expected.schema_name
          AND t.is_external = 0
          AND i.index_id > 0
          AND i.is_hypothetical = 0
    ),
    (
        SELECT COUNT(*)
        FROM sys.foreign_keys AS fk
        JOIN sys.tables AS t
          ON t.object_id = fk.parent_object_id
        JOIN sys.schemas AS s
          ON s.schema_id = t.schema_id
        WHERE s.name = expected.schema_name
    ),
    (
        SELECT COUNT(*)
        FROM sys.foreign_keys AS fk
        JOIN sys.tables AS t
          ON t.object_id = fk.parent_object_id
        JOIN sys.schemas AS s
          ON s.schema_id = t.schema_id
        WHERE s.name = expected.schema_name
          AND fk.is_not_trusted = 1
    ),
    (
        SELECT COUNT(*)
        FROM sys.foreign_keys AS fk
        JOIN sys.tables AS t
          ON t.object_id = fk.parent_object_id
        JOIN sys.schemas AS s
          ON s.schema_id = t.schema_id
        WHERE s.name = expected.schema_name
          AND fk.is_disabled = 1
    )
FROM
(
    SELECT N'dbo' AS schema_name
    UNION ALL SELECT N'rs'
    UNION ALL SELECT N'ext'
    UNION ALL SELECT N'hp' WHERE @has_hp = 1
) AS expected;

IF EXISTS
(
    SELECT 1
    FROM #schema_summary
    WHERE (schema_name IN (N'dbo', N'rs', N'hp') AND internal_tables <> 8)
       OR (schema_name = N'ext' AND external_tables <> 8)
)
    THROW 50706, 'A schema does not contain the expected eight tables.', 1;

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
    THROW 50707, 'dbo must contain eight clustered columnstore indexes.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.indexes AS i
    JOIN sys.tables AS t
      ON t.object_id = i.object_id
    JOIN sys.schemas AS s
      ON s.schema_id = t.schema_id
    WHERE s.name = N'rs'
      AND t.is_external = 0
      AND i.type IN (5, 6)
)
    THROW 50708, 'rs contains a columnstore index.', 1;

IF
(
    SELECT indexes
    FROM #schema_summary
    WHERE schema_name = N'rs'
) <> @expected_rs_indexes
    THROW 50709, 'rs index count differs from the expected design.', 1;

IF EXISTS
(
    SELECT 1
    FROM #schema_summary
    WHERE schema_name = N'rs'
      AND
      (
          foreign_keys <> 10
          OR untrusted_foreign_keys <> 0
          OR disabled_foreign_keys <> 0
      )
)
    THROW 50710, 'rs must contain ten enabled and trusted foreign keys.', 1;

IF @has_hp = 1
BEGIN
    IF EXISTS
    (
        SELECT 1
        FROM sys.indexes AS i
        JOIN sys.tables AS t
          ON t.object_id = i.object_id
        JOIN sys.schemas AS s
          ON s.schema_id = t.schema_id
        WHERE s.name = N'hp'
          AND t.is_external = 0
          AND i.index_id <> 0
    )
        THROW 50711, 'hp must contain only heaps.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM #schema_summary
        WHERE schema_name = N'hp'
          AND (indexes <> 0 OR foreign_keys <> 0)
    )
        THROW 50712, 'hp must not contain indexes or foreign keys.', 1;
END;

CREATE TABLE #dbo_columns
(
    table_name sysname NOT NULL,
    column_id int NOT NULL,
    column_name sysname NOT NULL,
    system_type_id tinyint NOT NULL,
    max_length smallint NOT NULL,
    precision_value tinyint NOT NULL,
    scale_value tinyint NOT NULL,
    collation_name sysname NULL,
    is_nullable bit NOT NULL
);

INSERT #dbo_columns
SELECT
    t.name,
    c.column_id,
    c.name,
    c.system_type_id,
    c.max_length,
    c.precision,
    c.scale,
    c.collation_name,
    c.is_nullable
FROM sys.tables AS t
JOIN sys.schemas AS s
  ON s.schema_id = t.schema_id
JOIN sys.columns AS c
  ON c.object_id = t.object_id
WHERE s.name = N'dbo'
  AND t.is_external = 0;

CREATE TABLE #target_columns
(
    schema_name sysname NOT NULL,
    table_name sysname NOT NULL,
    column_id int NOT NULL,
    column_name sysname NOT NULL,
    system_type_id tinyint NOT NULL,
    max_length smallint NOT NULL,
    precision_value tinyint NOT NULL,
    scale_value tinyint NOT NULL,
    collation_name sysname NULL,
    is_nullable bit NOT NULL
);

INSERT #target_columns
SELECT
    s.name,
    t.name,
    c.column_id,
    c.name,
    c.system_type_id,
    c.max_length,
    c.precision,
    c.scale,
    c.collation_name,
    c.is_nullable
FROM sys.tables AS t
JOIN sys.schemas AS s
  ON s.schema_id = t.schema_id
JOIN sys.columns AS c
  ON c.object_id = t.object_id
WHERE s.name IN (N'rs', N'hp')
  AND t.is_external = 0
  AND (s.name <> N'hp' OR @has_hp = 1);

IF EXISTS
(
    SELECT table_name, column_id, column_name, system_type_id, max_length,
           precision_value, scale_value, collation_name, is_nullable
    FROM #target_columns
    WHERE schema_name = N'rs'
    EXCEPT
    SELECT *
    FROM #dbo_columns
)
OR EXISTS
(
    SELECT *
    FROM #dbo_columns
    EXCEPT
    SELECT table_name, column_id, column_name, system_type_id, max_length,
           precision_value, scale_value, collation_name, is_nullable
    FROM #target_columns
    WHERE schema_name = N'rs'
)
    THROW 50713, 'rs column definitions differ from dbo.', 1;

IF @has_hp = 1
   AND
   (
       EXISTS
       (
           SELECT table_name, column_id, column_name, system_type_id,
                  max_length, precision_value, scale_value, collation_name,
                  is_nullable
           FROM #target_columns
           WHERE schema_name = N'hp'
           EXCEPT
           SELECT *
           FROM #dbo_columns
       )
       OR EXISTS
       (
           SELECT *
           FROM #dbo_columns
           EXCEPT
           SELECT table_name, column_id, column_name, system_type_id,
                  max_length, precision_value, scale_value, collation_name,
                  is_nullable
           FROM #target_columns
           WHERE schema_name = N'hp'
       )
   )
    THROW 50714, 'hp column definitions differ from dbo.', 1;

CREATE TABLE #data_comparison
(
    schema_name sysname NOT NULL,
    table_name sysname NOT NULL,
    row_count bigint NOT NULL,
    aggregate_checksum int NULL,
    PRIMARY KEY (schema_name, table_name)
);

DECLARE
    @schema_name sysname,
    @table_name sysname,
    @sql nvarchar(max),
    @row_count bigint,
    @aggregate_checksum int;

DECLARE data_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT schemas.schema_name, tables.name
FROM
(
    SELECT N'dbo' AS schema_name, 1 AS ordinal
    UNION ALL SELECT N'rs', 2
    UNION ALL SELECT N'hp', 3 WHERE @has_hp = 1
) AS schemas
CROSS JOIN
(
    SELECT t.name
    FROM sys.tables AS t
    JOIN sys.schemas AS s
      ON s.schema_id = t.schema_id
    WHERE s.name = N'dbo'
      AND t.is_external = 0
) AS tables
ORDER BY schemas.ordinal, tables.name;

OPEN data_cursor;
FETCH NEXT FROM data_cursor INTO @schema_name, @table_name;

WHILE @@FETCH_STATUS = 0
BEGIN
    RAISERROR
    (
        N'Validating %s.%s',
        10,
        1,
        @schema_name,
        @table_name
    ) WITH NOWAIT;

    SET @sql =
        N'SELECT @rows = COUNT_BIG(*), ' +
        N'@checksum = CHECKSUM_AGG(BINARY_CHECKSUM(*)) FROM ' +
        QUOTENAME(@schema_name) + N'.' + QUOTENAME(@table_name) +
        N' OPTION (MAXDOP 4);';

    EXEC sys.sp_executesql
        @sql,
        N'@rows bigint OUTPUT, @checksum int OUTPUT',
        @rows = @row_count OUTPUT,
        @checksum = @aggregate_checksum OUTPUT;

    INSERT #data_comparison
    VALUES
        (@schema_name, @table_name, @row_count, @aggregate_checksum);

    FETCH NEXT FROM data_cursor INTO @schema_name, @table_name;
END;

CLOSE data_cursor;
DEALLOCATE data_cursor;

IF EXISTS
(
    SELECT table_name, row_count, aggregate_checksum
    FROM #data_comparison
    WHERE schema_name = N'rs'
    EXCEPT
    SELECT table_name, row_count, aggregate_checksum
    FROM #data_comparison
    WHERE schema_name = N'dbo'
)
OR EXISTS
(
    SELECT table_name, row_count, aggregate_checksum
    FROM #data_comparison
    WHERE schema_name = N'dbo'
    EXCEPT
    SELECT table_name, row_count, aggregate_checksum
    FROM #data_comparison
    WHERE schema_name = N'rs'
)
    THROW 50715, 'rs data differs from dbo.', 1;

IF @has_hp = 1
   AND
   (
       EXISTS
       (
           SELECT table_name, row_count, aggregate_checksum
           FROM #data_comparison
           WHERE schema_name = N'hp'
           EXCEPT
           SELECT table_name, row_count, aggregate_checksum
           FROM #data_comparison
           WHERE schema_name = N'dbo'
       )
       OR EXISTS
       (
           SELECT table_name, row_count, aggregate_checksum
           FROM #data_comparison
           WHERE schema_name = N'dbo'
           EXCEPT
           SELECT table_name, row_count, aggregate_checksum
           FROM #data_comparison
           WHERE schema_name = N'hp'
       )
   )
    THROW 50716, 'hp data differs from dbo.', 1;

CREATE TABLE #expected_external_rows
(
    table_name sysname NOT NULL PRIMARY KEY,
    expected_rows bigint NOT NULL
);

INSERT #expected_external_rows
VALUES
    (N'customer', 1500000),
    (N'lineitem', 59999496),
    (N'nation', 25),
    (N'orders', 15000000),
    (N'part', 2000000),
    (N'partsupp', 8000000),
    (N'region', 5),
    (N'supplier', 100000);

CREATE TABLE #external_counts
(
    table_name sysname NOT NULL PRIMARY KEY,
    expected_rows bigint NOT NULL,
    external_rows bigint NOT NULL
);

DECLARE external_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT table_name, expected_rows
FROM #expected_external_rows
ORDER BY table_name;

DECLARE @expected_rows bigint;

OPEN external_cursor;
FETCH NEXT FROM external_cursor INTO @table_name, @expected_rows;

WHILE @@FETCH_STATUS = 0
BEGIN
    RAISERROR(N'Counting ext.%s', 10, 1, @table_name) WITH NOWAIT;

    SET @sql =
        N'SELECT @rows = COUNT_BIG(*) FROM ext.' +
        QUOTENAME(@table_name) + N' OPTION (MAXDOP 4);';

    EXEC sys.sp_executesql
        @sql,
        N'@rows bigint OUTPUT',
        @rows = @row_count OUTPUT;

    INSERT #external_counts
    VALUES (@table_name, @expected_rows, @row_count);

    FETCH NEXT FROM external_cursor INTO @table_name, @expected_rows;
END;

CLOSE external_cursor;
DEALLOCATE external_cursor;

IF EXISTS
(
    SELECT 1
    FROM #external_counts
    WHERE expected_rows <> external_rows
)
    THROW 50717, 'An ext table row count differs from its Parquet dataset.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.external_tables AS et
    JOIN sys.schemas AS s
      ON s.schema_id = et.schema_id
    WHERE s.name = N'ext'
      AND et.location <>
          N'tpch_parquet/tpchsf10_rowstore/dbo.' + et.name + N'/*.parquet'
)
    THROW 50718, 'An ext table points to an unexpected Blob path.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.external_data_sources
    WHERE name = N'TPCHParquetBlob'
      AND location =
          N'abs://tpch@tpcpublicstorage.blob.core.windows.net/'
      AND COALESCE(credential_id, 0) = 0
)
    THROW 50719, 'The anonymous TPCH Parquet data source is invalid.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.external_file_formats
    WHERE name = N'TPCHParquetFormat'
      AND format_type = N'PARQUET'
)
    THROW 50720, 'The TPCH Parquet file format is invalid.', 1;

SELECT
    DB_NAME() AS database_name,
    schema_name,
    internal_tables,
    external_tables,
    indexes,
    foreign_keys,
    untrusted_foreign_keys,
    disabled_foreign_keys
FROM #schema_summary
ORDER BY
    CASE schema_name
        WHEN N'dbo' THEN 1
        WHEN N'rs' THEN 2
        WHEN N'hp' THEN 3
        WHEN N'ext' THEN 4
    END;

SELECT
    schema_name,
    table_name,
    row_count,
    aggregate_checksum,
    N'MATCH' AS validation_status
FROM #data_comparison
ORDER BY table_name, schema_name;

SELECT
    table_name,
    expected_rows,
    external_rows,
    N'MATCH' AS validation_status
FROM #external_counts
ORDER BY table_name;
