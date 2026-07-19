/*
Run in SQLCMD mode and supply:
  TARGET_SCHEMA = dbo, rs, or ext
  ITERATION     = positive integer

The workload reads source tables only. It writes timing rows to a temporary
table so the measured query results are not dominated by client/network output.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET DEADLOCK_PRIORITY LOW;

DECLARE
    @target_schema sysname = N'$(TARGET_SCHEMA)',
    @iteration int = TRY_CONVERT(int, N'$(ITERATION)'),
    @sql nvarchar(max),
    @started_at datetime2(7),
    @finished_at datetime2(7),
    @result_rows bigint,
    @result_checksum int;

IF @target_schema NOT IN (N'dbo', N'rs', N'ext')
    THROW 50601, 'TARGET_SCHEMA must be dbo, rs, or ext.', 1;

IF @iteration IS NULL OR @iteration < 1
    THROW 50602, 'ITERATION must be a positive integer.', 1;

IF @target_schema = N'ext'
BEGIN
    IF
    (
        SELECT COUNT(*)
        FROM sys.external_tables AS t
        JOIN sys.schemas AS s
            ON s.schema_id = t.schema_id
        WHERE s.name = @target_schema
    ) <> 8
        THROW 50603, 'Expected eight external tables in ext.', 1;
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
        THROW 50604, 'Expected eight internal tables in the target schema.', 1;
END;

CREATE TABLE #workload_results
(
    query_id tinyint NOT NULL PRIMARY KEY,
    query_name varchar(80) NOT NULL,
    started_at_utc datetime2(7) NOT NULL,
    finished_at_utc datetime2(7) NOT NULL,
    duration_us bigint NOT NULL,
    result_rows bigint NULL,
    result_checksum int NULL
);

/* Q1: Scan the lineitem fact table and summarize shipping behavior. */
SET @sql = N'
WITH shipping_summary AS
(
    SELECT
        l_shipmode,
        l_returnflag,
        COUNT_BIG(*) AS shipment_count,
        SUM(CONVERT(decimal(38, 2), l_quantity)) AS total_quantity,
        SUM
        (
            CONVERT
            (
                decimal(38, 4),
                l_extendedprice * (CONVERT(decimal(12, 2), 1) - l_discount)
            )
        ) AS net_revenue
    FROM ' + QUOTENAME(@target_schema) + N'.lineitem
    WHERE l_shipdate >= CONVERT(date, ''1995-01-01'')
      AND l_shipdate <  CONVERT(date, ''1997-01-01'')
    GROUP BY l_shipmode, l_returnflag
)
SELECT
    @rows = COUNT_BIG(*),
    @checksum = CHECKSUM_AGG
    (
        BINARY_CHECKSUM
        (
            l_shipmode,
            l_returnflag,
            shipment_count,
            total_quantity,
            net_revenue
        )
    )
FROM shipping_summary
OPTION (MAXDOP 4);';

SET @result_rows = NULL;
SET @result_checksum = NULL;
SET @started_at = SYSUTCDATETIME();
EXEC sys.sp_executesql
    @sql,
    N'@rows bigint OUTPUT, @checksum int OUTPUT',
    @rows = @result_rows OUTPUT,
    @checksum = @result_checksum OUTPUT;
SET @finished_at = SYSUTCDATETIME();

INSERT #workload_results
VALUES
(
    1,
    'shipping-mode summary',
    @started_at,
    @finished_at,
    DATEDIFF_BIG(microsecond, @started_at, @finished_at),
    @result_rows,
    @result_checksum
);

