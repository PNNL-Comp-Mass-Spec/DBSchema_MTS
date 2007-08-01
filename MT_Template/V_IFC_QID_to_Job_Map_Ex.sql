/****** Object:  View [dbo].[V_IFC_QID_to_Job_Map_Ex] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW dbo.V_IFC_QID_to_Job_Map_Ex
AS
SELECT QD.Quantitation_ID, QD.Quantitation_State, MMD.MD_ID, 
    FAD.Job, FAD.Dataset, FAD.Experiment, 
    FAD.Instrument AS InstrumentName, 
    FAD.Instrument_Class AS InstrumentClass, 
    FAD.Parameter_File_Name, MMD.Ini_File_Name, 
    FAD.Completed AS Job_Completed, 
    FAD.Dataset_Created_DMS AS Dataset_Created
FROM dbo.T_Quantitation_Description QD INNER JOIN
    dbo.T_Quantitation_MDIDs QMDIDs ON 
    QD.Quantitation_ID = QMDIDs.Quantitation_ID INNER JOIN
    dbo.T_Match_Making_Description MMD ON 
    QMDIDs.MD_ID = MMD.MD_ID INNER JOIN
    dbo.T_FTICR_Analysis_Description FAD ON 
    MMD.MD_Reference_Job = FAD.Job


GO
