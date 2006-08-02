if exists (select * from dbo.sysobjects where id = object_id(N'[T_Quantitation_Description]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Quantitation_Description]
GO

CREATE TABLE [T_Quantitation_Description] (
	[Quantitation_ID] [int] IDENTITY (1, 1) NOT NULL ,
	[SampleName] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Quantitation_State] [tinyint] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_QuantitationProcessingState] DEFAULT (1),
	[Comment] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_Quantitation_Description_Comment] DEFAULT (''),
	[Fraction_Highest_Abu_To_Use] [decimal](9, 8) NOT NULL CONSTRAINT [DF_T_Quantitation_Description_Fraction_Highest_Abu_To_Use] DEFAULT (0.33),
	[Normalize_To_Standard_Abundances] [tinyint] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_Normalize_To_Standard_Abundances] DEFAULT (1),
	[Standard_Abundance_Min] [float] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_Standard_Abundance_Min] DEFAULT (0),
	[Standard_Abundance_Max] [float] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_Standard_Abundance_Max] DEFAULT (5000000000),
	[UMC_Abundance_Mode] [tinyint] NULL CONSTRAINT [DF_T_Quantitation_Description_UMC_Abundance_Mode] DEFAULT (0),
	[Expression_Ratio_Mode] [tinyint] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_Expression_Ratio_Mode] DEFAULT (0),
	[Minimum_MT_High_Normalized_Score] [real] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_Minimum_High_Normalized_Score] DEFAULT (0),
	[Minimum_MT_High_Discriminant_Score] [real] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_Minimum_MT_High_Discriminant_Score] DEFAULT (0),
	[Minimum_PMT_Quality_Score] [real] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_Minimum_PMT_Quality_Score] DEFAULT (0),
	[Minimum_Peptide_Length] [tinyint] NULL CONSTRAINT [DF_T_Quantitation_Description_Minimum_Peptide_Length] DEFAULT (6),
	[Minimum_Match_Score] [decimal](9, 5) NOT NULL CONSTRAINT [DF_T_Quantitation_Description_Minimum_Match_Score] DEFAULT (0),
	[Minimum_Del_Match_Score] [real] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_Minimum_Del_Match_Score] DEFAULT (0),
	[Minimum_Peptide_Replicate_Count] [smallint] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_Minimum_Peptide_Replicate_Count] DEFAULT (0),
	[ORF_Coverage_Computation_Level] [tinyint] NULL CONSTRAINT [DF_T_Quantitation_Description_ORF_Coverage_Computation_Level] DEFAULT (1),
	[RepNormalization_PctSmallDataToDiscard] [tinyint] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_RepNormalization_PctSmallDataToDiscard] DEFAULT (10),
	[RepNormalization_PctLargeDataToDiscard] [tinyint] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_RepNormalization_PctLargeDataToDiscard] DEFAULT (5),
	[RepNormalization_MinimumDataPointCount] [smallint] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_RepNormalization_MinimumDataPointCount] DEFAULT (10),
	[Internal_Std_Inclusion_Mode] [tinyint] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_Internal_Std_Inclusion_Mode] DEFAULT (0),
	[Minimum_Criteria_ORFMassDaDivisor] [int] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_Minimum_Criteria_ORFMassDaDivisor] DEFAULT (15000),
	[Minimum_Criteria_UniqueMTCountMinimum] [int] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_Minimum_Criteria_UniqueMTCountMinimum] DEFAULT (2),
	[Minimum_Criteria_MTIonMatchCountMinimum] [int] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_Minimum_Criteria_MTIonMatchCountMinimum] DEFAULT (6),
	[Minimum_Criteria_FractionScansMatchingSingleMassTagMinimum] [decimal](9, 8) NOT NULL CONSTRAINT [DF_T_Quantitation_Description_Minimum_Criteria_FractionScansMatchingSingleMassTagMinimum] DEFAULT (0.5),
	[RemoveOutlierAbundancesForReplicates] [tinyint] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_RemoveOutlierAbundancesForReplicates] DEFAULT (1),
	[FractionCrossReplicateAvgInRange] [decimal](9, 5) NOT NULL CONSTRAINT [DF_T_Quantitation_Description_FractionCrossReplicateAvgInRange] DEFAULT (2),
	[AddBackExcludedMassTags] [tinyint] NOT NULL CONSTRAINT [DF_T_Quantitation_Description_AddBackExcludedMassTags] DEFAULT (1),
	[FeatureCountWithMatchesAvg] [int] NULL ,
	[MTMatchingUMCsCount] [int] NULL ,
	[MTMatchingUMCsCountFilteredOut] [int] NULL ,
	[UniqueMassTagCount] [int] NULL ,
	[UniqueMassTagCountFilteredOut] [int] NULL ,
	[UniqueInternalStdCount] [int] NULL ,
	[UniqueInternalStdCountFilteredOut] [int] NULL ,
	[ReplicateNormalizationStats] [varchar] (1024) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Last_Affected] [datetime] NULL CONSTRAINT [DF_T_Quantitation_Description_Last_Affected] DEFAULT (getdate()),
	CONSTRAINT [PK_T_Quantitation_Description] PRIMARY KEY  CLUSTERED 
	(
		[Quantitation_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_Quantitation_Description_T_Quantitation_State_Name] FOREIGN KEY 
	(
		[Quantitation_State]
	) REFERENCES [T_Quantitation_State_Name] (
		[Quantitation_State]
	)
) ON [PRIMARY]
GO

GRANT  SELECT ,  UPDATE ,  INSERT ,  DELETE  ON [dbo].[T_Quantitation_Description]  TO [DMS_SP_User]
GO


