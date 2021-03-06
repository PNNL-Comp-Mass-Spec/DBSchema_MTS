/****** Object:  View [dbo].[V_Peptide_Database_List_Report] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbo.V_Peptide_Database_List_Report
AS
SELECT dbo.T_Peptide_Database_List.PDB_Name AS Name, 
   dbo.T_Peptide_Database_List.PDB_Organism AS Organism, 
   dbo.T_Peptide_Database_List.PDB_Description AS Description, 
   dbo.T_Peptide_Database_List.PDB_Connection_String AS ConnectionString,
    dbo.T_MT_Database_State_Name.Name AS State
FROM dbo.T_Peptide_Database_List INNER JOIN
   dbo.T_MT_Database_State_Name ON 
   dbo.T_Peptide_Database_List.PDB_State = dbo.T_MT_Database_State_Name.ID

GO
