/****** Object:  View [dbo].[V_Process_State_Summary] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO
CREATE VIEW [dbo].[V_Process_State_Summary]
AS
SELECT TOP 100 Percent TAD.Analysis_Tool, PS.Name AS State, 
    TAD.Process_State AS State_ID, COUNT(*) AS Job_Count, MAX(TAD.Last_Affected) AS Last_Affected
FROM dbo.T_Analysis_Description TAD INNER JOIN
    dbo.T_Process_State PS ON 
    TAD.Process_State = PS.ID
GROUP BY TAD.Analysis_Tool, TAD.Process_State, PS.Name
ORDER BY TAD.Analysis_Tool, TAD.Process_State

GO
GRANT VIEW DEFINITION ON [dbo].[V_Process_State_Summary] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[V_Process_State_Summary] TO [MTS_DB_Lite] AS [dbo]
GO
