SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_GANET_Peptides]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_GANET_Peptides]
GO


CREATE VIEW dbo.V_GANET_Peptides
AS
SELECT TOP 100 PERCENT Analysis_ID, Scan_Number, Peptide, 
    ISNULL(Mod_Description, 'none') AS Mod_Description, 
    Mass_Tag_ID, Charge_State, CONVERT(real, MH) AS MH, 
    XCorr, DeltaCn, CONVERT(real, Sp) AS Sp, 
    MAX(Cleavage_State) AS Cleavage_State_Max, 
    Scan_Time_Peak_Apex, DiscriminantScoreNorm
FROM (SELECT T_Peptides.Analysis_ID, T_Peptides.Scan_Number, 
          T_Mass_Tags.Peptide, 
          CASE WHEN Len(IsNull(T_Mass_Tags.Mod_Description, 
          '')) 
          = 0 THEN 'none' ELSE T_Mass_Tags.Mod_Description END
           AS Mod_Description, T_Mass_Tags.Mass_Tag_ID, 
          T_Peptides.Charge_State, T_Peptides.MH, 
          T_Score_Sequest.XCorr, T_Score_Sequest.DeltaCn, 
          T_Score_Sequest.Sp, ISNULL(CONVERT(smallint, 
          T_Mass_Tag_to_Protein_Map.Cleavage_State), - 1) 
          AS Cleavage_State, 
          T_Peptides.Scan_Time_Peak_Apex, 
          T_Score_Discriminant.DiscriminantScoreNorm
      FROM T_Mass_Tags INNER JOIN
          T_Peptides ON 
          T_Mass_Tags.Mass_Tag_ID = T_Peptides.Mass_Tag_ID
           INNER JOIN
          T_Score_Sequest ON 
          T_Peptides.Peptide_ID = T_Score_Sequest.Peptide_ID INNER
           JOIN
          T_Score_Discriminant ON 
          T_Peptides.Peptide_ID = T_Score_Discriminant.Peptide_ID
           LEFT OUTER JOIN
          T_Mass_Tag_to_Protein_Map ON 
          T_Mass_Tags.Mass_Tag_ID = T_Mass_Tag_to_Protein_Map.Mass_Tag_ID
      WHERE T_Score_Discriminant.DiscriminantScoreNorm >= 0.25)
     LookupQ
GROUP BY Analysis_ID, Scan_Number, Peptide, Mod_Description, 
    Mass_Tag_ID, Charge_State, MH, XCorr, DeltaCn, Sp, 
    Scan_Time_Peak_Apex, DiscriminantScoreNorm
ORDER BY Analysis_ID, Scan_Number, Charge_State, XCorr DESC


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

