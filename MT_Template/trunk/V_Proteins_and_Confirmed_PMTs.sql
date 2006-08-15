/****** Object:  View [dbo].[V_Proteins_and_Confirmed_PMTs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbo.V_Proteins_and_Confirmed_PMTs
AS
SELECT MTPM.Ref_ID, MT.Mass_Tag_ID
FROM dbo.T_FTICR_UMC_Results UR INNER JOIN
    dbo.T_FTICR_UMC_ResultDetails URD ON 
    UR.UMC_Results_ID = URD.UMC_Results_ID INNER JOIN
    dbo.T_Mass_Tags MT ON 
    URD.Mass_Tag_ID = MT.Mass_Tag_ID INNER JOIN
    dbo.T_Match_Making_Description MMD ON 
    UR.MD_ID = MMD.MD_ID INNER JOIN
    dbo.T_Mass_Tag_to_Protein_Map MTPM ON 
    MT.Mass_Tag_ID = MTPM.Mass_Tag_ID
WHERE (URD.Match_State = 6) AND (MMD.MD_State <> 6)
GROUP BY MT.Mass_Tag_ID, MTPM.Ref_ID

GO
