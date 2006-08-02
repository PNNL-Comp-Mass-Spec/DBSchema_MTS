SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_SIC_Stats_for_PeptideHit_Job]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_SIC_Stats_for_PeptideHit_Job]
GO


create VIEW dbo.V_SIC_Stats_for_PeptideHit_Job
AS
SELECT TOP 100 PERCENT dbo.V_SIC_Job_to_PeptideHit_Map.Dataset_ID,
     dbo.T_Peptides.Analysis_ID, 
    dbo.V_SIC_Job_to_PeptideHit_Map.SIC_Job, 
    dbo.T_Dataset_Stats_SIC.Parent_Ion_Index, 
    dbo.T_Dataset_Stats_SIC.Survey_Scan_Number, 
    dbo.T_Dataset_Stats_SIC.Frag_Scan_Number, 
    dbo.T_Dataset_Stats_SIC.Optimal_Peak_Apex_Scan_Number, 
    dbo.T_Dataset_Stats_Scans.Scan_Time AS Optimal_Peak_Apex_Time,
     dbo.T_Dataset_Stats_SIC.Peak_Area, 
    dbo.T_Dataset_Stats_SIC.Peak_SN_Ratio, 
    dbo.T_Peptides.Peptide_ID, dbo.T_Dataset_Stats_SIC.MZ, 
    ROUND((dbo.T_Peptides.MH + dbo.T_Peptides.Charge_State - 1)
     / dbo.T_Peptides.Charge_State, 3) AS Apparent_MZ, 
    dbo.T_Peptides.MH, dbo.T_Peptides.Charge_State, 
    dbo.T_Score_Sequest.XCorr, 
    dbo.T_Score_Sequest.DeltaCn
FROM dbo.V_SIC_Job_to_PeptideHit_Map INNER JOIN
    dbo.T_Peptides ON 
    dbo.V_SIC_Job_to_PeptideHit_Map.Job = dbo.T_Peptides.Analysis_ID
     INNER JOIN
    dbo.T_Score_Sequest ON 
    dbo.T_Peptides.Peptide_ID = dbo.T_Score_Sequest.Peptide_ID INNER
     JOIN
    dbo.T_Dataset_Stats_SIC ON 
    dbo.V_SIC_Job_to_PeptideHit_Map.SIC_Job = dbo.T_Dataset_Stats_SIC.Job
     AND 
    dbo.T_Peptides.Scan_Number = dbo.T_Dataset_Stats_SIC.Frag_Scan_Number
     INNER JOIN
    dbo.T_Dataset_Stats_Scans ON 
    dbo.T_Dataset_Stats_SIC.Job = dbo.T_Dataset_Stats_Scans.Job
     AND 
    dbo.T_Dataset_Stats_SIC.Optimal_Peak_Apex_Scan_Number = dbo.T_Dataset_Stats_Scans.Scan_Number

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

