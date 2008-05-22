/****** Object:  View [dbo].[V_MultiAlign_Activity] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[V_MultiAlign_Activity]
AS
SELECT TOP (100) PERCENT MAA.Assigned_Processor_Name, 
    MAA.Tool_Version, MAA.Tool_Query_Date, MAA.Working, 
    MAA.Server_Name, MAA.Database_Name, MAA.Task_ID, 
    MAA.Output_Folder_Path, MAA.Task_Start, MAA.Task_Finish, 
    MAA.Tasks_Completed, MAA.Job_ID, 
    ISNULL(AJP.State, 'D') AS Processor_State
FROM dbo.T_MultiAlign_Activity MAA LEFT OUTER JOIN
    dbo.T_Analysis_Job_Processors AJP ON 
    MAA.Assigned_Processor_Name = AJP.Processor_Name
WHERE (MAA.Task_Start >= GETDATE() - 90) AND 
    (ISNULL(AJP.State, 'D') <> 'I')
ORDER BY MAA.Tool_Query_Date DESC

GO
