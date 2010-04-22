/****** Object:  View [dbo].[V_Peak_Matching_Tasks] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE VIEW [dbo].[V_Peak_Matching_Tasks]
AS
SELECT AnTool.Tool_Name,
       AJ.Job_ID AS MTS_Job_ID,
       AJ.Job_Start,
       AJ.Job_Finish,
       AJ.Comment,
       AJ.State_ID,
       AJ.Task_Server,
       AJ.Task_Database,
       AJ.Task_ID,
       AJ.Assigned_Processor_Name,
       AJ.Tool_Version,
       AJ.DMS_Job_Count,
       AJTJ.DMS_Job,
       AJ.Output_Folder_Path,
       AJ.Results_URL,
       AJ.Analysis_Manager_Error,
       AJ.Analysis_Manager_Warning,
       AJ.Analysis_Manager_ResultsID
FROM T_Analysis_Job AJ
     INNER JOIN T_Analysis_Tool AnTool
       ON AJ.Tool_ID = AnTool.Tool_ID
     INNER JOIN T_Analysis_Job_Target_Jobs AJTJ
       ON AJ.Job_ID = AJTJ.Job_ID
    

GO
