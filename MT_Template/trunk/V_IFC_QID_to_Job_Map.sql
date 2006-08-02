SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_IFC_QID_to_Job_Map]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_IFC_QID_to_Job_Map]
GO


CREATE VIEW dbo.V_IFC_QID_to_Job_Map
AS
SELECT QD.Quantitation_ID, QD.Quantitation_State, MMD.MD_ID, 
    FAD.Job, FAD.Dataset, FAD.Experiment, FAD.Instrument_Class, 
    FAD.Parameter_File_Name, MMD.Ini_File_Name, 
    FAD.Completed AS Job_Completed, 
    FAD.Dataset_Created_DMS
FROM dbo.T_Quantitation_Description QD INNER JOIN
    dbo.T_Quantitation_MDIDs QMDIDs ON 
    QD.Quantitation_ID = QMDIDs.Quantitation_ID INNER JOIN
    dbo.T_Match_Making_Description MMD ON 
    QMDIDs.MD_ID = MMD.MD_ID INNER JOIN
    dbo.T_FTICR_Analysis_Description FAD ON 
    MMD.MD_Reference_Job = FAD.Job


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

