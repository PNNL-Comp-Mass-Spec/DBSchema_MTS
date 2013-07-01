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
       AJ.Analysis_Manager_ResultsID,
       ISNULL(AJ.AMT_Count_1pct_FDR, 0) AS AMT_Count_1pct_FDR,
       ISNULL(AJ.AMT_Count_5pct_FDR, 0) AS AMT_Count_5pct_FDR,
       ISNULL(AJ.AMT_Count_10pct_FDR, 0) AS AMT_Count_10pct_FDR,
       ISNULL(AJ.AMT_Count_25pct_FDR, 0) AS AMT_Count_25pct_FDR,
       ISNULL(AJ.AMT_Count_50pct_FDR, 0) AS AMT_Count_50pct_FDR,
       AJ.Refine_Mass_Cal_PPMShift,
       AJ.MD_ID,
       AJ.QID,
       AJ.Ini_File_Name, 
       AJ.Comparison_Mass_Tag_Count, 
       AJ.MD_State
FROM T_Analysis_Job AJ
     INNER JOIN T_Analysis_Tool AnTool
       ON AJ.Tool_ID = AnTool.Tool_ID
     INNER JOIN T_Analysis_Job_Target_Jobs AJTJ
       ON AJ.Job_ID = AJTJ.Job_ID
WHERE AJ.State_ID < 100 AND 
      ISNULL(AJ.MD_State, 0) <> 7


GO
