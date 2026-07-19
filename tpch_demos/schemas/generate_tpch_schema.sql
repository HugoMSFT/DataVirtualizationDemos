SET NOCOUNT ON;

DECLARE
    @line_break nchar(2) = NCHAR(13) + NCHAR(10),
    @column_separator nvarchar(3) = N',' + NCHAR(13) + NCHAR(10),
    @table_filter sysname = NULLIF(N'$(TABLE_FILTER)', N'*'),
    @schema_filter sysname = NULLIF(N'$(SCHEMA_FILTER)', N'*'),
    @schema_mode nvarchar(10) = N'$(SCHEMA_MODE)',
    @script nvarchar(max),
    @schema_name sysname,
    @table_name sysname,
    @object_id int,
    @columns nvarchar(max),
    @statement nvarchar(max),
    @key_columns nvarchar(max),
    @included_columns nvarchar(max),
    @parent_columns nvarchar(max),
    @referenced_columns nvarchar(max);

IF @schema_mode NOT IN (N'full', N'table')
    THROW 50301, 'SCHEMA_MODE must be full or table.', 1;

IF @schema_filter IS NOT NULL
   AND @schema_filter NOT IN (N'dbo', N'rs', N'hp')
    THROW 50305, 'SCHEMA_FILTER must be dbo, rs, hp, or *.', 1;

IF @table_filter IS NOT NULL
   AND NOT EXISTS
   (
       SELECT 1
       FROM sys.tables
       WHERE name = @table_filter
         AND schema_id = SCHEMA_ID(N'dbo')
         AND is_ms_shipped = 0
   )
    THROW 50302, 'TABLE_FILTER does not identify a dbo table.', 1;

DECLARE @internal_schemas table
(
   schema_name sysname NOT NULL PRIMARY KEY
);

INSERT @internal_schemas (schema_name)
SELECT name
FROM sys.schemas
WHERE name IN (N'dbo', N'rs', N'hp')
  AND (@schema_filter IS NULL OR name = @schema_filter);

SET @script =
   N'-- Generated from ' + QUOTENAME(DB_NAME()) + N' on ' +
    CONVERT(nvarchar(30), SYSUTCDATETIME(), 126) + N'Z' + @line_break +
    N'-- Schema only; table data is stored in the adjacent Parquet files.' +
    @line_break +
    N'SET ANSI_NULLS ON;' + @line_break +
    N'SET QUOTED_IDENTIFIER ON;' + @line_break +
    N'SET XACT_ABORT ON;' + @line_break +
    N'GO' + @line_break + @line_break;

IF EXISTS (SELECT 1 FROM @internal_schemas WHERE schema_name = N'rs')
    SET @script +=
        N'IF SCHEMA_ID(N''rs'') IS NULL EXEC(N''CREATE SCHEMA [rs]'');' +
        @line_break + N'GO' + @line_break + @line_break;

IF EXISTS (SELECT 1 FROM @internal_schemas WHERE schema_name = N'hp')
    SET @script +=
        N'IF SCHEMA_ID(N''hp'') IS NULL EXEC(N''CREATE SCHEMA [hp]'');' +
        @line_break + N'GO' + @line_break + @line_break;

IF @schema_filter IS NULL AND SCHEMA_ID(N'ext') IS NOT NULL
    SET @script +=
        N'IF SCHEMA_ID(N''ext'') IS NULL EXEC(N''CREATE SCHEMA [ext]'');' +
        @line_break + N'GO' + @line_break + @line_break;

DECLARE table_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT
    s.name,
    t.name,
    t.object_id
FROM sys.tables AS t
JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
WHERE t.is_ms_shipped = 0
  AND t.is_external = 0
  AND EXISTS
      (SELECT 1 FROM @internal_schemas AS allowed
       WHERE allowed.schema_name = s.name)
  AND (@table_filter IS NULL OR t.name = @table_filter)
ORDER BY
    CASE t.name
        WHEN N'region' THEN 1
        WHEN N'nation' THEN 2
        WHEN N'supplier' THEN 3
        WHEN N'customer' THEN 4
        WHEN N'part' THEN 5
        WHEN N'partsupp' THEN 6
        WHEN N'orders' THEN 7
        WHEN N'lineitem' THEN 8
        ELSE 100
    END,
    t.name;

