/****** Object:  View [dbo].[V_Last_Active_DB_Backup_Overdue] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbo.V_Last_Active_DB_Backup_Overdue
AS
SELECT LookupQ.Name, LookupQ.Backup_Date, 
    T_MT_Database_State_Name.Name AS State
FROM (SELECT V_Last_DB_Backup.name, 
          V_Last_DB_Backup.Backup_Date, 
          ISNULL(T_Peptide_Database_List.PDB_State, 0) 
          AS State
      FROM V_Last_DB_Backup LEFT OUTER JOIN
          T_Peptide_Database_List ON 
          V_Last_DB_Backup.name = T_Peptide_Database_List.PDB_Name
      UNION
      SELECT V_Last_DB_Backup.name, 
          V_Last_DB_Backup.Backup_Date, 
          ISNULL(T_MT_Database_List.MTL_State, 0) 
          AS MTL_State
      FROM V_Last_DB_Backup LEFT OUTER JOIN
          T_MT_Database_List ON 
          V_Last_DB_Backup.name = T_MT_Database_List.MTL_Name
      UNION
      SELECT V_Last_DB_Backup.name, 
          V_Last_DB_Backup.Backup_Date, 
          ISNULL(T_ORF_Database_List.ODB_State, 0) 
          AS State
      FROM V_Last_DB_Backup LEFT OUTER JOIN
          T_ORF_Database_List ON 
          V_Last_DB_Backup.name = T_ORF_Database_List.ODB_Name)
     LookupQ INNER JOIN
    T_MT_Database_State_Name ON 
    LookupQ.State = T_MT_Database_State_Name.ID
WHERE (ISNULL(LookupQ.Backup_Date, 0) < GETDATE() - 14) AND 
    (NOT (LookupQ.State IN (0, 3, 10)))

GO
