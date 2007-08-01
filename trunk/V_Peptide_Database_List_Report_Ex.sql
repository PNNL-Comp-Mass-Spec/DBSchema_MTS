/****** Object:  View [dbo].[V_Peptide_Database_List_Report_Ex] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbo.V_Peptide_Database_List_Report_Ex
AS
SELECT dbo.T_Peptide_Database_List.PDB_Name AS Name, 
    dbo.T_Peptide_Database_List.PDB_Organism AS Organism, 
    dbo.T_Peptide_Database_List.PDB_Description AS Description, 
    dbo.T_MT_Database_State_Name.Name AS State, 
    dbo.T_Peptide_Database_List.PDB_Last_Update AS [Last Update],
     dbo.T_Peptide_Database_List.PDB_Created AS Created, 
    dbo.T_MT_Database_State_Name.ID AS StateID, 
    dbo.T_Peptide_Database_List.PDB_ID, 
    dbo.T_Peptide_Database_List.PDB_DB_Schema_Version AS DB_Schema_Version
FROM dbo.T_Peptide_Database_List INNER JOIN
    dbo.T_MT_Database_State_Name ON 
    dbo.T_Peptide_Database_List.PDB_State = dbo.T_MT_Database_State_Name.ID

GO
