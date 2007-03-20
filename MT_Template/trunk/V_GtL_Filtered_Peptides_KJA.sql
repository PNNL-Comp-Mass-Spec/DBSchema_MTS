/****** Object:  View [dbo].[V_GtL_Filtered_Peptides_KJA] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

create VIEW V_GtL_Filtered_Peptides_KJA
AS
SELECT     TOP 100 PERCENT dbo.T_Peptides.Peptide_ID, dbo.T_Peptides.Analysis_ID, dbo.T_Peptides.Scan_Number, dbo.T_Peptides.Charge_State, 
                      dbo.T_Peptides.Peptide, dbo.T_Proteins.Reference, dbo.T_Score_Sequest.XCorr, dbo.T_Score_Sequest.DeltaCn2, dbo.T_Score_Sequest.Sp, 
                      dbo.T_Score_Sequest.RankSp, dbo.T_Score_Sequest.RankXc, dbo.T_Peptides.Mass_Tag_ID, dbo.T_Mass_Tag_to_Protein_Map.Cleavage_State, 
                      dbo.T_Proteins.Ref_ID, dbo.T_Peptides.Peak_Area
FROM         dbo.T_Mass_Tags INNER JOIN
                      dbo.T_Peptides ON dbo.T_Mass_Tags.Mass_Tag_ID = dbo.T_Peptides.Mass_Tag_ID INNER JOIN
                      dbo.T_Score_Sequest ON dbo.T_Peptides.Peptide_ID = dbo.T_Score_Sequest.Peptide_ID INNER JOIN
                      dbo.T_Mass_Tag_to_Protein_Map ON dbo.T_Mass_Tags.Mass_Tag_ID = dbo.T_Mass_Tag_to_Protein_Map.Mass_Tag_ID INNER JOIN
                      dbo.T_Proteins ON dbo.T_Mass_Tag_to_Protein_Map.Ref_ID = dbo.T_Proteins.Ref_ID
WHERE     (dbo.T_Peptides.Charge_State = 1) AND (dbo.T_Peptides.Peptide LIKE '[rk-].%[rk].%') AND (dbo.T_Score_Sequest.XCorr >= 1.9) AND 
                      (dbo.T_Score_Sequest.DeltaCn2 >= 0.1) AND (dbo.T_Score_Sequest.RankXc = 1) OR
                      (dbo.T_Peptides.Charge_State = 2) AND (dbo.T_Peptides.Peptide LIKE '[rk-].%[rk].%') AND (dbo.T_Score_Sequest.XCorr >= 2.2) AND 
                      (dbo.T_Score_Sequest.DeltaCn2 >= 0.1) AND (dbo.T_Score_Sequest.RankXc = 1) OR
                      (dbo.T_Peptides.Charge_State = 3) AND (dbo.T_Peptides.Peptide LIKE '[rk-].%[rk].%') AND (dbo.T_Score_Sequest.XCorr >= 3.5) AND 
                      (dbo.T_Score_Sequest.DeltaCn2 >= 0.1) AND (dbo.T_Score_Sequest.RankXc = 1) OR
                      (dbo.T_Peptides.Charge_State = 1) AND (dbo.T_Peptides.Peptide LIKE '[rkfwyla-].%[rkfwyla].%' OR
                      dbo.T_Peptides.Peptide LIKE '%[rk].%') AND (dbo.T_Score_Sequest.XCorr >= 2.4) AND (dbo.T_Score_Sequest.DeltaCn2 >= 0.1) AND 
                      (dbo.T_Score_Sequest.RankXc = 1) OR
                      (dbo.T_Peptides.Charge_State = 2) AND (dbo.T_Peptides.Peptide LIKE '[rkfwyla-].%[rkfwyla].%' OR
                      dbo.T_Peptides.Peptide LIKE '%[rk].%') AND (dbo.T_Score_Sequest.XCorr >= 2.6) AND (dbo.T_Score_Sequest.DeltaCn2 >= 0.1) AND 
                      (dbo.T_Score_Sequest.RankXc = 1) OR
                      (dbo.T_Peptides.Charge_State = 3) AND (dbo.T_Peptides.Peptide LIKE '[rkfwyla-].%[rkfwyla].%' OR
                      dbo.T_Peptides.Peptide LIKE '%[rk].%') AND (dbo.T_Score_Sequest.XCorr >= 3.9) AND (dbo.T_Score_Sequest.DeltaCn2 >= 0.1) AND 
                      (dbo.T_Score_Sequest.RankXc = 1) OR
                      (dbo.T_Peptides.Peptide LIKE '[rk-].%[rk].%') AND (dbo.T_Score_Sequest.XCorr >= 2.6) AND (dbo.T_Score_Sequest.RankXc = 1) AND 
                      (dbo.T_Score_Sequest.Sp >= 500) OR
                      (dbo.T_Peptides.Peptide LIKE '[rkfwyla-].%[rkfwyla].%' OR
                      dbo.T_Peptides.Peptide LIKE '%[rk].%') AND (dbo.T_Score_Sequest.XCorr >= 2.8) AND (dbo.T_Score_Sequest.RankXc = 1) AND 
                      (dbo.T_Score_Sequest.Sp >= 500) OR
                      (dbo.T_Peptides.Peptide LIKE '[rk-].%[rk].%') AND (dbo.T_Score_Sequest.XCorr >= 1.2) AND (dbo.T_Score_Sequest.DeltaCn2 >= 0.2) AND 
                      (dbo.T_Score_Sequest.RankXc = 1) OR
                      (dbo.T_Peptides.Peptide LIKE '[rkfwyla-].%[rkfwyla].%' OR
                      dbo.T_Peptides.Peptide LIKE '%[rk].%') AND (dbo.T_Score_Sequest.XCorr >= 1.8) AND (dbo.T_Score_Sequest.DeltaCn2 >= 0.2) AND 
                      (dbo.T_Score_Sequest.RankXc = 1) OR
                      (dbo.T_Score_Sequest.XCorr >= 5) AND (dbo.T_Score_Sequest.DeltaCn2 = 1) AND (dbo.T_Score_Sequest.RankXc = 1)
ORDER BY dbo.T_Proteins.Reference

GO