OPEN table_cursor;
FETCH NEXT FROM table_cursor
INTO @schema_name, @table_name, @object_id;

WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT @columns = STRING_AGG
    (
        CONVERT
        (
            nvarchar(max),
            N'    ' + QUOTENAME(c.name) + N' ' +
            CASE
                WHEN c.is_computed = 1 THEN
                    N'AS ' + cc.definition +
                    CASE WHEN cc.is_persisted = 1 THEN N' PERSISTED' ELSE N'' END
                ELSE
                    CASE WHEN ty.is_user_defined = 1
                         THEN QUOTENAME(SCHEMA_NAME(ty.schema_id)) + N'.'
                         ELSE N''
                    END + QUOTENAME(ty.name) +
                    CASE
                        WHEN ty.name IN
                            (N'char', N'varchar', N'binary', N'varbinary')
                            THEN N'(' +
                                CASE WHEN c.max_length = -1 THEN N'MAX'
                                     ELSE CONVERT(nvarchar(10), c.max_length)
                                END + N')'
                        WHEN ty.name IN (N'nchar', N'nvarchar')
                            THEN N'(' +
                                CASE WHEN c.max_length = -1 THEN N'MAX'
                                     ELSE CONVERT
                                          (nvarchar(10), c.max_length / 2)
                                END + N')'
                        WHEN ty.name IN (N'decimal', N'numeric')
                            THEN N'(' + CONVERT(nvarchar(10), c.precision) +
                                N',' + CONVERT(nvarchar(10), c.scale) + N')'
                        WHEN ty.name IN
                            (N'datetime2', N'datetimeoffset', N'time')
                            THEN N'(' + CONVERT(nvarchar(10), c.scale) + N')'
                        WHEN ty.name = N'float'
                            THEN N'(' + CONVERT(nvarchar(10), c.precision) + N')'
                        ELSE N''
                    END +
                    CASE
                        WHEN ic.object_id IS NOT NULL
                            THEN N' IDENTITY(' +
                                CONVERT(nvarchar(40), ic.seed_value) + N',' +
                                CONVERT(nvarchar(40), ic.increment_value) + N')'
                        ELSE N''
                    END +
                    CASE
                        WHEN dc.object_id IS NOT NULL
                            THEN N' CONSTRAINT ' + QUOTENAME(dc.name) +
                                N' DEFAULT ' + dc.definition
                        ELSE N''
                    END +
                    CASE WHEN c.is_nullable = 1
                         THEN N' NULL' ELSE N' NOT NULL' END
            END
        ),
        @column_separator
    ) WITHIN GROUP (ORDER BY c.column_id)
    FROM sys.columns AS c
    JOIN sys.types AS ty
        ON ty.user_type_id = c.user_type_id
    LEFT JOIN sys.computed_columns AS cc
        ON cc.object_id = c.object_id
       AND cc.column_id = c.column_id
    LEFT JOIN sys.identity_columns AS ic
        ON ic.object_id = c.object_id
       AND ic.column_id = c.column_id
    LEFT JOIN sys.default_constraints AS dc
        ON dc.parent_object_id = c.object_id
       AND dc.parent_column_id = c.column_id
    WHERE c.object_id = @object_id;

    SET @script +=
        N'CREATE TABLE ' + QUOTENAME(@schema_name) + N'.' +
        QUOTENAME(@table_name) + @line_break +
        N'(' + @line_break + @columns + @line_break + N');' + @line_break +
        N'GO' + @line_break + @line_break;

    FETCH NEXT FROM table_cursor
    INTO @schema_name, @table_name, @object_id;
END;

CLOSE table_cursor;
DEALLOCATE table_cursor;

DECLARE key_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT
    s.name,
    t.name,
    i.object_id,
    i.index_id,
    kc.name,
    kc.type,
    i.type_desc,
    i.fill_factor
FROM sys.key_constraints AS kc
JOIN sys.tables AS t
    ON t.object_id = kc.parent_object_id
JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
JOIN sys.indexes AS i
    ON i.object_id = kc.parent_object_id
   AND i.index_id = kc.unique_index_id
