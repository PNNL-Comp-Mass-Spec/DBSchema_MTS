/****** Object:  View [dbo].[V_QR_SummaryList] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_QR_SummaryList]
AS
SELECT 
	QD.Quantitation_ID AS QID, 
	QD.SampleName AS [Sample Name],
	QD.Comment, 
	QD.Fraction_Highest_Abu_To_Use AS [Threshold % For Inclusion],
	QD.Normalize_To_Standard_Abundances AS Normalize, 
	QD.Standard_Abundance_Min AS [Std Abu Min], 
	QD.Standard_Abundance_Max AS [Std Abu Max], 
	QD.UMC_Abundance_Mode AS [Force Peak Max Abundance], 
	QD.Minimum_MT_High_Normalized_Score AS [Min High MS/MS Score],
	QD.Minimum_MT_High_Discriminant_Score AS [Min High Discriminant Score],
	QD.Minimum_MT_Peptide_Prophet_Probability AS [Min High Peptide Prophet Prob],
	QD.Minimum_PMT_Quality_Score AS [Min PMT Quality Score], 
	QD.Maximum_Matches_per_UMC_to_Keep AS [Max Matches per UMC],
	QD.Minimum_Match_Score AS [Min SLiC Score], 
	QD.Minimum_Del_Match_Score AS [Min Del SLiC Score], 
	QD.Minimum_Uniqueness_Probability AS [Min Uniq Prob],
	QD.Maximum_FDR_Threshold AS [Max FDR],
	QD.Minimum_Peptide_Length AS [Min Peptide Length], 
	QD.Minimum_Peptide_Replicate_Count AS [Min Peptide Rep Count],
	QD.UniqueMassTagCount AS [Unique Mass Tag Count], 
	MDStatsQ.[Comparison Mass Tag Count], 
	ISNULL(QD.AMT_Count_5pct_FDR, 0)  AS [AMT Count 5% FDR],
	ISNULL(QD.AMT_Count_10pct_FDR, 0) AS [AMT Count 10% FDR],
	ISNULL(QD.AMT_Count_25pct_FDR, 0) AS [AMT Count 25% FDR],
	QD.Protein_Degeneracy_Mode AS [Protein Degeneracy Mode],
	QD.ORF_Coverage_Computation_Level AS [ORF Coverage Computation Level],
	QD.ReplicateNormalizationStats AS [Rep Norm Stats], 
	QD.Quantitation_State AS [Quantitation State ID], 
	QSN.Quantitation_State_Name AS State, 
	QD.Last_Affected AS [Last Affected]
FROM T_Quantitation_Description QD INNER JOIN
        ( SELECT QD.Quantitation_ID AS QID, 
				AVG(MMD.MD_Comparison_Mass_Tag_Count) AS [Comparison Mass Tag Count]
		  FROM	T_Match_Making_Description MMD INNER JOIN
				T_Quantitation_MDIDs QMDIDs ON MMD.MD_ID = QMDIDs.MD_ID INNER JOIN
				T_Quantitation_Description QD ON QMDIDs.Quantitation_ID = QD.Quantitation_ID
		  GROUP BY QD.Quantitation_ID
		) MDStatsQ ON 
    QD.Quantitation_ID = MDStatsQ.QID INNER JOIN
    T_Quantitation_State_Name QSN ON QD.Quantitation_State = QSN.Quantitation_State

GO
GRANT VIEW DEFINITION ON [dbo].[V_QR_SummaryList] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[V_QR_SummaryList] TO [MTS_DB_Lite] AS [dbo]
GO
