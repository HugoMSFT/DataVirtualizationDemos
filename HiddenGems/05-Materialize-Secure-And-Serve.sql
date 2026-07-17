-- =============================================================================
-- Hidden Gems 05: Turn an external snapshot into a secure local serving layer
-- Platform: Azure SQL Database
-- Data: Public Holidays Azure Open Dataset (public, anonymous)
-- =============================================================================
-- Azure SQL Database external tables do not support statistics, row-level
-- security, dynamic data masking, or CETAS. A selective INSERT...SELECT cache
-- is the bridge back to indexes and relational security features.
-- =============================================================================

IF SCHEMA_ID(N'Security') IS NULL
    EXEC(N'CREATE SCHEMA Security AUTHORIZATION dbo;');
GO

DROP SECURITY POLICY IF EXISTS Security.PublicHolidaysCountryPolicy;
DROP FUNCTION IF EXISTS Security.fn_PublicHolidaysCountryFilter;
DROP TABLE IF EXISTS dbo.PublicHolidays_HiddenGems_Cache;
GO

CREATE TABLE dbo.PublicHolidays_HiddenGems_Cache
(
    countryOrRegion      VARCHAR(256) NOT NULL,
    holidayName          VARCHAR(512) NOT NULL,
    normalizeHolidayName VARCHAR(512) NULL,
    isPaidTimeOff        BIT NULL,
    countryRegionCode    VARCHAR(10) NOT NULL,
    holidayDate          DATE NOT NULL,
    sourceFile           NVARCHAR(260) NOT NULL,
    loadedAt             DATETIME2(3) NOT NULL
        CONSTRAINT DF_PublicHolidays_HiddenGems_LoadedAt
        DEFAULT SYSUTCDATETIME()
);
GO

INSERT dbo.PublicHolidays_HiddenGems_Cache
(
    countryOrRegion,
    holidayName,
    normalizeHolidayName,
    isPaidTimeOff,
    countryRegionCode,
    holidayDate,
    sourceFile
)
SELECT
    src.countryOrRegion,
    src.holidayName,
    src.normalizeHolidayName,
    src.isPaidTimeOff,
    src.countryRegionCode,
    CONVERT(DATE, src.[date]),
    CONVERT(NVARCHAR(260), src.filename())
FROM OPENROWSET(
    BULK 'abs://holidaydatacontainer@azureopendatastorage.blob.core.windows.net/Processed/*.parquet',
    FORMAT = 'PARQUET'
)
WITH (
    countryOrRegion      VARCHAR(256),
    holidayName          VARCHAR(512),
    normalizeHolidayName VARCHAR(512),
    isPaidTimeOff        BIT,
    countryRegionCode    VARCHAR(10),
    [date]               DATETIME2(7)
) AS src
WHERE src.countryOrRegion IS NOT NULL
  AND src.holidayName IS NOT NULL
  AND src.countryRegionCode IS NOT NULL
  AND src.[date] IS NOT NULL;
GO

CREATE CLUSTERED INDEX CIX_PublicHolidays_HiddenGems
    ON dbo.PublicHolidays_HiddenGems_Cache
       (countryRegionCode, holidayDate, holidayName);
GO

CREATE FUNCTION Security.fn_PublicHolidaysCountryFilter
(
    @countryRegionCode VARCHAR(10)
)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
(
    SELECT 1 AS is_visible
    WHERE @countryRegionCode =
        CONVERT(VARCHAR(10), SESSION_CONTEXT(N'country_region_code'))
);
GO

CREATE SECURITY POLICY Security.PublicHolidaysCountryPolicy
ADD FILTER PREDICATE
    Security.fn_PublicHolidaysCountryFilter(countryRegionCode)
    ON dbo.PublicHolidays_HiddenGems_Cache
WITH (STATE = ON);
GO

-- Simulate a tenant or application context restricted to US rows.
EXEC sys.sp_set_session_context
    @key = N'country_region_code',
    @value = N'US';

SELECT
    holidayDate,
    holidayName,
    isPaidTimeOff
FROM dbo.PublicHolidays_HiddenGems_Cache
WHERE holidayDate >= '2026-01-01'
  AND holidayDate <  '2027-01-01'
ORDER BY holidayDate
FOR JSON PATH, ROOT('holidays');
GO

-- Reuse the same table and policy for another application context.
EXEC sys.sp_set_session_context
    @key = N'country_region_code',
    @value = N'GB';

SELECT
    holidayDate,
    holidayName
FROM dbo.PublicHolidays_HiddenGems_Cache
WHERE holidayDate >= '2026-01-01'
  AND holidayDate <  '2027-01-01'
ORDER BY holidayDate;
GO

EXEC sys.sp_set_session_context
    @key = N'country_region_code',
    @value = NULL;
GO
