/****** Object:  View [dbo].[V_Peak_Matching_Params_Cached] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[V_Peak_Matching_Params_Cached]
AS
SELECT 'Viper' AS ToolName,
       PMPC.Job_ID AS JobNum,
       'Job_' + CONVERT(varchar(12), PMPC.Job_ID) AS DatasetNum,
       PMPC.Task_ID,
       PMPC.Task_Server,
       PMPC.Task_Database,
       AJ.Comment,
       PMPC.Priority,
       PMPC.DMS_Job,
       PMPC.Minimum_High_Normalized_Score,
       PMPC.Minimum_High_Discriminant_Score,
       PMPC.Minimum_Peptide_Prophet_Probability,
       PMPC.Minimum_PMT_Quality_Score,
       PMPC.Experiment_Filter,
       PMPC.Experiment_Exclusion_Filter,
       PMPC.Limit_To_PMTs_From_Dataset,
       PMPC.Internal_Std_Explicit,
       PMPC.NET_Value_Type,
       PMPC.ParamFileStoragePath AS ParmFileStoragePath,
       PMPC.ParamFileName AS ParmFileName,
       PMPC.TransferFolderPath,
       PMPC.ResultsFolderName,
       PMPC.Cache_Date,
       'na' AS SettingsFileName
FROM dbo.T_Peak_Matching_Params_Cached AS PMPC
     LEFT OUTER JOIN dbo.T_Analysis_Job AS AJ
       ON PMPC.Job_ID = AJ.Job_ID

GO