/* Q2: Aggregate order value by month, status, and customer segment. */
SET @sql = N'
WITH monthly_orders AS
(
    SELECT
        DATEFROMPARTS(YEAR(o.o_orderdate), MONTH(o.o_orderdate), 1) AS order_month,
        o.o_orderstatus,
        c.c_mktsegment,
        COUNT_BIG(*) AS order_count,
        SUM(CONVERT(decimal(38, 2), o.o_totalprice)) AS gross_order_value
    FROM ' + QUOTENAME(@target_schema) + N'.orders AS o
    JOIN ' + QUOTENAME(@target_schema) + N'.customer AS c
      ON c.c_custkey = o.o_custkey
    WHERE o.o_orderdate >= CONVERT(date, ''1995-01-01'')
      AND o.o_orderdate <  CONVERT(date, ''1997-01-01'')
    GROUP BY
        DATEFROMPARTS(YEAR(o.o_orderdate), MONTH(o.o_orderdate), 1),
        o.o_orderstatus,
        c.c_mktsegment
)
SELECT
    @rows = COUNT_BIG(*),
    @checksum = CHECKSUM_AGG
    (
        BINARY_CHECKSUM
        (
            order_month,
            o_orderstatus,
            c_mktsegment,
            order_count,
            gross_order_value
        )
    )
FROM monthly_orders
OPTION (MAXDOP 4);';

SET @result_rows = NULL;
SET @result_checksum = NULL;
SET @started_at = SYSUTCDATETIME();
EXEC sys.sp_executesql
    @sql,
    N'@rows bigint OUTPUT, @checksum int OUTPUT',
    @rows = @result_rows OUTPUT,
    @checksum = @result_checksum OUTPUT;
SET @finished_at = SYSUTCDATETIME();

INSERT #workload_results
VALUES
(
    2,
    'monthly customer-segment orders',
    @started_at,
    @finished_at,
    DATEDIFF_BIG(microsecond, @started_at, @finished_at),
    @result_rows,
    @result_checksum
);

/* Q3: Join the sales fact path and report realized regional revenue. */
SET @sql = N'
WITH regional_revenue AS
(
    SELECT
        r.r_name,
        o.o_orderpriority,
        COUNT_BIG(*) AS line_count,
        SUM
        (
            CONVERT
            (
                decimal(38, 4),
                l.l_extendedprice *
                    (CONVERT(decimal(12, 2), 1) - l.l_discount)
            )
        ) AS realized_revenue
    FROM ' + QUOTENAME(@target_schema) + N'.lineitem AS l
    JOIN ' + QUOTENAME(@target_schema) + N'.orders AS o
      ON o.o_orderkey = l.l_orderkey
    JOIN ' + QUOTENAME(@target_schema) + N'.customer AS c
      ON c.c_custkey = o.o_custkey
    JOIN ' + QUOTENAME(@target_schema) + N'.nation AS n
      ON n.n_nationkey = c.c_nationkey
    JOIN ' + QUOTENAME(@target_schema) + N'.region AS r
      ON r.r_regionkey = n.n_regionkey
    WHERE o.o_orderdate >= CONVERT(date, ''1996-01-01'')
      AND o.o_orderdate <  CONVERT(date, ''1997-01-01'')
    GROUP BY r.r_name, o.o_orderpriority
)
SELECT
    @rows = COUNT_BIG(*),
    @checksum = CHECKSUM_AGG
    (
        BINARY_CHECKSUM
        (
            r_name,
            o_orderpriority,
            line_count,
            realized_revenue
        )
    )
FROM regional_revenue
OPTION (MAXDOP 4);';

SET @result_rows = NULL;
SET @result_checksum = NULL;
SET @started_at = SYSUTCDATETIME();
EXEC sys.sp_executesql
    @sql,
    N'@rows bigint OUTPUT, @checksum int OUTPUT',
    @rows = @result_rows OUTPUT,
    @checksum = @result_checksum OUTPUT;
SET @finished_at = SYSUTCDATETIME();

INSERT #workload_results
VALUES
(
    3,
    'regional realized revenue',
    @started_at,
    @finished_at,
    DATEDIFF_BIG(microsecond, @started_at, @finished_at),
    @result_rows,
    @result_checksum
);

