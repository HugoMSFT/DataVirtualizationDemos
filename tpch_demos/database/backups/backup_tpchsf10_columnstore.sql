USE master;
GO

SET NOCOUNT ON;

IF DB_ID(N'tpchsf10_columnstore') IS NULL
    THROW 50101, 'Database tpchsf10_columnstore does not exist.', 1;

BACKUP DATABASE [tpchsf10_columnstore]
TO URL = N'https://tpcpublicstorage.blob.core.windows.net/tpch/tpchsf10_columnstore.bak'
WITH
    COPY_ONLY,
    COMPRESSION,
    CHECKSUM,
    BLOCKSIZE = 65536,
    MAXTRANSFERSIZE = 4194304,
    NAME = N'tpchsf10_columnstore full backup',
    DESCRIPTION = N'Copy-only full backup to Azure Blob Storage',
    STATS = 5;
GO

SELECT TOP (1)
    database_name,
    backup_start_date,
    backup_finish_date,
    type,
    is_copy_only,
    has_backup_checksums,
    CAST(backup_size / 1048576.0 AS decimal(18, 2)) AS backup_size_mb,
    CAST(compressed_backup_size / 1048576.0 AS decimal(18, 2)) AS compressed_size_mb,
    physical_device_name
FROM msdb.dbo.backupset AS bs
JOIN msdb.dbo.backupmediafamily AS bmf
    ON bmf.media_set_id = bs.media_set_id
WHERE database_name = N'tpchsf10_columnstore'
  AND type = N'D'
ORDER BY backup_finish_date DESC;
GO
