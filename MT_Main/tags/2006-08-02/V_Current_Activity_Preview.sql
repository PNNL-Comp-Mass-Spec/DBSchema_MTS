SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Current_Activity_Preview]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Current_Activity_Preview]
GO


CREATE VIEW dbo.V_Current_Activity_Preview
AS
SELECT  top 100 percent   CAST(T_MT_Database_List.MTL_Name AS char(32)) AS Name, CAST(T_MT_Database_List.MTL_Campaign AS char(32)) AS Campaign, 
                      T_MT_Database_State_Name.Name AS State, CASE WHEN [MTL_State] IN (2, 5) THEN 'Yes' ELSE 'No' END AS AutoUpdate
FROM         T_MT_Database_List INNER JOIN
                      V_DMS_Most_Recent_Job_By_Campaign M ON M.Campaign = T_MT_Database_List.MTL_Campaign AND 
                      ISNULL(T_MT_Database_List.MTL_Last_Update, '1/1/1900') < M.mrcaj INNER JOIN
                      T_MT_Database_State_Name ON T_MT_Database_List.MTL_State = T_MT_Database_State_Name.ID
ORDER BY CASE WHEN [MTL_State] IN (2, 5) THEN 'Yes' ELSE 'No' END DESC, CAST(T_MT_Database_List.MTL_State AS char(8))



GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

