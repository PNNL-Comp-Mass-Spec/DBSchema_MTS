/****** Object:  View [dbo].[V_NET_Update_Task_Summary] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW dbo.V_NET_Update_Task_Summary
AS
SELECT TOP 100 PERCENT UT.Task_ID, UT.Processing_State, 
    UTSN.Processing_State_Name, UT.Task_Created, 
    UT.Task_Start, UT.Task_Finish, 
    UT.Task_AssignedProcessorName, COUNT(TJM.Job) 
    AS Job_Count, MIN(TJM.Job) AS Job_Min, MAX(TJM.Job) 
    AS Job_Max, MIN(AD.Process_State) AS Process_State_Min, 
    MAX(AD.Process_State) AS Process_State_Max
FROM dbo.T_NET_Update_Task_State_Name UTSN INNER JOIN
    dbo.T_NET_Update_Task UT ON 
    UTSN.Processing_State = UT.Processing_State LEFT OUTER JOIN
    dbo.T_Analysis_Description AD INNER JOIN
    dbo.T_NET_Update_Task_Job_Map TJM ON 
    AD.Job = TJM.Job ON UT.Task_ID = TJM.Task_ID
GROUP BY UT.Task_ID, UT.Processing_State, UT.Task_Created, 
    UT.Task_Start, UT.Task_Finish, 
    UT.Task_AssignedProcessorName, 
    UTSN.Processing_State_Name
ORDER BY UT.Task_ID


GO
GRANT VIEW DEFINITION ON [dbo].[V_NET_Update_Task_Summary] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[V_NET_Update_Task_Summary] TO [MTS_DB_Lite] AS [dbo]
GO
