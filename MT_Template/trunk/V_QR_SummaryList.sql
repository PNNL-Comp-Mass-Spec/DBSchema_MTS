/****** Object:  View [dbo].[V_QR_SummaryList] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW dbo.V_QR_SummaryList
AS
SELECT TOP 100 PERCENT QD.Quantitation_ID AS QID, 
    QD.SampleName AS [Sample Name], QD.Comment, 
    MIN(dbo.udfPeakMatchingPathForMDID(dbo.T_Quantitation_MDIDs.MD_ID))
     AS [Results Folder Path], 
    QD.Fraction_Highest_Abu_To_Use AS [Threshold % For Inclusion],
     QD.Normalize_To_Standard_Abundances AS Normalize, 
    QD.Standard_Abundance_Min AS [Std Abu Min], 
    QD.Standard_Abundance_Max AS [Std Abu Max], 
    QD.UMC_Abundance_Mode AS [Force Peak Max Abundance], 
    QD.Minimum_MT_High_Normalized_Score AS [Min High MS/MS Score],
     QD.Minimum_MT_High_Discriminant_Score AS [Min High Discriminant Score],
     QD.Minimum_PMT_Quality_Score AS [Min PMT Quality Score], 
    QD.Minimum_Match_Score AS [Min SLiC Score], 
    QD.Minimum_Del_Match_Score AS [Min Del SLiC Score], 
    QD.Minimum_Peptide_Length AS [Min Peptide Length], 
    QD.Minimum_Peptide_Replicate_Count AS [Min Peptide Rep Count],
     QD.UniqueMassTagCount AS [Unique Mass Tag Count], 
    AVG(MMD.MD_Comparison_Mass_Tag_Count) 
    AS [Comparison Mass Tag Count], 
    QD.ORF_Coverage_Computation_Level AS [ORF Coverage Computation Level],
     QD.ReplicateNormalizationStats AS [Rep Norm Stats], 
    QD.Quantitation_State AS [Quantitation State ID], 
    dbo.T_Quantitation_State_Name.Quantitation_State_Name AS State,
     QD.Last_Affected AS [Last Affected]
FROM dbo.T_Quantitation_Description QD INNER JOIN
    dbo.T_Quantitation_State_Name ON 
    QD.Quantitation_State = dbo.T_Quantitation_State_Name.Quantitation_State
     LEFT OUTER JOIN
    dbo.T_Quantitation_MDIDs ON 
    QD.Quantitation_ID = dbo.T_Quantitation_MDIDs.Quantitation_ID
     LEFT OUTER JOIN
    dbo.T_Match_Making_Description MMD ON 
    dbo.T_Quantitation_MDIDs.MD_ID = MMD.MD_ID
WHERE (QD.Quantitation_State = 3) OR
    (QD.Quantitation_State = 5)
GROUP BY QD.Quantitation_ID, QD.SampleName, QD.Comment, 
    QD.Fraction_Highest_Abu_To_Use, 
    QD.Normalize_To_Standard_Abundances, 
    QD.Standard_Abundance_Min, QD.Standard_Abundance_Max, 
    QD.Minimum_MT_High_Normalized_Score, 
    QD.Minimum_Peptide_Replicate_Count, 
    QD.UniqueMassTagCount, QD.ReplicateNormalizationStats, 
    QD.Quantitation_State, 
    dbo.T_Quantitation_State_Name.Quantitation_State_Name, 
    QD.Last_Affected, QD.Minimum_PMT_Quality_Score, 
    QD.Minimum_Peptide_Length, QD.UMC_Abundance_Mode, 
    QD.ORF_Coverage_Computation_Level, 
    QD.Minimum_MT_High_Discriminant_Score, 
    QD.Minimum_Match_Score,
    QD.Minimum_Del_Match_Score
ORDER BY QD.Quantitation_ID


GO
