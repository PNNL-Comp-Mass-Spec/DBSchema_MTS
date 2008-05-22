/****** Object:  View [dbo].[V_Peak_Matching_Activity] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[V_Peak_Matching_Activity]
AS
SELECT TOP (100) PERCENT PMA.Assigned_Processor_Name, 
    PMA.Tool_Version, PMA.Tool_Query_Date, PMA.Working, 
    PMA.Server_Name, PMA.Database_Name, PMA.Task_ID, PMA.Job AS DMS_Job, 
    PMA.Output_Folder_Path, PMA.Task_Start, PMA.Task_Finish, 
    PMA.Tasks_Completed, PMA.Job_ID, 
     ISNULL(AJP.State, 'D') AS Processor_State
FROM dbo.T_Peak_Matching_Activity PMA LEFT OUTER JOIN
    dbo.T_Analysis_Job_Processors AJP ON
    PMA.Assigned_Processor_Name = AJP.Processor_Name
WHERE (PMA.Task_Start >= GETDATE() - 90) AND 
    (ISNULL(AJP.State, 'D') <> 'I')
ORDER BY PMA.Tool_Query_Date DESC

GO
