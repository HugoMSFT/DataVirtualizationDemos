-- =============================================================================
-- Hidden Gems 03: Approximate analytics and per-file quality scoring
-- Platform: Azure SQL Database data virtualization (Preview)
-- Data: NYC Yellow Taxi Azure Open Dataset
-- =============================================================================
-- APPROX_PERCENTILE_CONT uses a bounded-error sketch instead of an exact sort.
-- It is a strong fit for large external rowsets where a p50/p95 estimate is
-- more useful than paying for an exact percentile.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Median and p95 metrics over three pruned monthly partitions.
--    A long result shape keeps all ordered aggregates on one compatible
--    ORDER BY expression while still calculating several business measures.
--    The value caps intentionally remove extreme/outlier records.
-- -----------------------------------------------------------------------------
WITH BaseRows AS
(
    SELECT
        TRY_CONVERT(TINYINT, src.filepath(2)) AS pickup_month,
        src.tpepPickupDateTime,
        src.tpepDropoffDateTime,
        src.tripDistance,
        src.totalAmount
    FROM OPENROWSET(
        BULK 'abs://nyctlc@azureopendatastorage.blob.core.windows.net/yellow/puYear=*/puMonth=*/*.parquet',
        FORMAT = 'PARQUET'
    )
    WITH (
        tpepPickupDateTime  DATETIME2(7),
        tpepDropoffDateTime DATETIME2(7),
        tripDistance        FLOAT,
        totalAmount         FLOAT
    ) AS src
    WHERE src.filepath(1) = '2017'
      AND src.filepath(2) IN ('10', '11', '12')
      AND src.totalAmount BETWEEN 0 AND 500
      AND src.tripDistance BETWEEN 0 AND 100
      AND src.tpepDropoffDateTime >= src.tpepPickupDateTime
),
MetricRows AS
(
    SELECT
        b.pickup_month,
        metric.metric_name,
        metric.metric_value
    FROM BaseRows AS b
    CROSS APPLY (
        VALUES
            (N'total_amount_usd', b.totalAmount),
            (N'trip_distance_miles', b.tripDistance),
            (
                N'trip_duration_seconds',
                CONVERT(
                    FLOAT,
                    DATEDIFF_BIG(
                        SECOND,
                        b.tpepPickupDateTime,
                        b.tpepDropoffDateTime
                    )
                )
            )
    ) AS metric(metric_name, metric_value)
)
SELECT
    pickup_month,
    metric_name,
    COUNT_BIG(*) AS observations,
    APPROX_PERCENTILE_CONT(0.50)
        WITHIN GROUP (ORDER BY metric_value) AS approximate_p50,
    APPROX_PERCENTILE_CONT(0.95)
        WITHIN GROUP (ORDER BY metric_value) AS approximate_p95
FROM MetricRows
GROUP BY pickup_month, metric_name
ORDER BY pickup_month, metric_name;
GO

-- Approximate cardinality is another low-memory option for large file scans.
SELECT
    TRY_CONVERT(TINYINT, src.filepath(2)) AS pickup_month,
    COUNT_BIG(*) AS rides,
    APPROX_COUNT_DISTINCT(src.puLocationId) AS approximate_pickup_zones
FROM OPENROWSET(
    BULK 'abs://nyctlc@azureopendatastorage.blob.core.windows.net/yellow/puYear=*/puMonth=*/*.parquet',
    FORMAT = 'PARQUET'
)
WITH (
    puLocationId VARCHAR(50)
) AS src
WHERE src.filepath(1) = '2017'
  AND src.filepath(2) IN ('10', '11', '12')
GROUP BY src.filepath(2)
ORDER BY pickup_month;
GO

-- -----------------------------------------------------------------------------
-- 2. Treat each Parquet file as a quality domain and rank suspicious files.
--    The lineage columns come from storage metadata, not the physical schema.
-- -----------------------------------------------------------------------------
WITH SourceRows AS
(
    SELECT
        CONVERT(NVARCHAR(1024), src.filepath()) AS source_path,
        CONVERT(NVARCHAR(260), src.filename()) AS source_file,
        src.tpepPickupDateTime,
        src.tpepDropoffDateTime,
        src.passengerCount,
        src.tripDistance,
        src.fareAmount,
        src.totalAmount
    FROM OPENROWSET(
        BULK 'abs://nyctlc@azureopendatastorage.blob.core.windows.net/yellow/puYear=*/puMonth=*/*.parquet',
        FORMAT = 'PARQUET'
    )
    WITH (
        tpepPickupDateTime  DATETIME2(7),
        tpepDropoffDateTime DATETIME2(7),
        passengerCount      INT,
        tripDistance        FLOAT,
        fareAmount          FLOAT,
        totalAmount         FLOAT
    ) AS src
    WHERE src.filepath(1) = '2018'
      AND src.filepath(2) = '6'
),
FileQuality AS
(
    SELECT
        source_path,
        source_file,
        COUNT_BIG(*) AS row_count,
        SUM(CONVERT(BIGINT, CASE WHEN fareAmount < 0 THEN 1 ELSE 0 END)) AS negative_fares,
        SUM(CONVERT(BIGINT, CASE WHEN totalAmount < fareAmount THEN 1 ELSE 0 END)) AS bad_totals,
        SUM(CONVERT(BIGINT, CASE WHEN tripDistance < 0 THEN 1 ELSE 0 END)) AS negative_distance,
        SUM(CONVERT(BIGINT, CASE WHEN passengerCount < 0 OR passengerCount > 8 THEN 1 ELSE 0 END)) AS odd_passenger_counts,
        SUM(CONVERT(BIGINT, CASE WHEN tpepDropoffDateTime < tpepPickupDateTime THEN 1 ELSE 0 END)) AS reversed_timestamps,
        SUM(CONVERT(BIGINT, CASE
            WHEN fareAmount < 0
              OR totalAmount < fareAmount
              OR tripDistance < 0
              OR passengerCount < 0
              OR passengerCount > 8
              OR tpepDropoffDateTime < tpepPickupDateTime
            THEN 1 ELSE 0
        END)) AS rows_with_issues
    FROM SourceRows
    GROUP BY source_path, source_file
)
SELECT
    source_path,
    source_file,
    row_count,
    negative_fares,
    bad_totals,
    negative_distance,
    odd_passenger_counts,
    reversed_timestamps,
    rows_with_issues,
    CONVERT(
        DECIMAL(9, 4),
        100.0 * rows_with_issues / NULLIF(row_count, 0)
    ) AS issue_percentage
FROM FileQuality
ORDER BY issue_percentage DESC, source_file;
GO
