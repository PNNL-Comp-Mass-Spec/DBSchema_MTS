SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Campaign_Activity_Report]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Campaign_Activity_Report]
GO

CREATE VIEW dbo.V_Campaign_Activity_Report
AS
SELECT     TOP 100 PERCENT dbo.V_DMS_Most_Recent_Job_By_Campaign.Campaign, 
                      dbo.V_DMS_Most_Recent_Job_By_Campaign.mrcaj AS [Most Recent Job], dbo.T_MT_Database_List.MTL_Name AS [Mass Tag DB], 
                      dbo.T_MT_Database_State_Name.Name AS State, dbo.T_MT_Database_List.MTL_Last_Update AS [Last Update]
FROM         dbo.T_MT_Database_List INNER JOIN
                      dbo.T_MT_Database_State_Name ON dbo.T_MT_Database_List.MTL_State = dbo.T_MT_Database_State_Name.ID RIGHT OUTER JOIN
                      dbo.V_DMS_Most_Recent_Job_By_Campaign ON 
                      dbo.T_MT_Database_List.MTL_Campaign = dbo.V_DMS_Most_Recent_Job_By_Campaign.Campaign
ORDER BY dbo.V_DMS_Most_Recent_Job_By_Campaign.Campaign

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