WHERE t.is_ms_shipped = 0
  AND t.is_external = 0
  AND EXISTS
      (SELECT 1 FROM @internal_schemas AS allowed
       WHERE allowed.schema_name = s.name)
  AND (@table_filter IS NULL OR t.name = @table_filter)
ORDER BY t.name, kc.name;

DECLARE
    @index_id int,
    @constraint_name sysname,
    @constraint_type char(2),
    @index_type nvarchar(60),
    @fill_factor tinyint;

OPEN key_cursor;
FETCH NEXT FROM key_cursor
INTO @schema_name, @table_name, @object_id, @index_id,
     @constraint_name, @constraint_type, @index_type, @fill_factor;

WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT @key_columns = STRING_AGG
    (
        CONVERT
        (
            nvarchar(max),
            QUOTENAME(c.name) +
            CASE WHEN ic.is_descending_key = 1 THEN N' DESC' ELSE N' ASC' END
        ),
        N', '
    ) WITHIN GROUP (ORDER BY ic.key_ordinal)
    FROM sys.index_columns AS ic
    JOIN sys.columns AS c
        ON c.object_id = ic.object_id
       AND c.column_id = ic.column_id
    WHERE ic.object_id = @object_id
      AND ic.index_id = @index_id
      AND ic.key_ordinal > 0;

    SET @script +=
        N'ALTER TABLE ' + QUOTENAME(@schema_name) + N'.' +
        QUOTENAME(@table_name) + N' ADD CONSTRAINT ' +
        QUOTENAME(@constraint_name) + N' ' +
        CASE @constraint_type WHEN N'PK' THEN N'PRIMARY KEY ' ELSE N'UNIQUE ' END +
        CASE @index_type WHEN N'CLUSTERED' THEN N'CLUSTERED ' ELSE N'NONCLUSTERED ' END +
        N'(' + @key_columns + N')' +
        CASE WHEN @fill_factor > 0
             THEN N' WITH (FILLFACTOR = ' +
                  CONVERT(nvarchar(3), @fill_factor) + N')'
             ELSE N''
        END + N';' + @line_break + N'GO' + @line_break + @line_break;

    FETCH NEXT FROM key_cursor
    INTO @schema_name, @table_name, @object_id, @index_id,
         @constraint_name, @constraint_type, @index_type, @fill_factor;
END;

CLOSE key_cursor;
DEALLOCATE key_cursor;

DECLARE index_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT
    s.name,
    t.name,
    i.object_id,
    i.index_id,
    i.name,
    i.type,
    i.type_desc,
    i.is_unique,
    i.fill_factor,
    i.has_filter,
    i.filter_definition
FROM sys.indexes AS i
JOIN sys.tables AS t
    ON t.object_id = i.object_id
JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
WHERE t.is_ms_shipped = 0
  AND t.is_external = 0
  AND EXISTS
      (SELECT 1 FROM @internal_schemas AS allowed
       WHERE allowed.schema_name = s.name)
  AND i.index_id > 0
  AND i.is_hypothetical = 0
  AND i.is_primary_key = 0
  AND i.is_unique_constraint = 0
  AND (@table_filter IS NULL OR t.name = @table_filter)
ORDER BY t.name, i.index_id;

DECLARE
    @index_name sysname,
    @index_type_id tinyint,
    @is_unique bit,
    @has_filter bit,
    @filter_definition nvarchar(max);

