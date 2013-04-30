/****** Object:  View [dbo].[V_Last_Full_DB_Backup] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW V_Last_Full_DB_Backup
AS
SELECT SysDB.name,
       BUSet.Backup_Date,
       DATEDIFF(DAY, ISNULL(backup_date, GETDATE() - 365), GETDATE()) AS Days_Since_Last_Full_Backup
FROM master.dbo.sysdatabases AS SysDB
     LEFT OUTER JOIN ( SELECT database_name,
                              MAX(backup_finish_date) AS backup_date
                       FROM msdb.dbo.backupset
                       WHERE backup_finish_date <= GetDate() AND
                             [type] = 'D' -- Full DB Backups as Type D
                       GROUP BY database_name ) AS BUSet
       ON SysDB.name = BUSet.database_name

GO
