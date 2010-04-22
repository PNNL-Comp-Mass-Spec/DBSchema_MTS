/****** Object:  Table [dbo].[T_Mass_Tag_Peptide_Prophet_Stats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Mass_Tag_Peptide_Prophet_Stats](
	[Mass_Tag_ID] [int] NOT NULL,
	[ObsCount_CS1] [int] NULL,
	[ObsCount_CS2] [int] NULL,
	[ObsCount_CS3] [int] NULL,
	[PepProphet_FScore_Max_CS1] [real] NULL,
	[PepProphet_FScore_Max_CS2] [real] NULL,
	[PepProphet_FScore_Max_CS3] [real] NULL,
	[PepProphet_Probability_Max_CS1] [real] NULL,
	[PepProphet_Probability_Max_CS2] [real] NULL,
	[PepProphet_Probability_Max_CS3] [real] NULL,
	[PepProphet_FScore_Avg_CS1] [real] NULL,
	[PepProphet_FScore_Avg_CS2] [real] NULL,
	[PepProphet_FScore_Avg_CS3] [real] NULL,
	[Cleavage_State_Max] [tinyint] NULL,
 CONSTRAINT [PK_T_Mass_Tag_Peptide_Prophet_Stats] PRIMARY KEY CLUSTERED 
(
	[Mass_Tag_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Mass_Tag_Peptide_Prophet_Stats]  WITH CHECK ADD  CONSTRAINT [FK_T_Mass_Tag_Peptide_Prophet_Stats_T_Mass_Tags] FOREIGN KEY([Mass_Tag_ID])
REFERENCES [T_Mass_Tags] ([Mass_Tag_ID])
GO
ALTER TABLE [dbo].[T_Mass_Tag_Peptide_Prophet_Stats] CHECK CONSTRAINT [FK_T_Mass_Tag_Peptide_Prophet_Stats_T_Mass_Tags]
GO
ALTER TABLE [dbo].[T_Mass_Tag_Peptide_Prophet_Stats] ADD  CONSTRAINT [DF_T_Mass_Tag_Peptide_Prophet_Stats_ObsCount_CS1]  DEFAULT (0) FOR [ObsCount_CS1]
GO
ALTER TABLE [dbo].[T_Mass_Tag_Peptide_Prophet_Stats] ADD  CONSTRAINT [DF_T_Mass_Tag_Peptide_Prophet_Stats_ObsCount_CS2]  DEFAULT (0) FOR [ObsCount_CS2]
GO
ALTER TABLE [dbo].[T_Mass_Tag_Peptide_Prophet_Stats] ADD  CONSTRAINT [DF_T_Mass_Tag_Peptide_Prophet_Stats_ObsCount_CS3]  DEFAULT (0) FOR [ObsCount_CS3]
GO
ALTER TABLE [dbo].[T_Mass_Tag_Peptide_Prophet_Stats] ADD  CONSTRAINT [DF_T_Mass_Tag_Peptide_Prophet_Stats_PepProphet_FScore_Max_CS1]  DEFAULT ((-100)) FOR [PepProphet_FScore_Max_CS1]
GO
ALTER TABLE [dbo].[T_Mass_Tag_Peptide_Prophet_Stats] ADD  CONSTRAINT [DF_T_Mass_Tag_Peptide_Prophet_Stats_PepProphet_FScore_Max_CS2]  DEFAULT ((-100)) FOR [PepProphet_FScore_Max_CS2]
GO
ALTER TABLE [dbo].[T_Mass_Tag_Peptide_Prophet_Stats] ADD  CONSTRAINT [DF_T_Mass_Tag_Peptide_Prophet_Stats_PepProphet_FScore_Max_CS3]  DEFAULT ((-100)) FOR [PepProphet_FScore_Max_CS3]
GO
ALTER TABLE [dbo].[T_Mass_Tag_Peptide_Prophet_Stats] ADD  CONSTRAINT [DF_T_Mass_Tag_Peptide_Prophet_Stats_PepProphet_Probability_Max_CS1]  DEFAULT ((-100)) FOR [PepProphet_Probability_Max_CS1]
GO
ALTER TABLE [dbo].[T_Mass_Tag_Peptide_Prophet_Stats] ADD  CONSTRAINT [DF_T_Mass_Tag_Peptide_Prophet_Stats_PepProphet_Probability_Max_CS2]  DEFAULT ((-100)) FOR [PepProphet_Probability_Max_CS2]
GO
ALTER TABLE [dbo].[T_Mass_Tag_Peptide_Prophet_Stats] ADD  CONSTRAINT [DF_T_Mass_Tag_Peptide_Prophet_Stats_PepProphet_Probability_Max_CS3]  DEFAULT ((-100)) FOR [PepProphet_Probability_Max_CS3]
GO
ALTER TABLE [dbo].[T_Mass_Tag_Peptide_Prophet_Stats] ADD  CONSTRAINT [DF_T_Mass_Tag_Peptide_Prophet_Stats_PepProphet_Probability_Avg_CS1]  DEFAULT ((-100)) FOR [PepProphet_FScore_Avg_CS1]
GO
ALTER TABLE [dbo].[T_Mass_Tag_Peptide_Prophet_Stats] ADD  CONSTRAINT [DF_T_Mass_Tag_Peptide_Prophet_Stats_PepProphet_Probability_Avg_CS2]  DEFAULT ((-100)) FOR [PepProphet_FScore_Avg_CS2]
GO
ALTER TABLE [dbo].[T_Mass_Tag_Peptide_Prophet_Stats] ADD  CONSTRAINT [DF_T_Mass_Tag_Peptide_Prophet_Stats_PepProphet_Probability_Avg_CS3]  DEFAULT ((-100)) FOR [PepProphet_FScore_Avg_CS3]
GO
