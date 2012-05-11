/****** Object:  View [dbo].[V_Sequest_vs_XTandem] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW V_Sequest_vs_XTandem
AS
SELECT SequestQ.Dataset_ID, 
    SequestQ.Scan_Number, SequestQ.Charge_State, 
    SequestQ.Mass_Tag_ID, SequestQ.XCorr, SequestQ.DeltaCn, 
    SequestQ.DeltaCn2, XTandemQ.XTandem_Normalized_Score, 
    XTandemQ.Hyperscore, 
    XTandemQ.DeltaCn2 AS XT_DeltaCn2, 
    XTandemQ.Log_EValue
FROM (SELECT TAD.Dataset_ID, P.Scan_Number, P.Charge_State, 
          P.Mass_Tag_ID, SS.XCorr, SS.DeltaCn, 
          SS.DeltaCn2
      FROM T_Analysis_Description TAD INNER JOIN
          T_Peptides P ON 
          TAD.Job = P.Job INNER JOIN
          T_Score_Sequest SS ON 
          P.Peptide_ID = SS.Peptide_ID
      WHERE (TAD.ResultType = 'Peptide_Hit')) 
    SequestQ INNER JOIN
        (SELECT TAD.Dataset_ID, P.Scan_Number, P.Charge_State, 
           P.Mass_Tag_ID, X.Hyperscore, X.DeltaCn2, 
           X.Log_EValue, 
           X.Normalized_Score AS XTandem_Normalized_Score
      FROM T_Analysis_Description TAD INNER JOIN
           T_Peptides P ON 
           TAD.Job = P.Job INNER JOIN
           T_Score_XTandem X ON 
           P.Peptide_ID = X.Peptide_ID
      WHERE (TAD.ResultType = 'XT_Peptide_Hit')) XTandemQ ON 
    SequestQ.Charge_State = XTandemQ.Charge_State AND 
    SequestQ.Dataset_ID = XTandemQ.Dataset_ID AND 
    SequestQ.Scan_Number = XTandemQ.Scan_Number AND 
    SequestQ.Mass_Tag_ID = XTandemQ.Mass_Tag_ID

GO
