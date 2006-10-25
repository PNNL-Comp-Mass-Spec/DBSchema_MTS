/****** Object:  Table [dbo].[T_Mass_Tag_Peptide_Prophet_Stats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Mass_Tag_Peptide_Prophet_Stats](
	[Mass_Tag_ID] [int] NOT NULL,
	[ObsCount_CS1] [int] NULL CONSTRAINT [DF_T_Mass_Tag_Peptide_Prophet_Stats_ObsCount_CS1]  DEFAULT (0),
	[ObsCount_CS2] [int] NULL CONSTRAINT [DF_T_Mass_Tag_Peptide_Prophet_Stats_ObsCount_CS2]  DEFAULT (0),
	[ObsCount_CS3] [int] NULL CONSTRAINT [DF_T_Mass_Tag_Peptide_Prophet_Stats_ObsCount_CS3]  DEFAULT (0),
	[PepProphet_FScore_Max_CS1] [real] NULL CONSTRAINT [DF_T_Mass_Tag_Peptide_Prophet_Stats_PepProphet_FScore_Max_CS1]  DEFAULT ((-100)),
	[PepProphet_FScore_Max_CS2] [real] NULL CONSTRAINT [DF_T_Mass_Tag_Peptide_Prophet_Stats_PepProphet_FScore_Max_CS2]  DEFAULT ((-100)),
	[PepProphet_FScore_Max_CS3] [real] NULL CONSTRAINT [DF_T_Mass_Tag_Peptide_Prophet_Stats_PepProphet_FScore_Max_CS3]  DEFAULT ((-100)),
	[PepProphet_Probability_Max_CS1] [real] NULL CONSTRAINT [DF_T_Mass_Tag_Peptide_Prophet_Stats_PepProphet_Probability_Max_CS1]  DEFAULT ((-100)),
	[PepProphet_Probability_Max_CS2] [real] NULL CONSTRAINT [DF_T_Mass_Tag_Peptide_Prophet_Stats_PepProphet_Probability_Max_CS2]  DEFAULT ((-100)),
	[PepProphet_Probability_Max_CS3] [real] NULL CONSTRAINT [DF_T_Mass_Tag_Peptide_Prophet_Stats_PepProphet_Probability_Max_CS3]  DEFAULT ((-100)),
	[PepProphet_Probability_Avg_CS1] [real] NULL CONSTRAINT [DF_T_Mass_Tag_Peptide_Prophet_Stats_PepProphet_Probability_Avg_CS1]  DEFAULT ((-100)),
	[PepProphet_Probability_Avg_CS2] [real] NULL CONSTRAINT [DF_T_Mass_Tag_Peptide_Prophet_Stats_PepProphet_Probability_Avg_CS2]  DEFAULT ((-100)),
	[PepProphet_Probability_Avg_CS3] [real] NULL CONSTRAINT [DF_T_Mass_Tag_Peptide_Prophet_Stats_PepProphet_Probability_Avg_CS3]  DEFAULT ((-100)),
 CONSTRAINT [PK_T_Mass_Tag_Peptide_Prophet_Stats] PRIMARY KEY CLUSTERED 
(
	[Mass_Tag_ID] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Mass_Tag_Peptide_Prophet_Stats]  WITH CHECK ADD  CONSTRAINT [FK_T_Mass_Tag_Peptide_Prophet_Stats_T_Mass_Tags] FOREIGN KEY([Mass_Tag_ID])
REFERENCES [T_Mass_Tags] ([Mass_Tag_ID])
GO
ALTER TABLE [dbo].[T_Mass_Tag_Peptide_Prophet_Stats] CHECK CONSTRAINT [FK_T_Mass_Tag_Peptide_Prophet_Stats_T_Mass_Tags]
GO
