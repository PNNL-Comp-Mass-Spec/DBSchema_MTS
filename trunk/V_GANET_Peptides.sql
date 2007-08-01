/****** Object:  View [dbo].[V_GANET_Peptides] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW dbo.V_GANET_Peptides
AS
SELECT TOP 100 PERCENT Analysis_ID, Scan_Number, Peptide, 
    ISNULL(Mod_Description, 'none') AS Mod_Description, 
    Mass_Tag_ID, Charge_State, CONVERT(real, MH) AS MH, 
    Normalized_Score, DeltaCn, CONVERT(real, Sp) AS Sp, 
    MAX(Cleavage_State) AS Cleavage_State_Max, 
    Scan_Time_Peak_Apex, DiscriminantScoreNorm
FROM (SELECT P.Analysis_ID, P.Scan_Number, MT.Peptide, 
          CASE WHEN Len(IsNull(MT.Mod_Description, '')) 
          = 0 THEN 'none' ELSE MT.Mod_Description END AS Mod_Description,
           MT.Mass_Tag_ID, P.Charge_State, P.MH, 
          SS.XCorr AS Normalized_Score, SS.DeltaCn, SS.Sp, 
          ISNULL(CONVERT(smallint, MTPM.Cleavage_State), 
          - 1) AS Cleavage_State, P.Scan_Time_Peak_Apex, 
          SD.DiscriminantScoreNorm
      FROM T_Mass_Tags MT INNER JOIN
          T_Peptides P ON 
          MT.Mass_Tag_ID = P.Mass_Tag_ID INNER JOIN
          T_Score_Sequest SS ON 
          P.Peptide_ID = SS.Peptide_ID INNER JOIN
          T_Score_Discriminant SD ON 
          P.Peptide_ID = SD.Peptide_ID INNER JOIN
          T_Analysis_Description TAD ON 
          P.Analysis_ID = TAD.Job LEFT OUTER JOIN
          T_Mass_Tag_to_Protein_Map MTPM ON 
          MT.Mass_Tag_ID = MTPM.Mass_Tag_ID
      WHERE (TAD.ResultType = 'Peptide_Hit') AND 
          (SD.DiscriminantScoreNorm >= 0.25)
      UNION
      SELECT P.Analysis_ID, P.Scan_Number, MT.Peptide, 
          CASE WHEN Len(IsNull(MT.Mod_Description, '')) 
          = 0 THEN 'none' ELSE MT.Mod_Description END AS Mod_Description,
           MT.Mass_Tag_ID, P.Charge_State, P.MH, 
          X.Normalized_Score AS Normalized_Score, 
          0 AS DeltaCn, 500 AS Sp, ISNULL(CONVERT(smallint, 
          MTPM.Cleavage_State), - 1) AS Cleavage_State, 
          P.Scan_Time_Peak_Apex, 
          SD.DiscriminantScoreNorm
      FROM T_Mass_Tags MT INNER JOIN
          T_Peptides P ON 
          MT.Mass_Tag_ID = P.Mass_Tag_ID INNER JOIN
          T_Score_XTandem X ON 
          P.Peptide_ID = X.Peptide_ID INNER JOIN
          T_Score_Discriminant SD ON 
          P.Peptide_ID = SD.Peptide_ID INNER JOIN
          T_Analysis_Description TAD ON 
          P.Analysis_ID = TAD.Job LEFT OUTER JOIN
          T_Mass_Tag_to_Protein_Map MTPM ON 
          MT.Mass_Tag_ID = MTPM.Mass_Tag_ID
      WHERE (TAD.ResultType = 'XT_Peptide_Hit') AND 
          (SD.DiscriminantScoreNorm >= 0.25)) LookupQ
GROUP BY Analysis_ID, Scan_Number, Peptide, Mod_Description, 
    Mass_Tag_ID, Charge_State, MH, Normalized_Score, DeltaCn, 
    Sp, Scan_Time_Peak_Apex, DiscriminantScoreNorm
ORDER BY Analysis_ID, Scan_Number, Charge_State, 
    Normalized_Score DESC


GO
