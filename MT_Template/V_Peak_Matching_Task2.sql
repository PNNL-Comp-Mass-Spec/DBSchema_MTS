/****** Object:  View [dbo].[V_Peak_Matching_Task2] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_Peak_Matching_Task2]
AS
SELECT PM.Dataset,
       PM.Instrument,
       PM.Task_ID,
       PM.Job,
       PM.Minimum_High_Normalized_Score,
       PM.Minimum_High_Discriminant_Score,
       PM.Minimum_Peptide_Prophet_Probability,
       PM.Minimum_PMT_Quality_Score,
       PM.Ini_File_Name,
       PM.Output_Folder_Name,
       PM.Results_URL,
       PM.Processing_State,
       PM.Priority,
       PM.Processing_Error_Code,
       PM.Processing_Warning_Code,
       PM.PM_Created,
       PM.PM_Start,
       PM.PM_Finish,
       PM.PM_AssignedProcessorName,
       PM.MD_ID,
       MMD.MD_Comparison_Mass_Tag_Count,
       MMD.MD_UMC_Count,
       MMD.AMT_Count_1pct_FDR,
       MMD.AMT_Count_5pct_FDR,
       MMD.AMT_Count_10pct_FDR,
       MMD.AMT_Count_25pct_FDR,
       MMD.AMT_Count_50pct_FDR
FROM V_Peak_Matching_Task PM
     LEFT OUTER JOIN T_Match_Making_Description MMD
       ON PM.MD_ID = MMD.MD_ID


GO
