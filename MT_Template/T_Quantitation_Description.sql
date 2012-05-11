/****** Object:  Table [dbo].[T_Quantitation_Description] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Quantitation_Description](
	[Quantitation_ID] [int] IDENTITY(1,1) NOT NULL,
	[SampleName] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Quantitation_State] [tinyint] NOT NULL,
	[Comment] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Fraction_Highest_Abu_To_Use] [decimal](9, 8) NOT NULL,
	[Normalize_To_Standard_Abundances] [tinyint] NOT NULL,
	[Standard_Abundance_Min] [float] NOT NULL,
	[Standard_Abundance_Max] [float] NOT NULL,
	[UMC_Abundance_Mode] [tinyint] NULL,
	[Expression_Ratio_Mode] [tinyint] NOT NULL,
	[Minimum_MT_High_Normalized_Score] [real] NOT NULL,
	[Minimum_MT_High_Discriminant_Score] [real] NOT NULL,
	[Minimum_MT_Peptide_Prophet_Probability] [real] NOT NULL,
	[Minimum_PMT_Quality_Score] [real] NOT NULL,
	[Minimum_Peptide_Length] [tinyint] NULL,
	[Maximum_Matches_per_UMC_to_Keep] [smallint] NOT NULL,
	[Minimum_Match_Score] [decimal](9, 5) NOT NULL,
	[Minimum_Del_Match_Score] [real] NOT NULL,
	[Minimum_Uniqueness_Probability] [real] NULL,
	[Maximum_FDR_Threshold] [real] NULL,
	[Minimum_Peptide_Replicate_Count] [smallint] NOT NULL,
	[ORF_Coverage_Computation_Level] [tinyint] NULL,
	[RepNormalization_PctSmallDataToDiscard] [tinyint] NOT NULL,
	[RepNormalization_PctLargeDataToDiscard] [tinyint] NOT NULL,
	[RepNormalization_MinimumDataPointCount] [smallint] NOT NULL,
	[Internal_Std_Inclusion_Mode] [tinyint] NOT NULL,
	[Protein_Degeneracy_Mode] [tinyint] NOT NULL,
	[Minimum_Criteria_ORFMassDaDivisor] [int] NOT NULL,
	[Minimum_Criteria_UniqueMTCountMinimum] [int] NOT NULL,
	[Minimum_Criteria_MTIonMatchCountMinimum] [int] NOT NULL,
	[Minimum_Criteria_FractionScansMatchingSingleMassTagMinimum] [decimal](9, 8) NOT NULL,
	[RemoveOutlierAbundancesForReplicates] [tinyint] NOT NULL,
	[FractionCrossReplicateAvgInRange] [decimal](9, 5) NOT NULL,
	[AddBackExcludedMassTags] [tinyint] NOT NULL,
	[FeatureCountWithMatchesAvg] [int] NULL,
	[MTMatchingUMCsCount] [int] NULL,
	[MTMatchingUMCsCountFilteredOut] [int] NULL,
	[UniqueMassTagCount] [int] NULL,
	[UniqueMassTagCountFilteredOut] [int] NULL,
	[UniqueInternalStdCount] [int] NULL,
	[UniqueInternalStdCountFilteredOut] [int] NULL,
	[Match_Score_Mode] [tinyint] NULL,
	[AMT_Count_1pct_FDR] [int] NULL,
	[AMT_Count_2pt5pct_FDR] [int] NULL,
	[AMT_Count_5pct_FDR] [int] NULL,
	[AMT_Count_10pct_FDR] [int] NULL,
	[AMT_Count_25pct_FDR] [int] NULL,
	[AMT_Count_50pct_FDR] [int] NULL,
	[ReplicateNormalizationStats] [varchar](1024) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Last_Affected] [datetime] NULL,
 CONSTRAINT [PK_T_Quantitation_Description] PRIMARY KEY CLUSTERED 
(
	[Quantitation_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
GRANT DELETE ON [dbo].[T_Quantitation_Description] TO [DMS_SP_User] AS [dbo]
GO
GRANT INSERT ON [dbo].[T_Quantitation_Description] TO [DMS_SP_User] AS [dbo]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Description] TO [DMS_SP_User] AS [dbo]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Description] TO [DMS_SP_User] AS [dbo]
GO
ALTER TABLE [dbo].[T_Quantitation_Description]  WITH CHECK ADD  CONSTRAINT [FK_T_Quantitation_Description_T_Quantitation_State_Name] FOREIGN KEY([Quantitation_State])
REFERENCES [T_Quantitation_State_Name] ([Quantitation_State])
GO
ALTER TABLE [dbo].[T_Quantitation_Description] CHECK CONSTRAINT [FK_T_Quantitation_Description_T_Quantitation_State_Name]
GO
ALTER TABLE [dbo].[T_Quantitation_Description] ADD  CONSTRAINT [DF_T_Quantitation_Description_QuantitationProcessingState]  DEFAULT ((1)) FOR [Quantitation_State]
GO
ALTER TABLE [dbo].[T_Quantitation_Description] ADD  CONSTRAINT [DF_T_Quantitation_Description_Comment]  DEFAULT ('') FOR [Comment]
GO
ALTER TABLE [dbo].[T_Quantitation_Description] ADD  CONSTRAINT [DF_T_Quantitation_Description_Fraction_Highest_Abu_To_Use]  DEFAULT ((0.33)) FOR [Fraction_Highest_Abu_To_Use]
GO
ALTER TABLE [dbo].[T_Quantitation_Description] ADD  CONSTRAINT [DF_T_Quantitation_Description_Normalize_To_Standard_Abundances]  DEFAULT ((1)) FOR [Normalize_To_Standard_Abundances]
GO
ALTER TABLE [dbo].[T_Quantitation_Description] ADD  CONSTRAINT [DF_T_Quantitation_Description_Standard_Abundance_Min]  DEFAULT ((0)) FOR [Standard_Abundance_Min]
GO
ALTER TABLE [dbo].[T_Quantitation_Description] ADD  CONSTRAINT [DF_T_Quantitation_Description_Standard_Abundance_Max]  DEFAULT ((5000000000.)) FOR [Standard_Abundance_Max]
GO
ALTER TABLE [dbo].[T_Quantitation_Description] ADD  CONSTRAINT [DF_T_Quantitation_Description_UMC_Abundance_Mode]  DEFAULT ((0)) FOR [UMC_Abundance_Mode]
GO
ALTER TABLE [dbo].[T_Quantitation_Description] ADD  CONSTRAINT [DF_T_Quantitation_Description_Expression_Ratio_Mode]  DEFAULT ((0)) FOR [Expression_Ratio_Mode]
GO
ALTER TABLE [dbo].[T_Quantitation_Description] ADD  CONSTRAINT [DF_T_Quantitation_Description_Minimum_High_Normalized_Score]  DEFAULT ((0)) FOR [Minimum_MT_High_Normalized_Score]
GO
ALTER TABLE [dbo].[T_Quantitation_Description] ADD  CONSTRAINT [DF_T_Quantitation_Description_Minimum_MT_High_Discriminant_Score]  DEFAULT ((0)) FOR [Minimum_MT_High_Discriminant_Score]
GO
ALTER TABLE [dbo].[T_Quantitation_Description] ADD  CONSTRAINT [DF_T_Quantitation_Description_Minimum_MT_Peptide_Prophet_Probability]  DEFAULT ((0)) FOR [Minimum_MT_Peptide_Prophet_Probability]
GO
ALTER TABLE [dbo].[T_Quantitation_Description] ADD  CONSTRAINT [DF_T_Quantitation_Description_Minimum_PMT_Quality_Score]  DEFAULT ((0)) FOR [Minimum_PMT_Quality_Score]
GO
ALTER TABLE [dbo].[T_Quantitation_Description] ADD  CONSTRAINT [DF_T_Quantitation_Description_Minimum_Peptide_Length]  DEFAULT ((6)) FOR [Minimum_Peptide_Length]
GO
ALTER TABLE [dbo].[T_Quantitation_Description] ADD  CONSTRAINT [DF_T_Quantitation_Description_Maximum_Matches_per_UMC_to_Keep]  DEFAULT ((0)) FOR [Maximum_Matches_per_UMC_to_Keep]
GO
ALTER TABLE [dbo].[T_Quantitation_Description] ADD  CONSTRAINT [DF_T_Quantitation_Description_Minimum_Match_Score]  DEFAULT ((0)) FOR [Minimum_Match_Score]
GO
ALTER TABLE [dbo].[T_Quantitation_Description] ADD  CONSTRAINT [DF_T_Quantitation_Description_Minimum_Del_Match_Score]  DEFAULT ((0)) FOR [Minimum_Del_Match_Score]
GO
ALTER TABLE [dbo].[T_Quantitation_Description] ADD  CONSTRAINT [DF_T_Quantitation_Description_Minimum_Uniqueness_Probability]  DEFAULT ((0)) FOR [Minimum_Uniqueness_Probability]
GO
ALTER TABLE [dbo].[T_Quantitation_Description] ADD  CONSTRAINT [DF_T_Quantitation_Description_Maximum_FDR_Threshold]  DEFAULT ((1)) FOR [Maximum_FDR_Threshold]
GO
ALTER TABLE [dbo].[T_Quantitation_Description] ADD  CONSTRAINT [DF_T_Quantitation_Description_Minimum_Peptide_Replicate_Count]  DEFAULT ((0)) FOR [Minimum_Peptide_Replicate_Count]
GO
ALTER TABLE [dbo].[T_Quantitation_Description] ADD  CONSTRAINT [DF_T_Quantitation_Description_ORF_Coverage_Computation_Level]  DEFAULT ((1)) FOR [ORF_Coverage_Computation_Level]
GO
ALTER TABLE [dbo].[T_Quantitation_Description] ADD  CONSTRAINT [DF_T_Quantitation_Description_RepNormalization_PctSmallDataToDiscard]  DEFAULT ((10)) FOR [RepNormalization_PctSmallDataToDiscard]
GO
ALTER TABLE [dbo].[T_Quantitation_Description] ADD  CONSTRAINT [DF_T_Quantitation_Description_RepNormalization_PctLargeDataToDiscard]  DEFAULT ((5)) FOR [RepNormalization_PctLargeDataToDiscard]
GO
ALTER TABLE [dbo].[T_Quantitation_Description] ADD  CONSTRAINT [DF_T_Quantitation_Description_RepNormalization_MinimumDataPointCount]  DEFAULT ((10)) FOR [RepNormalization_MinimumDataPointCount]
GO
ALTER TABLE [dbo].[T_Quantitation_Description] ADD  CONSTRAINT [DF_T_Quantitation_Description_Internal_Std_Inclusion_Mode]  DEFAULT ((0)) FOR [Internal_Std_Inclusion_Mode]
GO
ALTER TABLE [dbo].[T_Quantitation_Description] ADD  CONSTRAINT [DF_T_Quantitation_Description_Protein_Degeneracy_Mode]  DEFAULT ((0)) FOR [Protein_Degeneracy_Mode]
GO
ALTER TABLE [dbo].[T_Quantitation_Description] ADD  CONSTRAINT [DF_T_Quantitation_Description_Minimum_Criteria_ORFMassDaDivisor]  DEFAULT ((15000)) FOR [Minimum_Criteria_ORFMassDaDivisor]
GO
ALTER TABLE [dbo].[T_Quantitation_Description] ADD  CONSTRAINT [DF_T_Quantitation_Description_Minimum_Criteria_UniqueMTCountMinimum]  DEFAULT ((2)) FOR [Minimum_Criteria_UniqueMTCountMinimum]
GO
ALTER TABLE [dbo].[T_Quantitation_Description] ADD  CONSTRAINT [DF_T_Quantitation_Description_Minimum_Criteria_MTIonMatchCountMinimum]  DEFAULT ((6)) FOR [Minimum_Criteria_MTIonMatchCountMinimum]
GO
ALTER TABLE [dbo].[T_Quantitation_Description] ADD  CONSTRAINT [DF_T_Quantitation_Description_Minimum_Criteria_FractionScansMatchingSingleMassTagMinimum]  DEFAULT ((0.5)) FOR [Minimum_Criteria_FractionScansMatchingSingleMassTagMinimum]
GO
ALTER TABLE [dbo].[T_Quantitation_Description] ADD  CONSTRAINT [DF_T_Quantitation_Description_RemoveOutlierAbundancesForReplicates]  DEFAULT ((1)) FOR [RemoveOutlierAbundancesForReplicates]
GO
ALTER TABLE [dbo].[T_Quantitation_Description] ADD  CONSTRAINT [DF_T_Quantitation_Description_FractionCrossReplicateAvgInRange]  DEFAULT ((2)) FOR [FractionCrossReplicateAvgInRange]
GO
ALTER TABLE [dbo].[T_Quantitation_Description] ADD  CONSTRAINT [DF_T_Quantitation_Description_AddBackExcludedMassTags]  DEFAULT ((1)) FOR [AddBackExcludedMassTags]
GO
ALTER TABLE [dbo].[T_Quantitation_Description] ADD  CONSTRAINT [DF_T_Quantitation_Description_Match_Score_Mode]  DEFAULT ((0)) FOR [Match_Score_Mode]
GO
ALTER TABLE [dbo].[T_Quantitation_Description] ADD  CONSTRAINT [DF_T_Quantitation_Description_Last_Affected]  DEFAULT (getdate()) FOR [Last_Affected]
GO
