/****** Object:  View [dbo].[V_Database_Backups] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW V_Database_Backups
AS
SELECT Backups.Name,
       Backups.Backup_Folder,
       Backups.Full_Backup_Interval_Days,
       Backups.Last_Full_Backup,
       Backups.Last_Trans_Backup,
       Backups.Last_Failed_Backup,
       Backups.Failed_Backup_Message,
       ISNULL(MTDBs.MTL_ID, PTDBs.PDB_ID) AS DB_ID,
       COALESCE(MTDBs.MTL_State, PTDBs.PDB_State, 7) AS State_ID,
       COALESCE(MT_State.Name, PT_State.Name, 'n/a') AS StateName
FROM T_Database_Backups Backups
     LEFT OUTER JOIN T_MT_Database_State_Name PT_State
                     INNER JOIN T_Peptide_Database_List PTDBs
                       ON PT_State.ID = PTDBs.PDB_State
       ON Backups.Name = PTDBs.PDB_Name
     LEFT OUTER JOIN T_MT_Database_List MTDBs
                     INNER JOIN T_MT_Database_State_Name MT_State
                       ON MTDBs.MTL_State = MT_State.ID
       ON Backups.Name = MTDBs.MTL_Name


GO
