/****** Object:  Table [dbo].[T_Quantitation_Defaults] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Quantitation_Defaults](
	[Default_ID] [int] IDENTITY(100,1) NOT NULL,
	[Instrument_Name] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Dataset_Name_Filter] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Fraction_Highest_Abu_To_Use] [real] NOT NULL CONSTRAINT [DF_T_Quantitation_Defaults_Fraction_Highest_Abu_To_Use]  DEFAULT (0.33),
	[Normalize_To_Standard_Abundances] [tinyint] NOT NULL CONSTRAINT [DF_T_Quantitation_Defaults_Normalize_To_Standard_Abundances]  DEFAULT (1),
	[Standard_Abundance_Min] [float] NOT NULL CONSTRAINT [DF_T_Quantitation_Defaults_Standard_Abundance_Min]  DEFAULT (0),
	[Standard_Abundance_Max] [float] NOT NULL CONSTRAINT [DF_T_Quantitation_Defaults_Standard_Abundance_Max]  DEFAULT (5000000000),
	[UMC_Abundance_Mode] [tinyint] NOT NULL CONSTRAINT [DF_T_Quantitation_Defaults_UMC_Abundance_Mode]  DEFAULT (0),
	[Expression_Ratio_Mode] [tinyint] NOT NULL CONSTRAINT [DF_T_Quantitation_Defaults_Expression_Ratio_Mode]  DEFAULT (0),
	[Minimum_High_Normalized_Score] [real] NOT NULL CONSTRAINT [DF_T_Quantitation_Defaults_Minimum_High_Normalized_Score]  DEFAULT (0),
	[Minimum_High_Discriminant_Score] [real] NOT NULL CONSTRAINT [DF_T_Quantitation_Defaults_Minimum_High_Discriminant_Score]  DEFAULT (0.2),
	[Minimum_Peptide_Prophet_Probability] [real] NOT NULL CONSTRAINT [DF_T_Quantitation_Defaults_Minimum_Peptide_Prophet_Probability]  DEFAULT (0),
	[Minimum_PMT_Quality_Score] [real] NOT NULL CONSTRAINT [DF_T_Quantitation_Defaults_Minimum_PMT_Quality_Score]  DEFAULT (0),
	[Minimum_Peptide_Length] [tinyint] NOT NULL CONSTRAINT [DF_T_Quantitation_Defaults_Minimum_Peptide_Length]  DEFAULT (6),
	[Minimum_Match_Score] [real] NOT NULL CONSTRAINT [DF_T_Quantitation_Defaults_Minimum_Match_Score]  DEFAULT (0.35),
	[Minimum_Del_Match_Score] [real] NOT NULL CONSTRAINT [DF_T_Quantitation_Defaults_Minimum_Del_Match_Score]  DEFAULT (0.1),
	[Minimum_Peptide_Replicate_Count] [smallint] NOT NULL CONSTRAINT [DF_T_Quantitation_Defaults_Minimum_Peptide_Replicate_Count]  DEFAULT (0),
	[ORF_Coverage_Computation_Level] [tinyint] NOT NULL CONSTRAINT [DF_T_Quantitation_Defaults_ORF_Coverage_Computation_Level]  DEFAULT (1),
	[Internal_Std_Inclusion_Mode] [tinyint] NOT NULL CONSTRAINT [DF_T_Quantitation_Defaults_Internal_Std_Inclusion_Mode]  DEFAULT (0),
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
