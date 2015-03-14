/****** Object:  View [dbo].[V_Peak_Matching_Tasks] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW dbo.V_Peak_Matching_Tasks
AS
SELECT PM.Task_ID AS Task, PM.Job, 
    PMSN.Processing_State_Name AS State, 
    PM.PM_Created AS Created, PM.PM_Start AS Start, 
    PM.PM_Finish AS Finished, 
    PM.PM_AssignedProcessorName AS Processor
FROM dbo.T_Peak_Matching_Task PM INNER JOIN
    dbo.T_Peak_Matching_Task_State_Name PMSN ON 
    PM.Processing_State = PMSN.Processing_State


GO
GRANT VIEW DEFINITION ON [dbo].[V_Peak_Matching_Tasks] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[V_Peak_Matching_Tasks] TO [MTS_DB_Lite] AS [dbo]
GO
