/****** Object:  Table [dbo].[T_Mass_Tags] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Mass_Tags](
	[Mass_Tag_ID] [int] NOT NULL,
	[Peptide] [varchar](850) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Monoisotopic_Mass] [float] NULL,
	[Is_Confirmed] [tinyint] NOT NULL,
	[Confidence_Factor] [real] NULL,
	[Multiple_Proteins] [smallint] NULL,
	[Created] [datetime] NULL,
	[Last_Affected] [datetime] NULL,
	[Number_Of_Peptides] [int] NULL,
	[Peptide_Obs_Count_Passing_Filter] [int] NULL,
	[High_Normalized_Score] [real] NULL,
	[High_Discriminant_Score] [real] NULL,
	[High_Peptide_Prophet_Probability] [real] NULL,
	[Number_Of_FTICR] [int] NULL,
	[Mod_Count] [int] NOT NULL,
	[Mod_Description] [varchar](2048) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[PMT_Quality_Score] [numeric](9, 5) NULL,
	[Internal_Standard_Only] [tinyint] NOT NULL,
	[Min_Log_EValue] [real] NULL,
	[Cleavage_State_Max] [tinyint] NOT NULL,
	[PeptideEx] [varchar](512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [PK_T_Mass_Tags] PRIMARY KEY CLUSTERED 
(
	[Mass_Tag_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Mass_Tags] ******/
CREATE NONCLUSTERED INDEX [IX_T_Mass_Tags] ON [dbo].[T_Mass_Tags] 
(
	[Peptide] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 90) ON [PRIMARY]
GO

/****** Object:  Index [IX_T_Mass_Tags_DiscriminantScore] ******/
CREATE NONCLUSTERED INDEX [IX_T_Mass_Tags_DiscriminantScore] ON [dbo].[T_Mass_Tags] 
(
	[High_Discriminant_Score] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [IX_T_Mass_Tags_ModCount] ******/
CREATE NONCLUSTERED INDEX [IX_T_Mass_Tags_ModCount] ON [dbo].[T_Mass_Tags] 
(
	[Mod_Count] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [IX_T_Mass_Tags_PeptideProphetProbability] ******/
CREATE NONCLUSTERED INDEX [IX_T_Mass_Tags_PeptideProphetProbability] ON [dbo].[T_Mass_Tags] 
(
	[High_Peptide_Prophet_Probability] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [IX_T_Mass_Tags_PMTQS] ******/
CREATE NONCLUSTERED INDEX [IX_T_Mass_Tags_PMTQS] ON [dbo].[T_Mass_Tags] 
(
	[PMT_Quality_Score] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_Mass_Tags] ADD  CONSTRAINT [DF_T_MassTags_Is_Confirmed]  DEFAULT (0) FOR [Is_Confirmed]
GO
ALTER TABLE [dbo].[T_Mass_Tags] ADD  CONSTRAINT [DF_T_Mass_Tags_Created]  DEFAULT (getdate()) FOR [Created]
GO
ALTER TABLE [dbo].[T_Mass_Tags] ADD  CONSTRAINT [DF_T_Mass_Tags_Last_Affected]  DEFAULT (getdate()) FOR [Last_Affected]
GO
ALTER TABLE [dbo].[T_Mass_Tags] ADD  CONSTRAINT [DF_T_Mass_Tags_Peptide_Obs_Count_Passing_Filter]  DEFAULT (0) FOR [Peptide_Obs_Count_Passing_Filter]
GO
ALTER TABLE [dbo].[T_Mass_Tags] ADD  CONSTRAINT [DF_T_Mass_Tags_PMT_Quality_Score]  DEFAULT (0) FOR [PMT_Quality_Score]
GO
ALTER TABLE [dbo].[T_Mass_Tags] ADD  CONSTRAINT [DF_T_Mass_Tags_Is_Internal_Standard]  DEFAULT (0) FOR [Internal_Standard_Only]
GO
ALTER TABLE [dbo].[T_Mass_Tags] ADD  CONSTRAINT [DF_T_Mass_Tags_Min_Log_EValue]  DEFAULT ((0)) FOR [Min_Log_EValue]
GO
ALTER TABLE [dbo].[T_Mass_Tags] ADD  CONSTRAINT [DF_T_Mass_Tags_Cleavage_State_Max]  DEFAULT ((0)) FOR [Cleavage_State_Max]
GO
