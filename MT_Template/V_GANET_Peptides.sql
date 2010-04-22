/****** Object:  View [dbo].[V_GANET_Peptides] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE VIEW V_GANET_Peptides
AS
SELECT Analysis_ID,
       Scan_Number,
       Peptide,
       ISNULL(Mod_Description, 'none') AS Mod_Description,
       Mass_Tag_ID,
       Charge_State,
       CONVERT(real, MH) AS MH,
       Normalized_Score,
       DeltaCn,
       CONVERT(real, Sp) AS Sp,
       MAX(Cleavage_State) AS Cleavage_State_Max,
       Scan_Time_Peak_Apex,
       DiscriminantScoreNorm
FROM (SELECT Pep.Analysis_ID,
             Pep.Scan_Number,
             MT.Peptide,
             CASE WHEN Len(IsNull(MT.Mod_Description, '')) = 0 THEN 'none'
             ELSE MT.Mod_Description END AS Mod_Description,
             MT.Mass_Tag_ID,
             Pep.Charge_State,
             Pep.MH,
             SS.XCorr AS Normalized_Score,
             SS.DeltaCn,
             SS.Sp,
             ISNULL(CONVERT(smallint, MTPM.Cleavage_State), - 1) AS Cleavage_State,
             Pep.Scan_Time_Peak_Apex,
             SD.DiscriminantScoreNorm
      FROM T_Mass_Tags MT
           INNER JOIN T_Peptides Pep
             ON MT.Mass_Tag_ID = Pep.Mass_Tag_ID
           INNER JOIN T_Score_Sequest SS
             ON Pep.Peptide_ID = SS.Peptide_ID
           INNER JOIN T_Score_Discriminant SD
             ON Pep.Peptide_ID = SD.Peptide_ID
           INNER JOIN T_Analysis_Description TAD
             ON Pep.Analysis_ID = TAD.Job
           LEFT OUTER JOIN T_Mass_Tag_to_Protein_Map MTPM
             ON MT.Mass_Tag_ID = MTPM.Mass_Tag_ID
      WHERE (TAD.ResultType = 'Peptide_Hit') AND
            (IsNull(SD.DiscriminantScoreNorm, 0.25) >= 0.25)
      UNION
      SELECT Pep.Analysis_ID,
             Pep.Scan_Number,
             MT.Peptide,
             CASE WHEN Len(IsNull(MT.Mod_Description, '')) = 0 THEN 'none'
             ELSE MT.Mod_Description END AS Mod_Description,
             MT.Mass_Tag_ID,
             Pep.Charge_State,
             Pep.MH,
             X.Normalized_Score AS Normalized_Score,
             0 AS DeltaCn,
             500 AS Sp,
             ISNULL(CONVERT(smallint, MTPM.Cleavage_State), - 1) AS Cleavage_State,
             Pep.Scan_Time_Peak_Apex,
             SD.DiscriminantScoreNorm
      FROM T_Mass_Tags MT
           INNER JOIN T_Peptides Pep
             ON MT.Mass_Tag_ID = Pep.Mass_Tag_ID
           INNER JOIN T_Score_XTandem X
             ON Pep.Peptide_ID = X.Peptide_ID
           INNER JOIN T_Score_Discriminant SD
             ON Pep.Peptide_ID = SD.Peptide_ID
           INNER JOIN T_Analysis_Description TAD
             ON Pep.Analysis_ID = TAD.Job
           LEFT OUTER JOIN T_Mass_Tag_to_Protein_Map MTPM
             ON MT.Mass_Tag_ID = MTPM.Mass_Tag_ID
      WHERE (TAD.ResultType = 'XT_Peptide_Hit') AND
            (IsNull(SD.DiscriminantScoreNorm, 0.25) >= 0.25) 
      UNION
      SELECT Pep.Analysis_ID,
             Pep.Scan_Number,
             MT.Peptide,
             CASE WHEN Len(IsNull(MT.Mod_Description, '')) = 0 THEN 'none'
             ELSE MT.Mod_Description END AS Mod_Description,
             MT.Mass_Tag_ID,
             Pep.Charge_State,
             Pep.MH,
             I.Normalized_Score AS Normalized_Score,
             0 AS DeltaCn,
             500 AS Sp,
             ISNULL(CONVERT(smallint, MTPM.Cleavage_State), - 1) AS Cleavage_State,
             Pep.Scan_Time_Peak_Apex,
             SD.DiscriminantScoreNorm
      FROM T_Mass_Tags MT
           INNER JOIN T_Peptides Pep
             ON MT.Mass_Tag_ID = Pep.Mass_Tag_ID
           INNER JOIN T_Score_Inspect I
             ON Pep.Peptide_ID = I.Peptide_ID
           INNER JOIN T_Score_Discriminant SD
             ON Pep.Peptide_ID = SD.Peptide_ID
           INNER JOIN T_Analysis_Description TAD
             ON Pep.Analysis_ID = TAD.Job
           LEFT OUTER JOIN T_Mass_Tag_to_Protein_Map MTPM
             ON MT.Mass_Tag_ID = MTPM.Mass_Tag_ID
      WHERE (TAD.ResultType = 'IN_Peptide_Hit') AND
            (IsNull(SD.DiscriminantScoreNorm, 0.25) >= 0.25) ) LookupQ
GROUP BY Analysis_ID, Scan_Number, Peptide, Mod_Description, Mass_Tag_ID, Charge_State,
         MH, Normalized_Score, DeltaCn, Sp, Scan_Time_Peak_Apex, DiscriminantScoreNorm

GO
