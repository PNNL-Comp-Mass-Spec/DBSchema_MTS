/****** Object:  View [dbo].[V_GtL_Filtered_Peptides_KJA] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW V_GtL_Filtered_Peptides_KJA
AS
SELECT Pep.Peptide_ID,
       Pep.Job AS Analysis_ID,
       Pep.Scan_Number,
       Pep.Charge_State,
       Pep.Peptide,
       Prot.Reference,
       SS.XCorr,
       SS.DeltaCn2,
       SS.Sp,
       SS.RankSp,
       SS.RankXc,
       Pep.Mass_Tag_ID,
       MTPM.Cleavage_State,
       Prot.Ref_ID,
       Pep.Peak_Area
FROM dbo.T_Mass_Tags MT
     INNER JOIN dbo.T_Peptides Pep
       ON MT.Mass_Tag_ID = Pep.Mass_Tag_ID
     INNER JOIN dbo.T_Score_Sequest SS
       ON Pep.Peptide_ID = SS.Peptide_ID
     INNER JOIN dbo.T_Mass_Tag_to_Protein_Map MTPM
       ON MT.Mass_Tag_ID = MTPM.Mass_Tag_ID
     INNER JOIN dbo.T_Proteins Prot
       ON MTPM.Ref_ID = Prot.Ref_ID
WHERE (SS.RankXC = 1 AND Pep.Peptide LIKE '[rk-].%[rk].%' AND 
          (
		   (Pep.Charge_State = 1 AND SS.XCorr >= 1.9 AND SS.DeltaCn2 >= 0.1) OR
		   (Pep.Charge_State = 2 AND SS.XCorr >= 2.2 AND SS.DeltaCn2 >= 0.1) OR
		   (Pep.Charge_State >= 3 AND SS.XCorr >= 3.5 AND SS.DeltaCn2 >= 0.1) OR
		   (SS.XCorr >= 2.6 AND SS.Sp >= 500) OR
		   (SS.XCorr >= 1.2 AND SS.DeltaCn2 >= 0.2)
          )
	   ) OR
       (SS.RankXc = 1 AND (Pep.Peptide LIKE '[rkfwyla-].%[rkfwyla].%' OR Pep.Peptide LIKE '%[rk].%') AND
          (
		   (Pep.Charge_State = 1 AND SS.XCorr >= 2.4 AND SS.DeltaCn2 >= 0.1) OR
		   (Pep.Charge_State = 2 AND SS.XCorr >= 2.6 AND SS.DeltaCn2 >= 0.1) OR
		   (Pep.Charge_State >= 3 AND SS.XCorr >= 3.9 AND SS.DeltaCn2 >= 0.1) OR
		   (SS.XCorr >= 2.8 AND SS.Sp >= 500) OR
		   (SS.XCorr >= 1.8 AND SS.DeltaCn2 >= 0.2)
          )
       ) OR
       (SS.RankXC = 1 AND SS.XCorr >= 5)

GO
GRANT VIEW DEFINITION ON [dbo].[V_GtL_Filtered_Peptides_KJA] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[V_GtL_Filtered_Peptides_KJA] TO [MTS_DB_Lite] AS [dbo]
GO