/* Q4: Analyze supplier inventory value for a selective part segment. */
SET @sql = N'
WITH inventory_value AS
(
    SELECT
        n.n_name,
        p.p_mfgr,
        COUNT_BIG(*) AS supplier_part_count,
        SUM
        (
            CONVERT
            (
                decimal(38, 2),
                ps.ps_availqty * ps.ps_supplycost
            )
        ) AS available_inventory_value
    FROM ' + QUOTENAME(@target_schema) + N'.partsupp AS ps
    JOIN ' + QUOTENAME(@target_schema) + N'.supplier AS s
      ON s.s_suppkey = ps.ps_suppkey
    JOIN ' + QUOTENAME(@target_schema) + N'.nation AS n
      ON n.n_nationkey = s.s_nationkey
    JOIN ' + QUOTENAME(@target_schema) + N'.part AS p
      ON p.p_partkey = ps.ps_partkey
    WHERE p.p_size BETWEEN 5 AND 15
      AND p.p_type LIKE ''%COPPER%''
    GROUP BY n.n_name, p.p_mfgr
)
SELECT
    @rows = COUNT_BIG(*),
    @checksum = CHECKSUM_AGG
    (
        BINARY_CHECKSUM
        (
            n_name,
            p_mfgr,
            supplier_part_count,
            available_inventory_value
        )
    )
FROM inventory_value
OPTION (MAXDOP 4);';

SET @result_rows = NULL;
SET @result_checksum = NULL;
SET @started_at = SYSUTCDATETIME();
EXEC sys.sp_executesql
    @sql,
    N'@rows bigint OUTPUT, @checksum int OUTPUT',
    @rows = @result_rows OUTPUT,
    @checksum = @result_checksum OUTPUT;
SET @finished_at = SYSUTCDATETIME();

INSERT #workload_results
VALUES
(
    4,
    'supplier inventory value',
    @started_at,
    @finished_at,
    DATEDIFF_BIG(microsecond, @started_at, @finished_at),
    @result_rows,
    @result_checksum
);

/* Q5: Measure late-delivery behavior by priority and ship mode. */
SET @sql = N'
WITH late_delivery AS
(
    SELECT
        o.o_orderpriority,
        l.l_shipmode,
        COUNT_BIG(*) AS late_line_count,
        AVG
        (
            CONVERT
            (
                decimal(18, 2),
                DATEDIFF(day, l.l_commitdate, l.l_receiptdate)
            )
        ) AS average_days_late
    FROM ' + QUOTENAME(@target_schema) + N'.lineitem AS l
    JOIN ' + QUOTENAME(@target_schema) + N'.orders AS o
      ON o.o_orderkey = l.l_orderkey
    WHERE o.o_orderdate >= CONVERT(date, ''1997-01-01'')
      AND o.o_orderdate <  CONVERT(date, ''1998-01-01'')
      AND l.l_receiptdate > l.l_commitdate
    GROUP BY o.o_orderpriority, l.l_shipmode
)
SELECT
    @rows = COUNT_BIG(*),
    @checksum = CHECKSUM_AGG
    (
        BINARY_CHECKSUM
        (
            o_orderpriority,
            l_shipmode,
            late_line_count,
            average_days_late
        )
    )
FROM late_delivery
OPTION (MAXDOP 4);';

SET @result_rows = NULL;
SET @result_checksum = NULL;
SET @started_at = SYSUTCDATETIME();
EXEC sys.sp_executesql
    @sql,
    N'@rows bigint OUTPUT, @checksum int OUTPUT',
    @rows = @result_rows OUTPUT,
    @checksum = @result_checksum OUTPUT;
SET @finished_at = SYSUTCDATETIME();

INSERT #workload_results
VALUES
(
    5,
    'late-delivery analysis',
    @started_at,
    @finished_at,
    DATEDIFF_BIG(microsecond, @started_at, @finished_at),
    @result_rows,
    @result_checksum
);

SELECT
    DB_NAME() AS database_name,
    @target_schema AS target_schema,
    @iteration AS iteration,
    CONVERT(int, query_id) AS query_id,
    query_name,
    CAST(duration_us / 1000.0 AS decimal(18, 3)) AS duration_ms,
    result_rows,
    result_checksum
FROM #workload_results

UNION ALL

SELECT
    DB_NAME(),
    @target_schema,
    @iteration,
    99,
    'TOTAL',
    CAST(SUM(duration_us) / 1000.0 AS decimal(18, 3)),
    NULL,
    NULL
FROM #workload_results
ORDER BY query_id;
