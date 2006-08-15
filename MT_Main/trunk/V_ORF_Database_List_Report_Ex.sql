/****** Object:  View [dbo].[V_ORF_Database_List_Report_Ex] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbo.V_ORF_Database_List_Report_Ex
AS
SELECT dbo.T_ORF_Database_List.ODB_Name AS Name, 
    dbo.T_ORF_Database_List.ODB_Organism AS Organism, 
    dbo.T_ORF_Database_List.ODB_Description AS Description, 
    dbo.T_MT_Database_State_Name.Name AS State, 
    dbo.T_ORF_Database_List.ODB_Created AS Created, 
    dbo.T_MT_Database_State_Name.ID AS StateID, 
    dbo.T_ORF_Database_List.ODB_ID, 
    dbo.T_ORF_Database_List.ODB_DB_Schema_Version AS DB_Schema_Version
FROM dbo.T_ORF_Database_List INNER JOIN
    dbo.T_MT_Database_State_Name ON 
    dbo.T_ORF_Database_List.ODB_State = dbo.T_MT_Database_State_Name.ID

GO
