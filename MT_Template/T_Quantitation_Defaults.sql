/****** Object:  Table [dbo].[T_Quantitation_Defaults] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Quantitation_Defaults](
	[Default_ID] [int] IDENTITY(100,1) NOT NULL,
	[Instrument_Name] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Dataset_Name_Filter] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Fraction_Highest_Abu_To_Use] [real] NOT NULL,
	[Normalize_To_Standard_Abundances] [tinyint] NOT NULL,
	[Standard_Abundance_Min] [float] NOT NULL,
	[Standard_Abundance_Max] [float] NOT NULL,
	[UMC_Abundance_Mode] [tinyint] NOT NULL,
	[Expression_Ratio_Mode] [tinyint] NOT NULL,
	[Minimum_High_Normalized_Score] [real] NOT NULL,
	[Minimum_High_Discriminant_Score] [real] NOT NULL,
	[Minimum_Peptide_Prophet_Probability] [real] NOT NULL,
	[Minimum_PMT_Quality_Score] [real] NOT NULL,
	[Minimum_Peptide_Length] [tinyint] NOT NULL,
	[Maximum_Matches_per_UMC_to_Keep] [smallint] NOT NULL,
	[Minimum_Match_Score] [real] NOT NULL,
	[Minimum_Del_Match_Score] [real] NOT NULL,
	[Minimum_Uniqueness_Probability] [real] NOT NULL,
	[Maximum_FDR_Threshold] [real] NOT NULL,
	[Minimum_Peptide_Replicate_Count] [smallint] NOT NULL,
	[ORF_Coverage_Computation_Level] [tinyint] NOT NULL,
	[Internal_Std_Inclusion_Mode] [tinyint] NOT NULL,
 CONSTRAINT [PK_T_Quantitation_Defaults] PRIMARY KEY CLUSTERED 
(
	[Default_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 90) ON [PRIMARY],
 CONSTRAINT [IX_T_Quantitation_Defaults] UNIQUE NONCLUSTERED 
(
	[Instrument_Name] ASC,
	[Dataset_Name_Filter] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Quantitation_Defaults] ADD  CONSTRAINT [DF_T_Quantitation_Defaults_Fraction_Highest_Abu_To_Use]  DEFAULT ((0.33)) FOR [Fraction_Highest_Abu_To_Use]
GO
ALTER TABLE [dbo].[T_Quantitation_Defaults] ADD  CONSTRAINT [DF_T_Quantitation_Defaults_Normalize_To_Standard_Abundances]  DEFAULT ((1)) FOR [Normalize_To_Standard_Abundances]
GO
ALTER TABLE [dbo].[T_Quantitation_Defaults] ADD  CONSTRAINT [DF_T_Quantitation_Defaults_Standard_Abundance_Min]  DEFAULT ((0)) FOR [Standard_Abundance_Min]
GO
ALTER TABLE [dbo].[T_Quantitation_Defaults] ADD  CONSTRAINT [DF_T_Quantitation_Defaults_Standard_Abundance_Max]  DEFAULT ((5000000000.)) FOR [Standard_Abundance_Max]
GO
ALTER TABLE [dbo].[T_Quantitation_Defaults] ADD  CONSTRAINT [DF_T_Quantitation_Defaults_UMC_Abundance_Mode]  DEFAULT ((0)) FOR [UMC_Abundance_Mode]
GO
ALTER TABLE [dbo].[T_Quantitation_Defaults] ADD  CONSTRAINT [DF_T_Quantitation_Defaults_Expression_Ratio_Mode]  DEFAULT ((0)) FOR [Expression_Ratio_Mode]
GO
ALTER TABLE [dbo].[T_Quantitation_Defaults] ADD  CONSTRAINT [DF_T_Quantitation_Defaults_Minimum_High_Normalized_Score]  DEFAULT ((0)) FOR [Minimum_High_Normalized_Score]
GO
ALTER TABLE [dbo].[T_Quantitation_Defaults] ADD  CONSTRAINT [DF_T_Quantitation_Defaults_Minimum_High_Discriminant_Score]  DEFAULT ((0)) FOR [Minimum_High_Discriminant_Score]
GO
ALTER TABLE [dbo].[T_Quantitation_Defaults] ADD  CONSTRAINT [DF_T_Quantitation_Defaults_Minimum_Peptide_Prophet_Probability]  DEFAULT ((0)) FOR [Minimum_Peptide_Prophet_Probability]
GO
ALTER TABLE [dbo].[T_Quantitation_Defaults] ADD  CONSTRAINT [DF_T_Quantitation_Defaults_Minimum_PMT_Quality_Score]  DEFAULT ((0)) FOR [Minimum_PMT_Quality_Score]
GO
ALTER TABLE [dbo].[T_Quantitation_Defaults] ADD  CONSTRAINT [DF_T_Quantitation_Defaults_Minimum_Peptide_Length]  DEFAULT ((6)) FOR [Minimum_Peptide_Length]
GO
ALTER TABLE [dbo].[T_Quantitation_Defaults] ADD  CONSTRAINT [DF_T_Quantitation_Defaults_Maximum_Matches_per_UMC_to_Keep]  DEFAULT ((1)) FOR [Maximum_Matches_per_UMC_to_Keep]
GO
ALTER TABLE [dbo].[T_Quantitation_Defaults] ADD  CONSTRAINT [DF_T_Quantitation_Defaults_Minimum_Match_Score]  DEFAULT ((0.25)) FOR [Minimum_Match_Score]
GO
ALTER TABLE [dbo].[T_Quantitation_Defaults] ADD  CONSTRAINT [DF_T_Quantitation_Defaults_Minimum_Del_Match_Score]  DEFAULT ((0)) FOR [Minimum_Del_Match_Score]
GO
ALTER TABLE [dbo].[T_Quantitation_Defaults] ADD  CONSTRAINT [DF_T_Quantitation_Defaults_Minimum_Uniqueness_Probability]  DEFAULT ((0.25)) FOR [Minimum_Uniqueness_Probability]
GO
ALTER TABLE [dbo].[T_Quantitation_Defaults] ADD  CONSTRAINT [DF_T_Quantitation_Defaults_Maximum_FDR_Threshold]  DEFAULT ((0.5)) FOR [Maximum_FDR_Threshold]
GO
ALTER TABLE [dbo].[T_Quantitation_Defaults] ADD  CONSTRAINT [DF_T_Quantitation_Defaults_Minimum_Peptide_Replicate_Count]  DEFAULT ((0)) FOR [Minimum_Peptide_Replicate_Count]
GO
ALTER TABLE [dbo].[T_Quantitation_Defaults] ADD  CONSTRAINT [DF_T_Quantitation_Defaults_ORF_Coverage_Computation_Level]  DEFAULT ((1)) FOR [ORF_Coverage_Computation_Level]
GO
ALTER TABLE [dbo].[T_Quantitation_Defaults] ADD  CONSTRAINT [DF_T_Quantitation_Defaults_Internal_Std_Inclusion_Mode]  DEFAULT ((0)) FOR [Internal_Std_Inclusion_Mode]
GO
