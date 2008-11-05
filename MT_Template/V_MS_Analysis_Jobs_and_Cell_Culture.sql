/****** Object:  View [dbo].[V_MS_Analysis_Jobs_and_Cell_Culture] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_MS_Analysis_Jobs_and_Cell_Culture]
AS
SELECT IsNull(DCC.CellCulture, '(none)') AS [Cell Culture],
       TAD.Job,
       TAD.State,
       TAD.Dataset,
       TAD.Dataset_ID,
       TAD.Dataset_Created_DMS,
       TAD.Experiment,
       TAD.Campaign,
       TAD.Experiment_Organism,
       TAD.Instrument,
       TAD.Instrument_Class,
       TAD.Analysis_Tool,
       TAD.Parameter_File_Name,
       TAD.Settings_File_Name,
       TAD.Organism_DB_Name,
       TAD.Protein_Collection_List,
       TAD.Protein_Options_List,
       TAD.Completed,
       TAD.ResultType,
       TAD.Separation_Sys_Type,
       TAD.PreDigest_Internal_Std,
       TAD.PostDigest_Internal_Std,
       TAD.Dataset_Internal_Std,
       TAD.Labelling,
       ASN.AD_State_Name AS State_Name,
       dbo.udfCombinePaths(
         dbo.udfCombinePaths(
           dbo.udfCombinePaths(
             TAD.Vol_Client, 
             TAD.Storage_Path), 
             TAD.Dataset_Folder),
             TAD.Results_Folder) + '\' AS Results_Folder_Path
FROM dbo.T_FTICR_Analysis_Description TAD
     INNER JOIN dbo.T_Analysis_State_Name ASN
       ON TAD.State = ASN.AD_State_ID
     LEFT OUTER JOIN MT_Main.dbo.V_DMS_Cell_Culture_Experiments_Import DCC
       ON TAD.Experiment = DCC.Experiment


GO