OPEN index_cursor;
FETCH NEXT FROM index_cursor
INTO @schema_name, @table_name, @object_id, @index_id, @index_name,
     @index_type_id, @index_type, @is_unique, @fill_factor,
     @has_filter, @filter_definition;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF @index_type_id = 5
    BEGIN
        SET @statement =
            N'CREATE CLUSTERED COLUMNSTORE INDEX ' + QUOTENAME(@index_name) +
            N' ON ' + QUOTENAME(@schema_name) + N'.' +
            QUOTENAME(@table_name) + N';';
    END
    ELSE
    BEGIN
        SELECT @key_columns = STRING_AGG
        (
            CONVERT
            (
                nvarchar(max),
                QUOTENAME(c.name) +
                CASE WHEN ic.is_descending_key = 1
                     THEN N' DESC' ELSE N' ASC' END
            ),
            N', '
        ) WITHIN GROUP (ORDER BY ic.key_ordinal)
        FROM sys.index_columns AS ic
        JOIN sys.columns AS c
            ON c.object_id = ic.object_id
           AND c.column_id = ic.column_id
        WHERE ic.object_id = @object_id
          AND ic.index_id = @index_id
          AND ic.key_ordinal > 0;

        SELECT @included_columns = STRING_AGG
        (
            CONVERT(nvarchar(max), QUOTENAME(c.name)),
            N', '
        ) WITHIN GROUP (ORDER BY ic.index_column_id)
        FROM sys.index_columns AS ic
        JOIN sys.columns AS c
            ON c.object_id = ic.object_id
           AND c.column_id = ic.column_id
        WHERE ic.object_id = @object_id
          AND ic.index_id = @index_id
          AND ic.is_included_column = 1;

        SET @statement =
            N'CREATE ' + CASE WHEN @is_unique = 1 THEN N'UNIQUE ' ELSE N'' END +
            CASE @index_type_id
                WHEN 1 THEN N'CLUSTERED '
                WHEN 2 THEN N'NONCLUSTERED '
            END +
            N'INDEX ' + QUOTENAME(@index_name) + N' ON ' +
            QUOTENAME(@schema_name) + N'.' + QUOTENAME(@table_name) +
            N' (' + @key_columns + N')' +
            CASE WHEN @included_columns IS NOT NULL
                 THEN N' INCLUDE (' + @included_columns + N')' ELSE N'' END +
            CASE WHEN @has_filter = 1
                 THEN N' WHERE ' + @filter_definition ELSE N'' END +
            CASE WHEN @fill_factor > 0
                 THEN N' WITH (FILLFACTOR = ' +
                      CONVERT(nvarchar(3), @fill_factor) + N')'
                 ELSE N''
            END + N';';
    END;

    SET @script += @statement + @line_break + N'GO' +
                   @line_break + @line_break;

    FETCH NEXT FROM index_cursor
    INTO @schema_name, @table_name, @object_id, @index_id, @index_name,
         @index_type_id, @index_type, @is_unique, @fill_factor,
         @has_filter, @filter_definition;
END;

CLOSE index_cursor;
DEALLOCATE index_cursor;

