/****** Object:  View [dbo].[V_Analysis_Job_to_MT_DB_Map] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE VIEW V_Analysis_Job_to_MT_DB_Map
AS
SELECT TOP 100 PERCENT AJMDM.Job, AJMDM.ResultType, 
    MIN(MTDB.MTL_Name) AS DB_Name_First, 
    MAX(MTDB.MTL_Name) AS DB_Name_Last, 
    COUNT(AJMDM.MTL_ID) AS DB_Count, 
    MIN(AJMDM.Process_State) AS Process_State_Min, 
    MAX(AJMDM.Process_State) AS Process_State_Max, 
    MAX(AJMDM.Last_Affected) AS Last_Affected
FROM dbo.T_Analysis_Job_to_MT_DB_Map AJMDM INNER JOIN
    dbo.T_MT_Database_List MTDB ON 
    AJMDM.MTL_ID = MTDB.MTL_ID
GROUP BY AJMDM.Job, AJMDM.ResultType
ORDER BY AJMDM.Job

GO
