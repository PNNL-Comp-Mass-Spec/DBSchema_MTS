/****** Object:  View [dbo].[V_SIC_Stats_for_PeptideHit_Job] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW V_SIC_Stats_for_PeptideHit_Job
AS
SELECT SJPM.Dataset_ID,
       Pep.Job,
       SJPM.SIC_Job,
       DSSIC_1.Parent_Ion_Index,
       DSSIC_1.Survey_Scan_Number,
       DSSIC_1.Frag_Scan_Number,
       DSSIC_1.Optimal_Peak_Apex_Scan_Number,
       DSScans.Scan_Time AS Optimal_Peak_Apex_Time,
       DSSIC_1.Peak_Area,
       DSSIC_1.Peak_SN_Ratio,
       Pep.Peptide_ID,
       DSSIC_1.MZ,
       ROUND((Pep.MH + Pep.Charge_State - 1) / Pep.Charge_State, 3) AS Apparent_MZ,
       Pep.MH,
       Pep.Charge_State,
       SS.XCorr,
       SS.DeltaCn
FROM V_SIC_Job_to_PeptideHit_Map SJPM
     INNER JOIN T_Peptides Pep
       ON SJPM.Job = Pep.Job
     INNER JOIN T_Score_Sequest SS
       ON Pep.Peptide_ID = SS.Peptide_ID
     INNER JOIN T_Dataset_Stats_SIC DSSIC_1
       ON SJPM.SIC_Job = DSSIC_1.Job AND
          Pep.Scan_Number = DSSIC_1.Frag_Scan_Number
     INNER JOIN T_Dataset_Stats_Scans DSScans
       ON DSSIC_1.Job = DSScans.Job AND
          DSSIC_1.Optimal_Peak_Apex_Scan_Number = DSScans.Scan_Number

GO