IF @schema_mode = N'full'
BEGIN
    DECLARE foreign_key_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        fk.name,
        parent_schema.name,
        parent_table.name,
        referenced_schema.name,
        referenced_table.name,
        fk.object_id,
        fk.is_not_trusted,
        fk.is_disabled,
        fk.delete_referential_action_desc,
        fk.update_referential_action_desc
    FROM sys.foreign_keys AS fk
    JOIN sys.tables AS parent_table
        ON parent_table.object_id = fk.parent_object_id
    JOIN sys.schemas AS parent_schema
        ON parent_schema.schema_id = parent_table.schema_id
    JOIN sys.tables AS referenced_table
        ON referenced_table.object_id = fk.referenced_object_id
    JOIN sys.schemas AS referenced_schema
        ON referenced_schema.schema_id = referenced_table.schema_id
    WHERE parent_table.is_ms_shipped = 0
    AND parent_table.is_external = 0
    AND referenced_table.is_external = 0
    AND EXISTS
        (SELECT 1 FROM @internal_schemas AS allowed
         WHERE allowed.schema_name = parent_schema.name)
    ORDER BY parent_table.name, fk.name;

    DECLARE
        @foreign_key_name sysname,
        @parent_schema sysname,
        @parent_table sysname,
        @referenced_schema sysname,
        @referenced_table sysname,
        @foreign_key_id int,
        @is_not_trusted bit,
        @is_disabled bit,
        @delete_action nvarchar(60),
        @update_action nvarchar(60);

    OPEN foreign_key_cursor;
    FETCH NEXT FROM foreign_key_cursor
    INTO @foreign_key_name, @parent_schema, @parent_table,
         @referenced_schema, @referenced_table, @foreign_key_id,
         @is_not_trusted, @is_disabled, @delete_action, @update_action;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT
            @parent_columns = STRING_AGG
            (
                CONVERT(nvarchar(max), QUOTENAME(parent_column.name)),
                N', '
            ) WITHIN GROUP (ORDER BY fkc.constraint_column_id),
            @referenced_columns = STRING_AGG
            (
                CONVERT(nvarchar(max), QUOTENAME(referenced_column.name)),
                N', '
            ) WITHIN GROUP (ORDER BY fkc.constraint_column_id)
        FROM sys.foreign_key_columns AS fkc
        JOIN sys.columns AS parent_column
            ON parent_column.object_id = fkc.parent_object_id
           AND parent_column.column_id = fkc.parent_column_id
        JOIN sys.columns AS referenced_column
            ON referenced_column.object_id = fkc.referenced_object_id
           AND referenced_column.column_id = fkc.referenced_column_id
        WHERE fkc.constraint_object_id = @foreign_key_id;

        SET @script +=
            N'ALTER TABLE ' + QUOTENAME(@parent_schema) + N'.' +
            QUOTENAME(@parent_table) +
            CASE WHEN @is_not_trusted = 1
                 THEN N' WITH NOCHECK' ELSE N' WITH CHECK' END +
            N' ADD CONSTRAINT ' + QUOTENAME(@foreign_key_name) +
            N' FOREIGN KEY (' + @parent_columns + N') REFERENCES ' +
            QUOTENAME(@referenced_schema) + N'.' +
            QUOTENAME(@referenced_table) + N' (' +
            @referenced_columns + N')' +
            CASE WHEN @delete_action <> N'NO_ACTION'
                 THEN N' ON DELETE ' + REPLACE(@delete_action, N'_', N' ')
                 ELSE N''
            END +
            CASE WHEN @update_action <> N'NO_ACTION'
                 THEN N' ON UPDATE ' + REPLACE(@update_action, N'_', N' ')
                 ELSE N''
            END + N';' + @line_break + N'GO' + @line_break +
            N'ALTER TABLE ' + QUOTENAME(@parent_schema) + N'.' +
            QUOTENAME(@parent_table) +
            CASE WHEN @is_disabled = 1 THEN N' NOCHECK' ELSE N' CHECK' END +
            N' CONSTRAINT ' + QUOTENAME(@foreign_key_name) + N';' +
            @line_break + N'GO' + @line_break + @line_break;

        FETCH NEXT FROM foreign_key_cursor
        INTO @foreign_key_name, @parent_schema, @parent_table,
             @referenced_schema, @referenced_table, @foreign_key_id,
             @is_not_trusted, @is_disabled, @delete_action, @update_action;
    END;

    CLOSE foreign_key_cursor;
    DEALLOCATE foreign_key_cursor;
END;

IF @schema_mode = N'full'
   AND @schema_filter IS NULL
   AND EXISTS
       (SELECT 1
        FROM sys.external_tables AS et
        JOIN sys.schemas AS s
          ON s.schema_id = et.schema_id
        WHERE s.name = N'ext')
