/****** Object:  View [dbo].[V_PM_Results_Pairs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_PM_Results_Pairs]
AS
SELECT MMD.MD_ID, FUR.UMC_Ind AS UMC_Ind_Light, 
    FUR_Heavy.UMC_Ind AS UMC_Ind_Heavy, 
    FUR.Pair_UMC_Ind, FUR.Expression_Ratio, 
    FUR.Expression_Ratio_StDev, 
    FUR.Expression_Ratio_Charge_State_Basis_Count, 
    FUR.Expression_Ratio_Member_Basis_Count, 
    FURD.Mass_Tag_ID, FURD.Match_Score AS SLiC_Score, 
    FUR.Class_Mass AS Class_Mass_Light, 
    FUR_Heavy.Class_Mass AS Class_Mass_Heavy, 
    FUR.ElutionTime AS ElutionTime_Light, 
    FUR_Heavy.ElutionTime AS ElutionTime_Heavy, 
    FUR.Class_Abundance AS Class_Abundance_Light, 
    FUR_Heavy.Class_Abundance AS Class_Abundance_Heavy, 
    FUR.Member_Count_Used_For_Abu AS Count_Used_For_Abu_Light,
     FUR_Heavy.Member_Count_Used_For_Abu AS Count_Used_For_Abu_Heavy,
     FUR_Heavy.Class_Mass - FUR.Class_Mass AS Delta_Mass, 
    FUR_Heavy.ElutionTime - FUR.ElutionTime AS Delta_ElutionTime
FROM dbo.T_Match_Making_Description AS MMD INNER JOIN
    dbo.T_FTICR_UMC_Results AS FUR ON 
    MMD.MD_ID = FUR.MD_ID INNER JOIN
    dbo.T_FTICR_UMC_ResultDetails AS FURD ON 
    FUR.UMC_Results_ID = FURD.UMC_Results_ID INNER JOIN
    dbo.T_FTICR_UMC_Results AS FUR_Heavy ON 
    FUR.Pair_UMC_Ind = FUR_Heavy.Pair_UMC_Ind AND 
    FUR.UMC_Ind <> FUR_Heavy.UMC_Ind AND 
    FUR.MD_ID = FUR_Heavy.MD_ID
WHERE (FUR.Pair_UMC_Ind >= 0)

GO
