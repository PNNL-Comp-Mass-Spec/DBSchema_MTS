/****** Object:  View [dbo].[V_MSMS_Analysis_Jobs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_MSMS_Analysis_Jobs]
AS
SELECT TAD.Job,
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
       DMS_Enzymes.Enzyme_Name,
       TAD.Labelling,
       ASN.AD_State_Name AS State_Name,
       PDL.Peptide_DB_Name,
       dbo.udfCombinePaths(
         dbo.udfCombinePaths(
           dbo.udfCombinePaths(
             TAD.Vol_Client, 
             TAD.Storage_Path), 
             TAD.Dataset_Folder),
             TAD.Results_Folder) + '\' AS Results_Folder_Path,
       dbo.udfCombinePaths(
         dbo.udfCombinePaths(
           dbo.udfCombinePaths(
             TAD.Vol_Server, 
             TAD.Storage_Path), 
             TAD.Dataset_Folder),
             TAD.Results_Folder) + '\' AS Results_Folder_Path_Local
FROM dbo.T_Analysis_Description TAD
     INNER JOIN dbo.T_Analysis_State_Name ASN
       ON TAD.State = ASN.AD_State_ID
     LEFT OUTER JOIN MT_Main.dbo.V_DMS_Enzymes DMS_Enzymes
       ON TAD.Enzyme_ID = DMS_Enzymes.Enzyme_ID
     LEFT OUTER JOIN MT_Main.dbo.V_MTS_PT_DBs PDL
       ON TAD.PDB_ID = PDL.Peptide_DB_ID


GO
GRANT VIEW DEFINITION ON [dbo].[V_MSMS_Analysis_Jobs] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[V_MSMS_Analysis_Jobs] TO [MTS_DB_Lite] AS [dbo]
GO
