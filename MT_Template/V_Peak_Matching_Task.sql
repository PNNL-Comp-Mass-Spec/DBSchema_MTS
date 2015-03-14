/****** Object:  View [dbo].[V_Peak_Matching_Task] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_Peak_Matching_Task]
AS
SELECT FAD.Dataset, FAD.Instrument, PM.Task_ID, PM.Job, 
    PM.Minimum_High_Normalized_Score, 
    PM.Minimum_High_Discriminant_Score, 
    PM.Minimum_Peptide_Prophet_Probability, 
    PM.Minimum_PMT_Quality_Score, PM.Ini_File_Name, 
    PM.Output_Folder_Name, 
    'http://' + Lower(@@ServerName) + '/pm/results/' + DB_Name() + '/' + REPLACE(PM.Output_Folder_Name, '\', '/') AS Results_URL,
    PM.Processing_State, PM.Priority, 
    PM.Processing_Error_Code, PM.Processing_Warning_Code, 
    PM.PM_Created, PM.PM_Start, PM.PM_Finish, 
    PM.PM_AssignedProcessorName, PM.MD_ID
FROM T_Peak_Matching_Task PM
     LEFT OUTER JOIN T_FTICR_Analysis_Description FAD
       ON FAD.Job = PM.Job

GO
GRANT VIEW DEFINITION ON [dbo].[V_Peak_Matching_Task] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[V_Peak_Matching_Task] TO [MTS_DB_Lite] AS [dbo]
GO