BEGIN
    DECLARE
        @data_source_name sysname,
        @data_source_location nvarchar(4000),
        @file_format_name sysname,
        @external_location nvarchar(4000);

    IF
    (
        SELECT COUNT(DISTINCT et.data_source_id)
        FROM sys.external_tables AS et
        JOIN sys.schemas AS s
          ON s.schema_id = et.schema_id
        WHERE s.name = N'ext'
    ) <> 1
        THROW 50303, 'Expected one external data source for ext.', 1;

    IF
    (
        SELECT COUNT(DISTINCT et.file_format_id)
        FROM sys.external_tables AS et
        JOIN sys.schemas AS s
          ON s.schema_id = et.schema_id
        WHERE s.name = N'ext'
    ) <> 1
        THROW 50304, 'Expected one external file format for ext.', 1;

    SELECT TOP (1)
        @data_source_name = eds.name,
        @data_source_location = eds.location,
        @file_format_name = eff.name
    FROM sys.external_tables AS et
    JOIN sys.schemas AS s
      ON s.schema_id = et.schema_id
    JOIN sys.external_data_sources AS eds
      ON eds.data_source_id = et.data_source_id
    JOIN sys.external_file_formats AS eff
      ON eff.file_format_id = et.file_format_id
    WHERE s.name = N'ext';

    SET @script +=
        N'CREATE EXTERNAL DATA SOURCE ' + QUOTENAME(@data_source_name) +
        @line_break + N'WITH' + @line_break + N'(' + @line_break +
        N'    LOCATION = N''' +
        REPLACE(@data_source_location, N'''', N'''''') + N'''' +
        @line_break + N');' + @line_break + N'GO' + @line_break +
        @line_break +
        N'CREATE EXTERNAL FILE FORMAT ' + QUOTENAME(@file_format_name) +
        @line_break + N'WITH' + @line_break + N'(' + @line_break +
        N'    FORMAT_TYPE = PARQUET' + @line_break + N');' +
        @line_break + N'GO' + @line_break + @line_break;

    DECLARE external_table_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        s.name,
        et.name,
        et.object_id,
        et.location
    FROM sys.external_tables AS et
    JOIN sys.schemas AS s
      ON s.schema_id = et.schema_id
    WHERE s.name = N'ext'
    ORDER BY
        CASE et.name
            WHEN N'region' THEN 1
            WHEN N'nation' THEN 2
            WHEN N'supplier' THEN 3
            WHEN N'customer' THEN 4
            WHEN N'part' THEN 5
            WHEN N'partsupp' THEN 6
            WHEN N'orders' THEN 7
            WHEN N'lineitem' THEN 8
            ELSE 100
        END,
        et.name;

    OPEN external_table_cursor;
    FETCH NEXT FROM external_table_cursor
    INTO @schema_name, @table_name, @object_id, @external_location;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT @columns = STRING_AGG
        (
            CONVERT
            (
                nvarchar(max),
                N'    ' + QUOTENAME(c.name) + N' ' +
                CASE WHEN ty.is_user_defined = 1
                     THEN QUOTENAME(SCHEMA_NAME(ty.schema_id)) + N'.'
                     ELSE N''
                END + QUOTENAME(ty.name) +
                CASE
                    WHEN ty.name IN
                        (N'char', N'varchar', N'binary', N'varbinary')
                        THEN N'(' +
                            CASE WHEN c.max_length = -1 THEN N'MAX'
                                 ELSE CONVERT(nvarchar(10), c.max_length)
                            END + N')'
                    WHEN ty.name IN (N'nchar', N'nvarchar')
                        THEN N'(' +
                            CASE WHEN c.max_length = -1 THEN N'MAX'
                                 ELSE CONVERT(nvarchar(10), c.max_length / 2)
                            END + N')'
                    WHEN ty.name IN (N'decimal', N'numeric')
                        THEN N'(' + CONVERT(nvarchar(10), c.precision) +
                            N',' + CONVERT(nvarchar(10), c.scale) + N')'
                    WHEN ty.name IN
                        (N'datetime2', N'datetimeoffset', N'time')
                        THEN N'(' + CONVERT(nvarchar(10), c.scale) + N')'
                    WHEN ty.name = N'float'
                        THEN N'(' + CONVERT(nvarchar(10), c.precision) + N')'
                    ELSE N''
                END +
                CASE WHEN c.is_nullable = 1
                     THEN N' NULL' ELSE N' NOT NULL' END
            ),
            @column_separator
        ) WITHIN GROUP (ORDER BY c.column_id)
        FROM sys.columns AS c
        JOIN sys.types AS ty
          ON ty.user_type_id = c.user_type_id
        WHERE c.object_id = @object_id;

        SET @script +=
            N'CREATE EXTERNAL TABLE ' + QUOTENAME(@schema_name) + N'.' +
            QUOTENAME(@table_name) + @line_break + N'(' + @line_break +
            @columns + @line_break + N')' + @line_break + N'WITH' +
            @line_break + N'(' + @line_break + N'    LOCATION = N''' +
            REPLACE(@external_location, N'''', N'''''') + N''',' +
            @line_break + N'    DATA_SOURCE = ' +
            QUOTENAME(@data_source_name) + N',' + @line_break +
            N'    FILE_FORMAT = ' + QUOTENAME(@file_format_name) +
            @line_break + N');' + @line_break + N'GO' + @line_break +
            @line_break;

        FETCH NEXT FROM external_table_cursor
        INTO @schema_name, @table_name, @object_id, @external_location;
    END;

    CLOSE external_table_cursor;
    DEALLOCATE external_table_cursor;
END;

SELECT REPLACE(value, NCHAR(13), N'')
FROM STRING_SPLIT(@script, NCHAR(10), 1)
ORDER BY ordinal;
