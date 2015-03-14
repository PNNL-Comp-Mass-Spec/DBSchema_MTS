/****** Object:  View [dbo].[V_Analysis_Description_Updates] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_Analysis_Description_Updates]
AS
SELECT  Entered, Job, 
        CASE WHEN IsNull(Dataset, '') <> IsNull(Dataset_New, '')
            THEN '* ' + Dataset + ' --> ' + Dataset_New
            ELSE Dataset
        END AS Dataset,
        CASE WHEN IsNull(Dataset_ID, 0) <> IsNull(Dataset_ID_New, 0)
            THEN '* ' + Convert(varchar(19), Dataset_ID) + ' --> ' + Convert(varchar(19), Dataset_ID_New)
            ELSE Convert(varchar(19), Dataset_ID)
        END AS Dataset_ID,
        CASE WHEN IsNull(Dataset_Acq_Length, 0) <> IsNull(Dataset_Acq_Length_New, 0)
            THEN '* ' + Convert(varchar(19), ISNULL(Dataset_Acq_Length, 0)) + ' --> ' + Convert(varchar(19), Dataset_Acq_Length_New)
            ELSE Convert(varchar(19), Dataset_Acq_Length)
        END AS Dataset_Acq_Length,
        CASE WHEN IsNull(Experiment, '') <> IsNull(Experiment_New, '')
            THEN '* ' + Experiment + ' --> ' + Experiment_New
            ELSE Experiment
        END AS Experiment,
        CASE WHEN IsNull(Campaign, '') <> IsNull(Campaign_New, '')
            THEN '* ' + Campaign + ' --> ' + Campaign_New
            ELSE Campaign
        END AS Campaign,
        CASE WHEN IsNull(Vol_Client, '') <> IsNull(Vol_Client_New, '')
            THEN '* ' + Vol_Client + ' --> ' + Vol_Client_New
            ELSE Vol_Client
        END AS Vol_Client,
        CASE WHEN IsNull(Vol_Server, '') <> IsNull(Vol_Server_New, '')
            THEN '* ' + Vol_Server + ' --> ' + Vol_Server_New
            ELSE Vol_Server
        END AS Vol_Server,
        CASE WHEN IsNull(Storage_Path, '') <> IsNull(Storage_Path_New, '')
            THEN '* ' + Storage_Path + ' --> ' + Storage_Path_New
            ELSE Storage_Path
        END AS Storage_Path,
        CASE WHEN IsNull(Dataset_Folder, '') <> IsNull(Dataset_Folder_New, '')
            THEN '* ' + Dataset_Folder + ' --> ' + Dataset_Folder_New
            ELSE Dataset_Folder
        END AS Dataset_Folder,
        CASE WHEN IsNull(Results_Folder, '') <> IsNull(Results_Folder_New, '')
            THEN '* ' + Results_Folder + ' --> ' + Results_Folder_New
            ELSE Results_Folder
        END AS Results_Folder,
        CASE WHEN IsNull(Completed, '1/1/1980') <> IsNull(Completed_New, '1/1/1980')
            THEN '* ' + Convert(varchar(64), Completed, 120) + ' --> ' + Convert(varchar(64), Completed_New, 120)
            ELSE Convert(varchar(64), Completed, 120)
        END AS Completed,
        CASE WHEN IsNull(Parameter_File_Name, '') <> IsNull(Parameter_File_Name_New, '')
            THEN '* ' + Parameter_File_Name + ' --> ' + Parameter_File_Name_New
            ELSE Parameter_File_Name
        END AS Parameter_File_Name,
        CASE WHEN IsNull(Settings_File_Name, '') <> IsNull(Settings_File_Name_New, '')
            THEN '* ' + Settings_File_Name + ' --> ' + Settings_File_Name_New
            ELSE Settings_File_Name
        END AS Settings_File_Name,
        CASE WHEN IsNull(Organism_DB_Name, '') <> IsNull(Organism_DB_Name_New, '')
            THEN '* ' + Organism_DB_Name + ' --> ' + Organism_DB_Name_New
            ELSE Organism_DB_Name
        END AS Organism_DB_Name,
        CASE WHEN IsNull(Protein_Collection_List, '') <> IsNull(Protein_Collection_List_New, '')
            THEN '* ' + Protein_Collection_List + ' --> ' + Protein_Collection_List_New
            ELSE Protein_Collection_List
        END AS Protein_Collection_List,
        CASE WHEN IsNull(Protein_Options_List, '') <> IsNull(Protein_Options_List_New, '')
            THEN '* ' + Protein_Options_List + ' --> ' + Protein_Options_List_New
            ELSE Protein_Options_List
        END AS Protein_Options_List,
        CASE WHEN IsNull(Separation_Sys_Type, '') <> IsNull(Separation_Sys_Type_New, '')
            THEN '* ' + Separation_Sys_Type + ' --> ' + Separation_Sys_Type_New
            ELSE Separation_Sys_Type
        END AS Separation_Sys_Type,
        CASE WHEN IsNull(PreDigest_Internal_Std, '') <> IsNull(PreDigest_Internal_Std_New, '')
            THEN '* ' + PreDigest_Internal_Std + ' --> ' + PreDigest_Internal_Std_New
            ELSE PreDigest_Internal_Std
        END AS PreDigest_Internal_Std,
        CASE WHEN IsNull(PostDigest_Internal_Std, '') <> IsNull(PostDigest_Internal_Std_New, '')
            THEN '* ' + PostDigest_Internal_Std + ' --> ' + PostDigest_Internal_Std_New
            ELSE PostDigest_Internal_Std
        END AS PostDigest_Internal_Std,
        CASE WHEN IsNull(Dataset_Internal_Std, '') <> IsNull(Dataset_Internal_Std_New, '')
            THEN '* ' + Dataset_Internal_Std + ' --> ' + Dataset_Internal_Std_New
            ELSE Dataset_Internal_Std
        END AS Dataset_Internal_Std,
        CASE WHEN IsNull(Enzyme_ID, 0) <> IsNull(Enzyme_ID_New, 0)
            THEN '* ' + Convert(varchar(19), Enzyme_ID) + ' --> ' + Convert(varchar(19), Enzyme_ID_New)
            ELSE Convert(varchar(19), Enzyme_ID)
        END AS Enzyme_ID,        
        CASE WHEN IsNull(Labelling, '') <> IsNull(Labelling_New, '')
            THEN '* ' + Labelling + ' --> ' + Labelling_New
            ELSE Labelling
        END AS Labelling
FROM dbo.T_Analysis_Description_Updates


GO
GRANT VIEW DEFINITION ON [dbo].[V_Analysis_Description_Updates] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[V_Analysis_Description_Updates] TO [MTS_DB_Lite] AS [dbo]
GO
