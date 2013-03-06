/****** Object:  View [dbo].[V_GANET_Peptides] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW V_GANET_Peptides
AS
-- Warning: This view can run very slowly
-- Instead, use stored procedure ExportGANETPeptideFile
--   which creates custom views for exporting the data
SELECT Pep.Job,
       Pep.Scan_Number,
       Seq.Clean_Sequence,
       CASE
           WHEN Len(IsNull(Seq.Mod_Description, '')) = 0 THEN 'none'
           ELSE Seq.Mod_Description
       END AS Mod_Description,
       Pep.Seq_ID,
       Pep.Charge_State,
       CONVERT(real, Pep.MH) AS MH,
       SS.XCorr AS Normalized_Score,
       SS.DeltaCn,
       CONVERT(real, SS.Sp) AS Sp,
       Seq.Cleavage_State_Max,
       Pep.Scan_Time_Peak_Apex,
       SD.MSGF_SpecProb
FROM dbo.T_Analysis_Description TAD
     INNER JOIN dbo.T_Peptides Pep
                INNER JOIN dbo.T_Sequence Seq
                  ON Pep.Seq_ID = Seq.Seq_ID
       ON TAD.Job = Pep.Job
     INNER JOIN dbo.T_Score_Sequest SS 
       ON Pep.Peptide_ID = SS.Peptide_ID
     INNER JOIN dbo.T_Score_Discriminant SD 
       ON Pep.Peptide_ID = SD.Peptide_ID
WHERE (TAD.ResultType = 'Peptide_Hit')
UNION
SELECT Pep.Job,
       Pep.Scan_Number,
       Seq.Clean_Sequence,
       CASE
           WHEN Len(IsNull(Seq.Mod_Description, '')) = 0 THEN 'none'
           ELSE Seq.Mod_Description
       END AS Mod_Description,
       Pep.Seq_ID,
       Pep.Charge_State,
       CONVERT(real, Pep.MH) AS MH,
       X.Normalized_Score AS Normalized_Score,
       0 AS DeltaCn,
       500 AS SP,
       Seq.Cleavage_State_Max,
       Pep.Scan_Time_Peak_Apex,
       SD.MSGF_SpecProb
FROM T_Analysis_Description TAD
     INNER JOIN T_Peptides Pep
                INNER JOIN T_Sequence Seq
                  ON Pep.Seq_ID = Seq.Seq_ID
       ON TAD.Job = Pep.Job
     INNER JOIN T_Score_XTandem X
       ON Pep.Peptide_ID = X.Peptide_ID
     INNER JOIN dbo.T_Score_Discriminant SD 
       ON Pep.Peptide_ID = SD.Peptide_ID
WHERE (TAD.ResultType = 'XT_Peptide_Hit')
UNION
SELECT Pep.Job,
       Pep.Scan_Number,
       Seq.Clean_Sequence,
       CASE
           WHEN Len(IsNull(Seq.Mod_Description, '')) = 0 THEN 'none'
           ELSE Seq.Mod_Description
       END AS Mod_Description,
       Pep.Seq_ID,
       Pep.Charge_State,
       CONVERT(real, Pep.MH) AS MH,
       I.Normalized_Score AS Normalized_Score,
       0 AS DeltaCn,
       500 AS SP,
       Seq.Cleavage_State_Max,
       Pep.Scan_Time_Peak_Apex,
       SD.MSGF_SpecProb
FROM T_Analysis_Description TAD
     INNER JOIN T_Peptides Pep
                INNER JOIN T_Sequence Seq
                  ON Pep.Seq_ID = Seq.Seq_ID
       ON TAD.Job = Pep.Job
     INNER JOIN T_Score_Inspect I
       ON Pep.Peptide_ID = I.Peptide_ID
     INNER JOIN dbo.T_Score_Discriminant SD 
       ON Pep.Peptide_ID = SD.Peptide_ID
WHERE (TAD.ResultType = 'IN_Peptide_Hit')
UNION
SELECT Pep.Job,
       Pep.Scan_Number,
       Seq.Clean_Sequence,
       CASE
           WHEN Len(IsNull(Seq.Mod_Description, '')) = 0 THEN 'none'
           ELSE Seq.Mod_Description
       END AS Mod_Description,
       Pep.Seq_ID,
       Pep.Charge_State,
       CONVERT(real, Pep.MH) AS MH,
       M.Normalized_Score AS Normalized_Score,
       0 AS DeltaCn,
       500 AS SP,
       Seq.Cleavage_State_Max,
       Pep.Scan_Time_Peak_Apex,
       SD.MSGF_SpecProb
FROM T_Analysis_Description TAD
     INNER JOIN T_Peptides Pep
                INNER JOIN T_Sequence Seq
                  ON Pep.Seq_ID = Seq.Seq_ID
       ON TAD.Job = Pep.Job
     INNER JOIN T_Score_MSGFDB M
       ON Pep.Peptide_ID = M.Peptide_ID
     INNER JOIN dbo.T_Score_Discriminant SD 
       ON Pep.Peptide_ID = SD.Peptide_ID
WHERE (TAD.ResultType = 'MSG_Peptide_Hit')
UNION
SELECT Pep.Job,
       Pep.Scan_Number,
       Seq.Clean_Sequence,
       CASE
           WHEN Len(IsNull(Seq.Mod_Description, '')) = 0 THEN 'none'
           ELSE Seq.Mod_Description
       END AS Mod_Description,
       Pep.Seq_ID,
       Pep.Charge_State,
       CONVERT(real, Pep.MH) AS MH,
       M.Normalized_Score AS Normalized_Score,
       0 AS DeltaCn,
       500 AS SP,
       Seq.Cleavage_State_Max,
       Pep.Scan_Time_Peak_Apex,
       ISNULL(SD.MSGF_SpecProb, M.PValue) AS MSGF_SpecProb
FROM T_Analysis_Description TAD
     INNER JOIN T_Peptides Pep
                INNER JOIN T_Sequence Seq
                  ON Pep.Seq_ID = Seq.Seq_ID
       ON TAD.Job = Pep.Job
     INNER JOIN T_Score_MSAlign M
       ON Pep.Peptide_ID = M.Peptide_ID
     INNER JOIN dbo.T_Score_Discriminant SD 
       ON Pep.Peptide_ID = SD.Peptide_ID
WHERE (TAD.ResultType = 'MSA_Peptide_Hit')
GO
