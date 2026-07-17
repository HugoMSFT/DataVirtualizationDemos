-- =============================================================================
-- Hidden Gems 02: Join two data lakes without ingesting either one
-- Platform: Azure SQL Database data virtualization (Preview)
-- Data: NYC Yellow Taxi + Public Holidays Azure Open Datasets
-- =============================================================================
-- The taxi scan is restricted to two folder partitions with filepath().
-- Holiday rows are collapsed to one row per date before the join so a date with
-- multiple holiday labels cannot multiply the taxi aggregates.
-- The 0-500 total cap intentionally excludes extreme/outlier transactions, so
-- gross_revenue is the total for the cleaned analytical subset, not all rides.
-- =============================================================================

WITH TaxiRows AS
(
    SELECT
        CONVERT(DATE, src.tpepPickupDateTime) AS ride_date,
        src.tripDistance,
        src.tipAmount,
        src.totalAmount
    FROM OPENROWSET(
        BULK 'abs://nyctlc@azureopendatastorage.blob.core.windows.net/yellow/puYear=*/puMonth=*/*.parquet',
        FORMAT = 'PARQUET'
    )
    WITH (
        tpepPickupDateTime DATETIME2(7),
        tripDistance       FLOAT,
        tipAmount          FLOAT,
        totalAmount        FLOAT
    ) AS src
    WHERE src.filepath(1) = '2018'
      AND src.filepath(2) IN ('11', '12')
      AND src.totalAmount BETWEEN 0 AND 500
),
TaxiDaily AS
(
    SELECT
        ride_date,
        COUNT_BIG(*) AS rides,
        SUM(totalAmount) AS gross_revenue,
        AVG(totalAmount) AS average_total,
        AVG(tripDistance) AS average_miles,
        AVG(CASE
                WHEN totalAmount > 0
                THEN 100.0 * tipAmount / totalAmount
            END) AS average_tip_pct
    FROM TaxiRows
    GROUP BY ride_date
),
USHolidays AS
(
    SELECT
        CONVERT(DATE, src.[date]) AS holiday_date,
        STRING_AGG(CONVERT(VARCHAR(MAX), src.holidayName), ', ') AS holiday_names
    FROM OPENROWSET(
        BULK 'abs://holidaydatacontainer@azureopendatastorage.blob.core.windows.net/Processed/*.parquet',
        FORMAT = 'PARQUET'
    )
    WITH (
        holidayName       VARCHAR(512),
        countryRegionCode VARCHAR(10),
        [date]            DATETIME2(7)
    ) AS src
    WHERE src.countryRegionCode = 'US'
      AND src.[date] >= '2018-11-01'
      AND src.[date] <  '2019-01-01'
    GROUP BY CONVERT(DATE, src.[date])
)
SELECT
    t.ride_date,
    DATENAME(WEEKDAY, t.ride_date) AS weekday_name,
    COALESCE(h.holiday_names, '(regular day)') AS day_type,
    t.rides,
    CONVERT(DECIMAL(14, 2), t.gross_revenue) AS gross_revenue,
    CONVERT(DECIMAL(10, 2), t.average_total) AS average_total,
    CONVERT(DECIMAL(10, 2), t.average_miles) AS average_miles,
    CONVERT(DECIMAL(10, 2), t.average_tip_pct) AS average_tip_pct
FROM TaxiDaily AS t
LEFT JOIN USHolidays AS h
    ON h.holiday_date = t.ride_date
ORDER BY t.ride_date;
GO
