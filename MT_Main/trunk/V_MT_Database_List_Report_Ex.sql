/****** Object:  View [dbo].[V_MT_Database_List_Report_Ex] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbo.V_MT_Database_List_Report_Ex
AS
SELECT TOP 100 PERCENT dbo.T_MT_Database_List.MTL_Name AS
     Name, 
    dbo.T_MT_Database_List.MTL_Campaign AS Campaign, 
    dbo.T_MT_Database_List.MTL_Description AS Description, 
    dbo.T_MT_Database_List.MTL_Organism AS Organism, 
    dbo.T_MT_Database_State_Name.Name AS State, 
    dbo.T_MT_Database_List.MTL_Created AS Created, 
    dbo.T_MT_Database_List.MTL_Last_Update AS [Last Update], 
    DATEDIFF(dd, dbo.T_MT_Database_List.MTL_Last_Update, 
    GETDATE()) AS [Days since], 
    dbo.T_MT_Database_State_Name.ID AS StateID, 
    dbo.T_MT_Database_List.MTL_ID, 
    dbo.T_MT_Database_List.MTL_DB_Schema_Version AS DB_Schema_Version
FROM dbo.T_MT_Database_List INNER JOIN
    dbo.T_MT_Database_State_Name ON 
    dbo.T_MT_Database_List.MTL_State = dbo.T_MT_Database_State_Name.ID
ORDER BY dbo.T_MT_Database_List.MTL_Created DESC

GO
