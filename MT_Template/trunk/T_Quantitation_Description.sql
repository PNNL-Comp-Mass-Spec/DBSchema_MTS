/****** Object:  Table [dbo].[T_Quantitation_Description] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Quantitation_Description](
	[Quantitation_ID] [int] IDENTITY(1,1) NOT NULL,
	[SampleName] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Quantitation_State] [tinyint] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_QuantitationProcessingState]  DEFAULT (1),
	[Comment] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_Quantitation_Description_Comment]  DEFAULT (''),
	[Fraction_Highest_Abu_To_Use] [decimal](9, 8) NOT NULL CONSTRAINT [DF_T_Quantitation_Description_Fraction_Highest_Abu_To_Use]  DEFAULT (0.33),
	[Normalize_To_Standard_Abundances] [tinyint] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_Normalize_To_Standard_Abundances]  DEFAULT (1),
	[Standard_Abundance_Min] [float] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_Standard_Abundance_Min]  DEFAULT (0),
	[Standard_Abundance_Max] [float] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_Standard_Abundance_Max]  DEFAULT (5000000000),
	[UMC_Abundance_Mode] [tinyint] NULL CONSTRAINT [DF_T_Quantitation_Description_UMC_Abundance_Mode]  DEFAULT (0),
	[Expression_Ratio_Mode] [tinyint] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_Expression_Ratio_Mode]  DEFAULT (0),
	[Minimum_MT_High_Normalized_Score] [real] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_Minimum_High_Normalized_Score]  DEFAULT (0),
	[Minimum_MT_High_Discriminant_Score] [real] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_Minimum_MT_High_Discriminant_Score]  DEFAULT (0),
	[Minimum_MT_Peptide_Prophet_Probability] [real] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_Minimum_MT_Peptide_Prophet_Probability]  DEFAULT (0),
	[Minimum_PMT_Quality_Score] [real] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_Minimum_PMT_Quality_Score]  DEFAULT (0),
	[Minimum_Peptide_Length] [tinyint] NULL CONSTRAINT [DF_T_Quantitation_Description_Minimum_Peptide_Length]  DEFAULT (6),
	[Minimum_Match_Score] [decimal](9, 5) NOT NULL CONSTRAINT [DF_T_Quantitation_Description_Minimum_Match_Score]  DEFAULT (0),
	[Minimum_Del_Match_Score] [real] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_Minimum_Del_Match_Score]  DEFAULT (0),
	[Minimum_Peptide_Replicate_Count] [smallint] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_Minimum_Peptide_Replicate_Count]  DEFAULT (0),
	[ORF_Coverage_Computation_Level] [tinyint] NULL CONSTRAINT [DF_T_Quantitation_Description_ORF_Coverage_Computation_Level]  DEFAULT (1),
	[RepNormalization_PctSmallDataToDiscard] [tinyint] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_RepNormalization_PctSmallDataToDiscard]  DEFAULT (10),
	[RepNormalization_PctLargeDataToDiscard] [tinyint] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_RepNormalization_PctLargeDataToDiscard]  DEFAULT (5),
	[RepNormalization_MinimumDataPointCount] [smallint] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_RepNormalization_MinimumDataPointCount]  DEFAULT (10),
	[Internal_Std_Inclusion_Mode] [tinyint] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_Internal_Std_Inclusion_Mode]  DEFAULT (0),
	[Minimum_Criteria_ORFMassDaDivisor] [int] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_Minimum_Criteria_ORFMassDaDivisor]  DEFAULT (15000),
	[Minimum_Criteria_UniqueMTCountMinimum] [int] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_Minimum_Criteria_UniqueMTCountMinimum]  DEFAULT (2),
	[Minimum_Criteria_MTIonMatchCountMinimum] [int] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_Minimum_Criteria_MTIonMatchCountMinimum]  DEFAULT (6),
	[Minimum_Criteria_FractionScansMatchingSingleMassTagMinimum] [decimal](9, 8) NOT NULL CONSTRAINT [DF_T_Quantitation_Description_Minimum_Criteria_FractionScansMatchingSingleMassTagMinimum]  DEFAULT (0.5),
	[RemoveOutlierAbundancesForReplicates] [tinyint] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_RemoveOutlierAbundancesForReplicates]  DEFAULT (1),
	[FractionCrossReplicateAvgInRange] [decimal](9, 5) NOT NULL CONSTRAINT [DF_T_Quantitation_Description_FractionCrossReplicateAvgInRange]  DEFAULT (2),
	[AddBackExcludedMassTags] [tinyint] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_AddBackExcludedMassTags]  DEFAULT (1),
	[FeatureCountWithMatchesAvg] [int] NULL,
	[MTMatchingUMCsCount] [int] NULL,
	[MTMatchingUMCsCountFilteredOut] [int] NULL,
	[UniqueMassTagCount] [int] NULL,
	[UniqueMassTagCountFilteredOut] [int] NULL,
	[UniqueInternalStdCount] [int] NULL,
	[UniqueInternalStdCountFilteredOut] [int] NULL,
	[ReplicateNormalizationStats] [varchar](1024) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Last_Affected] [datetime] NULL CONSTRAINT [DF_T_Quantitation_Description_Last_Affected]  DEFAULT (getdate()),
 CONSTRAINT [PK_T_Quantitation_Description] PRIMARY KEY CLUSTERED 
(
	[Quantitation_ID] ASC
)WITH FILLFACTOR = 90 ON [PRIMARY]
) ON [PRIMARY]

GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] TO [DMS_SP_User]
GO
GRANT INSERT ON [dbo].[T_Quantitation_Description] TO [DMS_SP_User]
GO
GRANT DELETE ON [dbo].[T_Quantitation_Description] TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([Quantitation_ID]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([Quantitation_ID]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([SampleName]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([SampleName]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([Quantitation_State]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([Quantitation_State]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([Comment]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([Comment]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([Fraction_Highest_Abu_To_Use]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([Fraction_Highest_Abu_To_Use]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([Normalize_To_Standard_Abundances]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([Normalize_To_Standard_Abundances]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([Standard_Abundance_Min]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([Standard_Abundance_Min]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([Standard_Abundance_Max]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([Standard_Abundance_Max]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([UMC_Abundance_Mode]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([UMC_Abundance_Mode]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([Expression_Ratio_Mode]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([Expression_Ratio_Mode]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([Minimum_MT_High_Normalized_Score]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([Minimum_MT_High_Normalized_Score]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([Minimum_MT_High_Discriminant_Score]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([Minimum_MT_High_Discriminant_Score]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([Minimum_MT_Peptide_Prophet_Probability]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([Minimum_MT_Peptide_Prophet_Probability]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([Minimum_PMT_Quality_Score]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([Minimum_PMT_Quality_Score]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([Minimum_Peptide_Length]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([Minimum_Peptide_Length]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([Minimum_Match_Score]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([Minimum_Match_Score]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([Minimum_Del_Match_Score]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([Minimum_Del_Match_Score]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([Minimum_Peptide_Replicate_Count]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([Minimum_Peptide_Replicate_Count]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([ORF_Coverage_Computation_Level]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([ORF_Coverage_Computation_Level]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([RepNormalization_PctSmallDataToDiscard]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([RepNormalization_PctSmallDataToDiscard]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([RepNormalization_PctLargeDataToDiscard]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([RepNormalization_PctLargeDataToDiscard]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([RepNormalization_MinimumDataPointCount]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([RepNormalization_MinimumDataPointCount]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([Internal_Std_Inclusion_Mode]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([Internal_Std_Inclusion_Mode]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([Minimum_Criteria_ORFMassDaDivisor]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([Minimum_Criteria_ORFMassDaDivisor]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([Minimum_Criteria_UniqueMTCountMinimum]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([Minimum_Criteria_UniqueMTCountMinimum]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([Minimum_Criteria_MTIonMatchCountMinimum]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([Minimum_Criteria_MTIonMatchCountMinimum]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([Minimum_Criteria_FractionScansMatchingSingleMassTagMinimum]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([Minimum_Criteria_FractionScansMatchingSingleMassTagMinimum]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([RemoveOutlierAbundancesForReplicates]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([RemoveOutlierAbundancesForReplicates]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([FractionCrossReplicateAvgInRange]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([FractionCrossReplicateAvgInRange]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([AddBackExcludedMassTags]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([AddBackExcludedMassTags]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([FeatureCountWithMatchesAvg]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([FeatureCountWithMatchesAvg]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([MTMatchingUMCsCount]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([MTMatchingUMCsCount]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([MTMatchingUMCsCountFilteredOut]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([MTMatchingUMCsCountFilteredOut]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([UniqueMassTagCount]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([UniqueMassTagCount]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([UniqueMassTagCountFilteredOut]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([UniqueMassTagCountFilteredOut]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([UniqueInternalStdCount]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([UniqueInternalStdCount]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([UniqueInternalStdCountFilteredOut]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([UniqueInternalStdCountFilteredOut]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([ReplicateNormalizationStats]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([ReplicateNormalizationStats]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] ([Last_Affected]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] ([Last_Affected]) TO [DMS_SP_User]
GO
ALTER TABLE [dbo].[T_Quantitation_Description]  WITH NOCHECK ADD  CONSTRAINT [FK_T_Quantitation_Description_T_Quantitation_State_Name] FOREIGN KEY([Quantitation_State])
REFERENCES [T_Quantitation_State_Name] ([Quantitation_State])
GO
ALTER TABLE [dbo].[T_Quantitation_Description] CHECK CONSTRAINT [FK_T_Quantitation_Description_T_Quantitation_State_Name]
GO
