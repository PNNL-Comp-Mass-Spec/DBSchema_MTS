/****** Object:  View [dbo].[V_DMS_Filter_Set_Report] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_DMS_Filter_Set_Report]
AS
SELECT Filter_Type_Name, Filter_Set_ID, 
    Filter_Set_Name, Filter_Set_Description, 
    Filter_Criteria_Group_ID, Spectrum_Count, Charge, 
    High_Normalized_Score, Cleavage_State, Terminus_State, 
    Peptide_Length, Mass, DelCn, DelCn2, Discriminant_Score, 
    NET_Difference_Absolute, Discriminant_Initial_Filter, 
    Protein_Count, XTandem_Hyperscore, XTandem_LogEValue, 
    Peptide_Prophet_Probability, RankScore,
    Inspect_MQScore, Inspect_TotalPRMScore, Inspect_FScore, Inspect_PValue
FROM GIGASAX.DMS5.dbo.V_Filter_Set_Report AS t1


GO
