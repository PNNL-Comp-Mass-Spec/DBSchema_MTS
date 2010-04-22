/****** Object:  Table [dbo].[T_Peak_Matching_Defaults] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Peak_Matching_Defaults](
	[Default_ID] [int] IDENTITY(100,1) NOT NULL,
	[Instrument_Name] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Dataset_Name_Filter] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Labelling_Filter] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[IniFile_Name] [varchar](185) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Confirmed_Only] [tinyint] NOT NULL,
	[Mod_List] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Minimum_High_Normalized_Score] [real] NOT NULL,
	[Minimum_High_Discriminant_Score] [real] NOT NULL,
	[Minimum_Peptide_Prophet_Probability] [real] NOT NULL,
	[Minimum_PMT_Quality_Score] [real] NOT NULL,
	[Priority] [int] NOT NULL,
 CONSTRAINT [PK_T_Peak_Matching_Defaults] PRIMARY KEY CLUSTERED 
(
	[Default_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Peak_Matching_Defaults] ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_T_Peak_Matching_Defaults] ON [dbo].[T_Peak_Matching_Defaults] 
(
	[Instrument_Name] ASC,
	[Dataset_Name_Filter] ASC,
	[Labelling_Filter] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Defaults] ADD  CONSTRAINT [DF_T_Peak_Matching_Defaults_Confirmed_Only]  DEFAULT (0) FOR [Confirmed_Only]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Defaults] ADD  CONSTRAINT [DF_T_Peak_Matching_Defaults_Mod_List]  DEFAULT ('') FOR [Mod_List]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Defaults] ADD  CONSTRAINT [DF_T_Peak_Matching_Defaults_Minimum_High_Normalized_Score]  DEFAULT (1.0) FOR [Minimum_High_Normalized_Score]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Defaults] ADD  CONSTRAINT [DF_T_Peak_Matching_Defaults_Minimum_High_Discriminant_Score]  DEFAULT (0) FOR [Minimum_High_Discriminant_Score]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Defaults] ADD  CONSTRAINT [DF_T_Peak_Matching_Defaults_Minimum_Peptide_Prophet_Probability]  DEFAULT (0) FOR [Minimum_Peptide_Prophet_Probability]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Defaults] ADD  CONSTRAINT [DF_T_Peak_Matching_Defaults_Minimum_PMT_Quality_Score]  DEFAULT (1) FOR [Minimum_PMT_Quality_Score]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Defaults] ADD  CONSTRAINT [DF_T_Peak_Matching_Defaults_Priority]  DEFAULT (5) FOR [Priority]
GO
