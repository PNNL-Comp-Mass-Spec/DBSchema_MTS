/****** Object:  View [dbo].[V_Last_DB_Backup_Overdue] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE View dbo.V_Last_DB_Backup_Overdue
AS
SELECT name, Backup_Date, 
    PDB_State + MTL_State + ODB_State AS DB_State
FROM (SELECT V_Last_DB_Backup.name, 
          V_Last_DB_Backup.Backup_Date, 
          ISNULL(T_Peptide_Database_List.PDB_State, 0) 
          AS PDB_State, 
          ISNULL(T_MT_Database_List.MTL_State, 0) 
          AS MTL_State, 
          ISNULL(T_ORF_Database_List.ODB_State, 0) 
          AS ODB_State
      FROM V_Last_DB_Backup LEFT OUTER JOIN
          T_ORF_Database_List ON 
          V_Last_DB_Backup.name = T_ORF_Database_List.ODB_Name
           LEFT OUTER JOIN
          T_MT_Database_List ON 
          V_Last_DB_Backup.name = T_MT_Database_List.MTL_Name
           LEFT OUTER JOIN
          T_Peptide_Database_List ON 
          V_Last_DB_Backup.name = T_Peptide_Database_List.PDB_Name)
     AS LookupQ
WHERE IsNull(backup_date, 0) < GetDate() - 28

GO
