SET NOCOUNT ON;

IF
(
    SELECT COUNT(*)
    FROM sys.external_tables AS et
    JOIN sys.schemas AS s
        ON s.schema_id = et.schema_id
    WHERE s.name = N'$(TARGET_SCHEMA)'
) <> 8
    THROW 50421, 'Expected eight external tables in the target schema.', 1;

CREATE TABLE #row_counts
(
    table_name sysname NOT NULL,
    expected_rows bigint NOT NULL,
    external_rows bigint NOT NULL
);

INSERT #row_counts
VALUES
    (N'customer', 1500000,
     (SELECT COUNT_BIG(*) FROM [$(TARGET_SCHEMA)].[customer])),
    (N'lineitem', 59999496,
     (SELECT COUNT_BIG(*) FROM [$(TARGET_SCHEMA)].[lineitem])),
    (N'nation', 25,
     (SELECT COUNT_BIG(*) FROM [$(TARGET_SCHEMA)].[nation])),
    (N'orders', 15000000,
     (SELECT COUNT_BIG(*) FROM [$(TARGET_SCHEMA)].[orders])),
    (N'part', 2000000,
     (SELECT COUNT_BIG(*) FROM [$(TARGET_SCHEMA)].[part])),
    (N'partsupp', 8000000,
     (SELECT COUNT_BIG(*) FROM [$(TARGET_SCHEMA)].[partsupp])),
    (N'region', 5,
     (SELECT COUNT_BIG(*) FROM [$(TARGET_SCHEMA)].[region])),
    (N'supplier', 100000,
     (SELECT COUNT_BIG(*) FROM [$(TARGET_SCHEMA)].[supplier]));

SELECT
    DB_NAME() AS database_name,
    N'$(TARGET_SCHEMA)' AS external_schema,
    table_name,
    expected_rows,
    external_rows,
    CASE WHEN expected_rows = external_rows
         THEN N'MATCH' ELSE N'MISMATCH' END AS validation_status
FROM #row_counts
ORDER BY table_name;

IF EXISTS
(
    SELECT 1
    FROM #row_counts
    WHERE expected_rows <> external_rows
)
    THROW 50422, 'External table row counts differ from the exported folders.', 1;
GO
