SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Peak_Matching_Tasks]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Peak_Matching_Tasks]
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
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

