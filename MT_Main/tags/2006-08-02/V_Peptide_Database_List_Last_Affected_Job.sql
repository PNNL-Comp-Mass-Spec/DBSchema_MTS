SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Peptide_Database_List_Last_Affected_Job]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Peptide_Database_List_Last_Affected_Job]
GO

CREATE VIEW dbo.V_Peptide_Database_List_Last_Affected_Job
AS
SELECT TOP 100 PERCENT dbo.T_Peptide_Database_List.PDB_ID, 
    dbo.T_Peptide_Database_List.PDB_Name, 
    dbo.T_Peptide_Database_List.PDB_State, 
    dbo.T_Peptide_Database_List.PDB_Description, 
    LookupQ.Job_Last_Affected_Max
FROM (SELECT AJPM.PDB_ID, MAX(AJPM.Last_Affected) 
          AS Job_Last_Affected_Max
      FROM T_Analysis_Job_to_Peptide_DB_Map AJPM INNER JOIN
          T_Peptide_Database_List PDL ON 
          AJPM.PDB_ID = PDL.PDB_ID
      GROUP BY AJPM.PDB_ID, PDL.PDB_Name, 
          PDL.PDB_State) LookupQ INNER JOIN
    dbo.T_Peptide_Database_List ON 
    LookupQ.PDB_ID = dbo.T_Peptide_Database_List.PDB_ID
ORDER BY LookupQ.Job_Last_Affected_Max

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

