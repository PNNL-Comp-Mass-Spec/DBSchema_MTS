SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_MSMS_Analysis_Jobs]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_MSMS_Analysis_Jobs]
GO


CREATE VIEW dbo.V_MSMS_Analysis_Jobs
AS
SELECT TOP 100 PERCENT TAD.Job, TAD.State, TAD.Dataset, 
    TAD.Dataset_ID, TAD.Dataset_Created_DMS, TAD.Experiment, 
    TAD.Campaign, TAD.Organism, TAD.Instrument, 
    TAD.Instrument_Class, TAD.Analysis_Tool, 
    TAD.Parameter_File_Name, TAD.Settings_File_Name, 
    TAD.Organism_DB_Name, TAD.Completed, TAD.ResultType, 
    TAD.Separation_Sys_Type, TAD.Internal_Standard, 
    DMS_Enzymes.Enzyme_Name, TAD.Labelling, 
    ASN.AD_State_Name AS State_Name, 
    PDL.PDB_Name AS Peptide_DB_Name, 
    TAD.Vol_Client + TAD.Storage_Path + TAD.Dataset_Folder + '\' + TAD.Results_Folder
     + '\' AS Results_Folder_Path
FROM dbo.T_Analysis_Description TAD INNER JOIN
    dbo.T_Analysis_State_Name ASN ON 
    TAD.State = ASN.AD_State_ID LEFT OUTER JOIN
    MT_Main.dbo.V_DMS_Enzymes DMS_Enzymes ON 
    TAD.Enzyme_ID = DMS_Enzymes.Enzyme_ID LEFT OUTER JOIN
    MT_Main.dbo.T_Peptide_Database_List PDL ON 
    TAD.PDB_ID = PDL.PDB_ID
ORDER BY TAD.Job


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

