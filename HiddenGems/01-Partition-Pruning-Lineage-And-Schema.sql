-- =============================================================================
-- Hidden Gems 01: Partition pruning, file lineage, and schema mapping
-- Platform: Azure SQL Database data virtualization (Preview)
-- Data: NYC Yellow Taxi Azure Open Dataset (public, anonymous)
-- =============================================================================
-- Blog hooks:
--   1. filepath() turns folder names into queryable partition columns.
--   2. filename()/filepath() provide lineage without changing the files.
--   3. OPENROWSET can map columns by physical ordinal, not only by name.
--   4. Parquet inference commonly returns VARCHAR(8000); pinning a schema avoids it.
--   5. External tables expose file metadata, but Azure SQL Database does not
--      support filepath()/filename() in an external-table WHERE clause.
-- =============================================================================

IF (SELECT compatibility_level
    FROM sys.databases
    WHERE database_id = DB_ID()) < 130
BEGIN
    THROW 50000, 'Azure SQL data virtualization requires compatibility level 130 or later.', 1;
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.external_data_sources
    WHERE name = N'AzureOpenDataHiddenGems'
)
BEGIN
    CREATE EXTERNAL DATA SOURCE AzureOpenDataHiddenGems
    WITH (
        LOCATION = 'abs://nyctlc@azureopendatastorage.blob.core.windows.net'
    );
END;
GO

