SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Peptide_Score_Filter_Report]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Peptide_Score_Filter_Report]
GO

CREATE VIEW dbo.V_Peptide_Score_Filter_Report
AS
SELECT TOP 100 PERCENT dbo.T_PMT_Quality_Score_Sets.PMT_Quality_Score_Set_ID,
     dbo.T_PMT_Quality_Score_Sets.PMT_Quality_Score_Set_Name,
     dbo.T_PMT_Quality_Score_Sets.PMT_Quality_Score_Set_Description,
     dbo.T_PMT_Quality_Score_SetDetails.Evaluation_Order, 
    dbo.T_PMT_Quality_Score_SetDetails.Analysis_Count_Comparison,
     dbo.T_PMT_Quality_Score_SetDetails.Analysis_Count_Threshold,
     dbo.T_PMT_Quality_Score_SetDetails.Charge_State_Comparison,
     dbo.T_PMT_Quality_Score_SetDetails.Charge_State_Threshold,
     dbo.T_PMT_Quality_Score_SetDetails.High_Normalized_Score_Comparison,
     dbo.T_PMT_Quality_Score_SetDetails.High_Normalized_Score_Threshold,
     dbo.T_PMT_Quality_Score_SetDetails.Cleavage_State_Comparison,
     dbo.T_PMT_Quality_Score_SetDetails.Cleavage_State_Threshold,
     dbo.T_PMT_Quality_Score_SetDetails.Peptide_Length_Comparison,
     dbo.T_PMT_Quality_Score_SetDetails.Peptide_Length_Threshold,
     dbo.T_PMT_Quality_Score_SetDetails.Mass_Comparison, 
    dbo.T_PMT_Quality_Score_SetDetails.Mass_Threshold, 
    dbo.T_PMT_Quality_Score_SetDetails.DelCN_Comparison, 
    dbo.T_PMT_Quality_Score_SetDetails.DelCN_Threshold, 
    dbo.T_PMT_Quality_Score_SetDetails.DelCN2_Comparison, 
    dbo.T_PMT_Quality_Score_SetDetails.DelCN2_Threshold
FROM dbo.T_PMT_Quality_Score_Sets INNER JOIN
    dbo.T_PMT_Quality_Score_SetDetails ON 
    dbo.T_PMT_Quality_Score_Sets.PMT_Quality_Score_Set_ID = dbo.T_PMT_Quality_Score_SetDetails.PMT_Quality_Score_Set_ID
ORDER BY dbo.T_PMT_Quality_Score_Sets.PMT_Quality_Score_Set_ID,
     dbo.T_PMT_Quality_Score_SetDetails.Evaluation_Order

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

