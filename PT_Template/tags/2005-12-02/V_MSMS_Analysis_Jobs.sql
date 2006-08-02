SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_MSMS_Analysis_Jobs]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_MSMS_Analysis_Jobs]
GO


CREATE VIEW dbo.V_MSMS_Analysis_Jobs
AS
SELECT TOP 100 PERCENT TAD.Job, TAD.Process_State, 
    TAD.Dataset, TAD.Dataset_ID, 
    DS.Created_DMS AS Dataset_Created_DMS, TAD.Experiment, 
    TAD.Campaign, TAD.Organism, TAD.Instrument, 
    TAD.Instrument_Class, TAD.Analysis_Tool, 
    TAD.Parameter_File_Name, TAD.Settings_File_Name, 
    TAD.Organism_DB_Name, TAD.Completed, TAD.ResultType, 
    TAD.Separation_Sys_Type, TAD.Internal_Standard, 
    MT_Main.dbo.V_DMS_Enzymes.Enzyme_Name, 
    TAD.Labelling, 
    dbo.T_Process_State.Name AS Process_State_Name, 
    DB_NAME() AS Peptide_DB_Name, 
    TAD.Vol_Client + TAD.Storage_Path + TAD.Dataset_Folder + '\' + TAD.Results_Folder
     + '\' AS Results_Folder_Path
FROM dbo.T_Analysis_Description TAD INNER JOIN
    dbo.T_Process_State ON 
    TAD.Process_State = dbo.T_Process_State.ID LEFT OUTER JOIN
    MT_Main.dbo.V_DMS_Enzymes ON 
    TAD.Enzyme_ID = MT_Main.dbo.V_DMS_Enzymes.Enzyme_ID LEFT
     OUTER JOIN
    dbo.T_Datasets DS ON 
    TAD.Dataset_ID = DS.Dataset_ID
ORDER BY TAD.Job


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

