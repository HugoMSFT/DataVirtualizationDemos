USE master;
GO

SET NOCOUNT ON;

RESTORE VERIFYONLY
FROM URL = N'https://tpcpublicstorage.blob.core.windows.net/tpch/tpchsf10_columnstore.bak'
WITH CHECKSUM;
GO

RESTORE VERIFYONLY
FROM URL = N'https://tpcpublicstorage.blob.core.windows.net/tpch/tpchsf10_rowstore.bak'
WITH CHECKSUM;
GO

SELECT
    bs.database_name,
    bs.backup_start_date,
    bs.backup_finish_date,
    bs.is_copy_only,
    bs.has_backup_checksums,
    CAST(bs.backup_size / 1048576.0 AS decimal(18, 2)) AS backup_size_mb,
    CAST(bs.compressed_backup_size / 1048576.0 AS decimal(18, 2)) AS compressed_size_mb,
    bmf.physical_device_name
FROM msdb.dbo.backupset AS bs
JOIN msdb.dbo.backupmediafamily AS bmf
    ON bmf.media_set_id = bs.media_set_id
WHERE bs.backup_set_id IN
(
    SELECT MAX(latest.backup_set_id)
    FROM msdb.dbo.backupset AS latest
    WHERE latest.database_name IN
        (N'tpchsf10_columnstore', N'tpchsf10_rowstore')
      AND latest.type = N'D'
    GROUP BY latest.database_name
)
ORDER BY bs.database_name;
GO