-- -----------------------------------------------------------------------------
-- 1. Ask SQL to describe the inferred Parquet schema before running a large query.
--    Look for inferred VARCHAR(8000) columns, then replace them with realistic sizes.
-- -----------------------------------------------------------------------------
EXEC sys.sp_describe_first_result_set N'
SELECT vendorID, tpepPickupDateTime, passengerCount, paymentType
FROM OPENROWSET(
    BULK ''yellow/puYear=2018/puMonth=6/*.parquet'',
    DATA_SOURCE = ''AzureOpenDataHiddenGems'',
    FORMAT = ''PARQUET''
) AS src;';
GO

-- -----------------------------------------------------------------------------
-- 2. Rename and reorder fields by physical Parquet ordinal.
--    The output names intentionally do not match the source names.
-- -----------------------------------------------------------------------------
SELECT TOP (20)
    ride_provider,
    pickup_time,
    dropoff_time,
    passengers,
    miles,
    fare_amount
FROM OPENROWSET(
    BULK 'yellow/puYear=2018/puMonth=6/*.parquet',
    DATA_SOURCE = 'AzureOpenDataHiddenGems',
    FORMAT = 'PARQUET'
)
WITH (
    ride_provider VARCHAR(10) 1,
    pickup_time   DATETIME2(7) 2,
    dropoff_time  DATETIME2(7) 3,
    passengers    INT          4,
    miles         FLOAT        5,
    fare_amount   FLOAT        15
) AS src
ORDER BY pickup_time;
GO

-- -----------------------------------------------------------------------------
-- 3. One wildcard equals one addressable filepath(n) segment.
--    These predicates eliminate all folders except 2017 Q4.
-- -----------------------------------------------------------------------------
SELECT
    CONVERT(CHAR(4), src.filepath(1)) AS partition_year,
    CONVERT(VARCHAR(2), src.filepath(2)) AS partition_month,
    CONVERT(NVARCHAR(260), src.filename()) AS source_file,
    COUNT_BIG(*) AS ride_count
FROM OPENROWSET(
    BULK 'yellow/puYear=*/puMonth=*/*.parquet',
    DATA_SOURCE = 'AzureOpenDataHiddenGems',
    FORMAT = 'PARQUET'
)
WITH (
    vendorID VARCHAR(10)
) AS src
WHERE src.filepath(1) = '2017'
  AND src.filepath(2) IN ('10', '11', '12')
GROUP BY
    src.filepath(1),
    src.filepath(2),
    src.filename()
ORDER BY
    partition_year,
    TRY_CONVERT(TINYINT, partition_month),
    source_file;
GO

-- -----------------------------------------------------------------------------
-- 4. Put partition and lineage columns in a view for Power BI and ordinary SQL.
--    Filter the raw filepath values so folder elimination remains available.
-- -----------------------------------------------------------------------------
CREATE OR ALTER VIEW dbo.vw_NycTaxiYellow_HiddenGems
AS
SELECT
    src.filepath(1) AS puYear,
    src.filepath(2) AS puMonth,
    src.filename() AS sourceFile,
    src.vendorID,
    src.tpepPickupDateTime,
    src.tpepDropoffDateTime,
    src.passengerCount,
    src.tripDistance,
    src.paymentType,
    src.fareAmount,
    src.tipAmount,
    src.totalAmount
FROM OPENROWSET(
    BULK 'yellow/puYear=*/puMonth=*/*.parquet',
    DATA_SOURCE = 'AzureOpenDataHiddenGems',
    FORMAT = 'PARQUET'
)
WITH (
    vendorID             VARCHAR(50),
    tpepPickupDateTime   DATETIME2(7),
    tpepDropoffDateTime  DATETIME2(7),
    passengerCount       INT,
    tripDistance         FLOAT,
    paymentType          VARCHAR(10),
    fareAmount           FLOAT,
    tipAmount            FLOAT,
    totalAmount          FLOAT
) AS src;
GO

SELECT
    puMonth,
    COUNT_BIG(*) AS rides,
    CONVERT(DECIMAL(10, 2), AVG(totalAmount)) AS average_total
FROM dbo.vw_NycTaxiYellow_HiddenGems
WHERE puYear = '2018'
  AND puMonth IN ('1', '2', '3')
GROUP BY puMonth
ORDER BY TRY_CONVERT(TINYINT, puMonth);
GO

-- -----------------------------------------------------------------------------
-- 5. External-table contrast. It is convenient, but its schema must be explicit.
--    File metadata can be projected; do not filter an external table by
--    ext.filepath() or ext.filename() in Azure SQL Database.
-- -----------------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1
    FROM sys.external_file_formats
    WHERE name = N'ParquetHiddenGems'
)
BEGIN
    CREATE EXTERNAL FILE FORMAT ParquetHiddenGems
    WITH (FORMAT_TYPE = PARQUET);
END;
GO

IF OBJECT_ID(N'dbo.NycTaxiYellow_HiddenGems_External') IS NOT NULL
    DROP EXTERNAL TABLE dbo.NycTaxiYellow_HiddenGems_External;
GO

CREATE EXTERNAL TABLE dbo.NycTaxiYellow_HiddenGems_External
(
    vendorID             VARCHAR(10),
    tpepPickupDateTime   DATETIME2(7),
    tpepDropoffDateTime  DATETIME2(7),
    passengerCount       INT,
    tripDistance         FLOAT,
    puLocationId         VARCHAR(50),
    doLocationId         VARCHAR(50),
    startLon             FLOAT,
    startLat             FLOAT,
    endLon               FLOAT,
    endLat               FLOAT,
    rateCodeId           INT,
    storeAndFwdFlag      VARCHAR(50),
    paymentType          VARCHAR(50),
    fareAmount           FLOAT,
    extra                FLOAT,
    mtaTax               FLOAT,
    improvementSurcharge VARCHAR(50),
    tipAmount            FLOAT,
    tollsAmount          FLOAT,
    totalAmount          FLOAT
)
WITH (
    LOCATION = 'yellow/puYear=*/puMonth=*/*.parquet',
    DATA_SOURCE = AzureOpenDataHiddenGems,
    FILE_FORMAT = ParquetHiddenGems
);
GO

SELECT TOP (20)
    ext.filepath(1) AS puYear,
    ext.filepath(2) AS puMonth,
    ext.filename() AS sourceFile,
    ext.tpepPickupDateTime,
    ext.totalAmount
FROM dbo.NycTaxiYellow_HiddenGems_External AS ext;
GO
