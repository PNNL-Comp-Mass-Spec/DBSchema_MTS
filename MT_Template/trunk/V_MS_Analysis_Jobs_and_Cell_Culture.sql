SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_MS_Analysis_Jobs_and_Cell_Culture]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_MS_Analysis_Jobs_and_Cell_Culture]
GO


CREATE VIEW dbo.V_MS_Analysis_Jobs_and_Cell_Culture
AS
SELECT TOP 100 PERCENT CASE WHEN DCC.CellCulture IS NULL 
    THEN '(none)' ELSE DCC.CellCulture END AS [Cell Culture], 
    FAD.Job, FAD.State, FAD.Dataset, FAD.Dataset_ID, 
    FAD.Dataset_Created_DMS, FAD.Experiment, FAD.Campaign, 
    FAD.Organism, FAD.Instrument, FAD.Instrument_Class, 
    FAD.Analysis_Tool, FAD.Parameter_File_Name, 
    FAD.Settings_File_Name, FAD.Organism_DB_Name, 
    FAD.Completed, FAD.ResultType, FAD.Separation_Sys_Type, 
    FAD.Internal_Standard, FAD.Labelling, 
    ASN.AD_State_Name AS State_Name, 
    FAD.Vol_Client + FAD.Storage_Path + FAD.Dataset_Folder + '\' + FAD.Results_Folder
     + '\' AS Results_Folder_Path
FROM dbo.T_FTICR_Analysis_Description FAD INNER JOIN
    dbo.T_Analysis_State_Name ASN ON 
    FAD.State = ASN.AD_State_ID LEFT OUTER JOIN
    MT_Main.dbo.V_DMS_Cell_Culture_Experiments_Import DCC ON
     FAD.Experiment = DCC.Experiment
ORDER BY FAD.Job


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

