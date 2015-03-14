/****** Object:  View [dbo].[V_PM_Results_Pairs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_PM_Results_Pairs]
AS
SELECT MMD.MD_ID,
       FUR_Light.UMC_Ind AS UMC_Ind_Light,
       FUR_Heavy.UMC_Ind AS UMC_Ind_Heavy,
       FUR_Light.Pair_UMC_Ind,
       FUR_Light.Expression_Ratio,
       FUR_Light.Expression_Ratio_StDev,
       FUR_Light.Expression_Ratio_Charge_State_Basis_Count,
       FUR_Light.Expression_Ratio_Member_Basis_Count,
       FURD.Mass_Tag_ID,
       FURD.Match_Score AS SLiC_Score,
       FUR_Light.Class_Mass AS Class_Mass_Light,
       FUR_Heavy.Class_Mass AS Class_Mass_Heavy,
       FUR_Light.ElutionTime AS ElutionTime_Light,
       FUR_Heavy.ElutionTime AS ElutionTime_Heavy,
       FUR_Light.Class_Abundance AS Class_Abundance_Light,
       FUR_Heavy.Class_Abundance AS Class_Abundance_Heavy,
       FUR_Light.Member_Count_Used_For_Abu AS Count_Used_For_Abu_Light,
       FUR_Heavy.Member_Count_Used_For_Abu AS Count_Used_For_Abu_Heavy,
       FUR_Heavy.Class_Mass - FUR_Light.Class_Mass AS Delta_Mass,
       FUR_Heavy.ElutionTime - FUR_Light.ElutionTime AS Delta_ElutionTime
FROM dbo.T_Match_Making_Description AS MMD
     INNER JOIN dbo.T_FTICR_UMC_Results AS FUR_Light
       ON MMD.MD_ID = FUR_Light.MD_ID
     INNER JOIN dbo.T_FTICR_UMC_ResultDetails AS FURD
       ON FUR_Light.UMC_Results_ID = FURD.UMC_Results_ID
     INNER JOIN dbo.T_FTICR_UMC_Results AS FUR_Heavy
       ON FUR_Light.Pair_UMC_Ind = FUR_Heavy.Pair_UMC_Ind AND
          FUR_Light.UMC_Ind <> FUR_Heavy.UMC_Ind AND
          FUR_Light.MD_ID = FUR_Heavy.MD_ID
WHERE (FUR_Light.Pair_UMC_Ind >= 0) AND (FUR_Light.FPR_Type_ID = 0 OR FUR_Light.FPR_Type_ID % 2 = 1)
UNION
SELECT MMD.MD_ID,
       FUR_Light.UMC_Ind AS UMC_Ind_Light,
       FUR_Heavy.UMC_Ind AS UMC_Ind_Heavy,
       FUR_Heavy.Pair_UMC_Ind,
       FUR_Heavy.Expression_Ratio,
       FUR_Heavy.Expression_Ratio_StDev,
       FUR_Heavy.Expression_Ratio_Charge_State_Basis_Count,
       FUR_Heavy.Expression_Ratio_Member_Basis_Count,
       FURD.Mass_Tag_ID,
       FURD.Match_Score AS SLiC_Score,
       FUR_Light.Class_Mass AS Class_Mass_Light,
       FUR_Heavy.Class_Mass AS Class_Mass_Heavy,
       FUR_Light.ElutionTime AS ElutionTime_Light,
       FUR_Heavy.ElutionTime AS ElutionTime_Heavy,
       FUR_Light.Class_Abundance AS Class_Abundance_Light,
       FUR_Heavy.Class_Abundance AS Class_Abundance_Heavy,
       FUR_Light.Member_Count_Used_For_Abu AS Count_Used_For_Abu_Light,
       FUR_Heavy.Member_Count_Used_For_Abu AS Count_Used_For_Abu_Heavy,
       FUR_Heavy.Class_Mass - FUR_Light.Class_Mass AS Delta_Mass,
       FUR_Heavy.ElutionTime - FUR_Light.ElutionTime AS Delta_ElutionTime
FROM dbo.T_Match_Making_Description AS MMD
     INNER JOIN dbo.T_FTICR_UMC_Results AS FUR_Heavy
       ON MMD.MD_ID = FUR_Heavy.MD_ID
     INNER JOIN dbo.T_FTICR_UMC_ResultDetails AS FURD
       ON FUR_Heavy.UMC_Results_ID = FURD.UMC_Results_ID
     INNER JOIN dbo.T_FTICR_UMC_Results AS FUR_Light
       ON FUR_Heavy.Pair_UMC_Ind = FUR_Light.Pair_UMC_Ind AND
          FUR_Heavy.UMC_Ind <> FUR_Light.UMC_Ind AND
          FUR_Heavy.MD_ID = FUR_Light.MD_ID
WHERE (FUR_Heavy.Pair_UMC_Ind >= 0) AND (FUR_Heavy.FPR_Type_ID > 0 AND FUR_Heavy.FPR_Type_ID % 2 = 0)

GO
GRANT VIEW DEFINITION ON [dbo].[V_PM_Results_Pairs] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[V_PM_Results_Pairs] TO [MTS_DB_Lite] AS [dbo]
GO
