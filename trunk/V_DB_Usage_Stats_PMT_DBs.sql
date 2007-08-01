/****** Object:  View [dbo].[V_DB_Usage_Stats_PMT_DBs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbo.V_DB_Usage_Stats_PMT_DBs
AS
SELECT TOP 100 PERCENT LookupQ.MTL_Name, 
    LookupQ.MTL_Description AS Description, 
    LookupQ.MTL_State AS State, LookupQ.Created_Max, 
    LookupQ.Last_Affected_Max, LookupQ.Job_Count, 
    DATEDIFF(month, LookupQ.Created_Max, GETDATE()) 
    AS Months_Since_Last_Job_Created, DATEDIFF(month, 
    LookupQ.Last_Affected_Max, GETDATE()) 
    AS Months_Since_Last_Job_Affected, 
    dbo.V_Current_Activity.[Duration Last Cycle (Minutes)], 
    dbo.V_Current_Activity.[Duration Last 24 hours], 
    dbo.V_Current_Activity.[Duration Last 7 Days]
FROM (SELECT MTL.MTL_Name, MTL.MTL_Description, 
          MTL.MTL_State, MAX(AJMM.Created) AS Created_Max, 
          MAX(AJMM.Last_Affected) AS Last_Affected_Max, 
          COUNT(*) AS Job_Count
      FROM T_Analysis_Job_to_MT_DB_Map AJMM INNER JOIN
          T_MT_Database_List MTL ON 
          AJMM.MTL_ID = MTL.MTL_ID
      WHERE (MTL.MTL_State < 15)
      GROUP BY MTL.MTL_Name, MTL.MTL_Description, 
          MTL.MTL_State) LookupQ LEFT OUTER JOIN
    dbo.V_Current_Activity ON 
    LookupQ.MTL_Name = dbo.V_Current_Activity.Name
ORDER BY DATEDIFF(month, LookupQ.Last_Affected_Max, 
    GETDATE()) DESC, DATEDIFF(month, LookupQ.Created_Max, 
    GETDATE()) DESC

GO
