-- =============================================================================
-- Hidden Gems 04: Dense time series and geospatial analysis over Parquet
-- Platform: Azure SQL Database data virtualization (Preview)
-- Data: Boston 311 Safety + Public Holidays Azure Open Datasets
-- =============================================================================
-- GENERATE_SERIES supplies missing dates, DATE_BUCKET aligns event timestamps,
-- and geography methods operate directly on latitude/longitude read from Parquet.
-- GENERATE_SERIES requires database compatibility level 160 or later.
-- Boston Safety has a flat file layout, so date predicates do not perform folder
-- elimination; each query scans the roughly 90 MB source. This is intentional.
-- =============================================================================

IF (SELECT compatibility_level
    FROM sys.databases
    WHERE database_id = DB_ID()) < 160
BEGIN
    THROW 50001, 'This demo requires compatibility level 160 for GENERATE_SERIES.', 1;
END;
GO

DECLARE @StartDate DATE = '2021-07-01';
DECLARE @EndDate   DATE = '2021-07-10';

WITH DateSpine AS
(
    SELECT DATEADD(DAY, value, @StartDate) AS calendar_date
    FROM GENERATE_SERIES(0, DATEDIFF(DAY, @StartDate, @EndDate))
),
IncidentDaily AS
(
    SELECT
        CONVERT(DATE, DATE_BUCKET(DAY, 1, src.dateTime)) AS incident_date,
        COUNT_BIG(*) AS incidents,
        SUM(CONVERT(BIGINT, CASE
            WHEN src.category LIKE 'Noise%'
            THEN 1 ELSE 0
        END)) AS noise_incidents
    FROM OPENROWSET(
        BULK 'abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=Boston/*.parquet',
        FORMAT = 'PARQUET'
    )
    WITH (
        dateTime DATETIME2(7),
        category VARCHAR(256)
    ) AS src
    WHERE src.dateTime >= @StartDate
      AND src.dateTime < DATEADD(DAY, 1, @EndDate)
    GROUP BY CONVERT(DATE, DATE_BUCKET(DAY, 1, src.dateTime))
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
      AND src.[date] >= @StartDate
      AND src.[date] < DATEADD(DAY, 1, @EndDate)
    GROUP BY CONVERT(DATE, src.[date])
)
SELECT
    d.calendar_date,
    DATENAME(WEEKDAY, d.calendar_date) AS weekday_name,
    COALESCE(h.holiday_names, '(regular day)') AS holiday_name,
    COALESCE(i.incidents, 0) AS incidents,
    COALESCE(i.noise_incidents, 0) AS noise_incidents
FROM DateSpine AS d
LEFT JOIN IncidentDaily AS i
    ON i.incident_date = d.calendar_date
LEFT JOIN USHolidays AS h
    ON h.holiday_date = d.calendar_date
ORDER BY d.calendar_date;
GO

-- -----------------------------------------------------------------------------
-- Incidents within two kilometers of Boston Common.
-- The bounding box is evaluated before the more expensive spatial calculation.
-- -----------------------------------------------------------------------------
DECLARE @BostonCommon GEOGRAPHY = geography::Point(42.3550, -71.0650, 4326);

WITH CandidateIncidents AS
(
    SELECT
        src.dateTime,
        src.category,
        src.subcategory,
        src.address,
        src.latitude,
        src.longitude
    FROM OPENROWSET(
        BULK 'abs://citydatacontainer@azureopendatastorage.blob.core.windows.net/Safety/Release/city=Boston/*.parquet',
        FORMAT = 'PARQUET'
    )
    WITH (
        dateTime   DATETIME2(7),
        category   VARCHAR(256),
        subcategory VARCHAR(512),
        address    VARCHAR(512),
        latitude   FLOAT,
        longitude  FLOAT
    ) AS src
    WHERE src.dateTime >= '2021-07-01'
      AND src.dateTime <  '2021-07-11'
      AND src.latitude  BETWEEN 42.32 AND 42.39
      AND src.longitude BETWEEN -71.11 AND -71.02
)
SELECT TOP (25)
    i.dateTime,
    i.category,
    i.subcategory,
    i.address,
    CONVERT(DECIMAL(10, 1), @BostonCommon.STDistance(p.location)) AS meters_from_boston_common
FROM CandidateIncidents AS i
CROSS APPLY (
    VALUES (geography::Point(i.latitude, i.longitude, 4326))
) AS p(location)
WHERE @BostonCommon.STDistance(p.location) <= 2000
ORDER BY meters_from_boston_common, i.dateTime;
GO
