SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Peak_Matching_Activity]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Peak_Matching_Activity]
GO

CREATE VIEW dbo.V_Peak_Matching_Activity
AS
SELECT TOP (100) PERCENT t1.PM_AssignedProcessorName, 
    t1.PM_ToolVersion, t1.PM_ToolQueryDate, t1.Working, 
    t1.Server_Name, t1.MTDBName, t1.TaskID, t1.Job, 
    t1.Output_Folder_Path, t1.PM_Start, t1.PM_Finish, 
    t1.TasksCompleted, t1.PM_History_ID, 
    ISNULL(dbo.T_Peak_Matching_Processors.Active, 0) 
    AS Active_Processor
FROM dbo.T_Peak_Matching_Activity AS t1 LEFT OUTER JOIN
    dbo.T_Peak_Matching_Processors ON 
    t1.PM_AssignedProcessorName = dbo.T_Peak_Matching_Processors.PM_AssignedProcessorName
WHERE (t1.PM_Start >= GETDATE() - 90) AND 
    (ISNULL(dbo.T_Peak_Matching_Processors.Active, 0) < 100)
ORDER BY t1.PM_ToolQueryDate DESC

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

