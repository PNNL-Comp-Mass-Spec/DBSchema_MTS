SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_MT_Database_List_Report]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_MT_Database_List_Report]
GO

CREATE VIEW dbo.V_MT_Database_List_Report
AS
SELECT dbo.T_MT_Database_List.MTL_Name AS Name, 
    dbo.T_MT_Database_List.MTL_Organism AS Organism, 
    dbo.T_MT_Database_List.MTL_Campaign AS Campaign, 
    dbo.T_MT_Database_List.MTL_Description AS Description, 
    dbo.T_MT_Database_List.MTL_Connection_String AS ConnectionString,
     dbo.T_MT_Database_State_Name.Name AS State
FROM dbo.T_MT_Database_List INNER JOIN
    dbo.T_MT_Database_State_Name ON 
    dbo.T_MT_Database_List.MTL_State = dbo.T_MT_Database_State_Name.ID
WHERE (dbo.T_MT_Database_State_Name.ID <> 100)

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

