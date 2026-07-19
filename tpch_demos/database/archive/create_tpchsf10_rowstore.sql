USE master;
GO

SET NOCOUNT ON;

IF DB_ID(N'tpchsf10_columnstore') IS NULL
    THROW 50011, 'Source database tpchsf10_columnstore is missing.', 1;

IF DB_ID(N'tpchsf10_rowstore') IS NOT NULL
    THROW 50012, 'Target rowstore database already exists.', 1;
GO

-- Use the SQL Server instance defaults instead of machine-specific drive paths.
CREATE DATABASE [tpchsf10_rowstore];
GO

ALTER DATABASE [tpchsf10_rowstore] SET RECOVERY SIMPLE;
ALTER DATABASE [tpchsf10_rowstore] SET COMPATIBILITY_LEVEL = 170;
GO

SELECT
    d.name,
    d.state_desc,
    d.recovery_model_desc,
    d.compatibility_level,
    mf.type_desc,
    CAST(mf.size * 8.0 / 1024 AS decimal(12, 1)) AS size_mb,
    mf.physical_name
FROM sys.databases AS d
JOIN sys.master_files AS mf
    ON mf.database_id = d.database_id
WHERE d.name IN (N'tpchsf10_columnstore', N'tpchsf10_rowstore')
ORDER BY d.name, mf.type;
GO
