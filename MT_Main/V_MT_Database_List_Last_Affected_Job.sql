/****** Object:  View [dbo].[V_MT_Database_List_Last_Affected_Job] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbo.V_MT_Database_List_Last_Affected_Job
AS
SELECT TOP 100 PERCENT dbo.T_MT_Database_List.MTL_ID, 
    dbo.T_MT_Database_List.MTL_Name, 
    dbo.T_MT_Database_List.MTL_State, 
    dbo.T_MT_Database_List.MTL_Description, 
    LookupQ.Job_Last_Affected_Max
FROM (SELECT AJMM.MTL_ID, MAX(AJMM.Last_Affected) 
          AS Job_Last_Affected_Max
      FROM T_Analysis_Job_to_MT_DB_Map AJMM INNER JOIN
          T_MT_Database_List MDL ON 
          AJMM.MTL_ID = MDL.MTL_ID
      GROUP BY AJMM.MTL_ID, MDL.MTL_Name, 
          MDL.MTL_State) LookupQ INNER JOIN
    dbo.T_MT_Database_List ON 
    LookupQ.MTL_ID = dbo.T_MT_Database_List.MTL_ID
ORDER BY LookupQ.Job_Last_Affected_Max

GO
