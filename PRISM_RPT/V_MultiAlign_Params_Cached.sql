/****** Object:  View [dbo].[V_MultiAlign_Params_Cached] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[V_MultiAlign_Params_Cached]
AS
SELECT 'MultiAlign' AS ToolName,
       MAPC.Job_ID AS JobNum,
       SUBSTRING('DMSJobs_' + MAPC.DMS_Job_List, 1, 128) AS DatasetNum,
       MAPC.Task_ID,
       MAPC.Task_Server,
       MAPC.Task_Database,
       AJ.Comment,
       MAPC.Priority,
       MAPC.DMS_Job_List,
       MAPC.Minimum_High_Normalized_Score,
       MAPC.Minimum_High_Discriminant_Score,
       MAPC.Minimum_Peptide_Prophet_Probability,
       MAPC.Minimum_PMT_Quality_Score,
       MAPC.Experiment_Filter,
       MAPC.Experiment_Exclusion_Filter,
       MAPC.Limit_To_PMTs_From_Dataset,
       MAPC.Internal_Std_Explicit,
       MAPC.NET_Value_Type,
       MAPC.ParamFileStoragePath AS ParmFileStoragePath,
       MAPC.ParamFileName AS ParmFileName,
       MAPC.TransferFolderPath,
       MAPC.ResultsFolderName,
       MAPC.Cache_Date,
       'na' AS SettingsFileName
FROM dbo.T_MultiAlign_Params_Cached AS MAPC
     LEFT OUTER JOIN dbo.T_Analysis_Job AS AJ
       ON MAPC.Job_ID = AJ.Job_ID

GO
