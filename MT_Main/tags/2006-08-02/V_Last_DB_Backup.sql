SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Last_DB_Backup]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Last_DB_Backup]
GO

Create View dbo.V_Last_DB_Backup
AS
SELECT SysDB.name, BUSet.Backup_Date 
FROM master.dbo.sysdatabases AS SysDB
	LEFT OUTER JOIN
            (SELECT database_name, MAX(backup_finish_date) AS backup_date
             FROM msdb.dbo.backupset WHERE backup_finish_date <= GetDate()
             GROUP BY database_name) AS BUSet
	ON SysDB.name = BUSet.database_name


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

