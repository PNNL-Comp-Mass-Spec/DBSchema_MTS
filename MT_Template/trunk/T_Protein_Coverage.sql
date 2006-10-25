/****** Object:  Table [dbo].[T_Protein_Coverage] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Protein_Coverage](
	[Ref_ID] [int] NOT NULL,
	[Coverage_PMTs] [real] NULL,
	[Coverage_Confirmed] [real] NULL,
	[Count_PMTs] [int] NOT NULL CONSTRAINT [DF_T_Protein_Coverage_CountPMT]  DEFAULT (0),
	[Count_PMTs_Full_Enzyme] [int] NOT NULL,
	[Count_PMTs_Partial_Enzyme] [int] NOT NULL,
	[Count_Confirmed] [int] NOT NULL CONSTRAINT [DF_T_Protein_Coverage_CountPeaks]  DEFAULT (0),
	[Total_MSMS_Observation_Count] [int] NOT NULL CONSTRAINT [DF_T_Protein_Coverage_CountPeptides]  DEFAULT (0),
	[High_Normalized_Score] [real] NOT NULL CONSTRAINT [DF_T_Protein_Coverage_HighScore]  DEFAULT (0),
	[High_Discriminant_Score] [real] NOT NULL,
	[PMT_Quality_Score_Minimum] [real] NOT NULL,
 CONSTRAINT [PK_T_Protein_Coverage] PRIMARY KEY CLUSTERED 
(
	[Ref_ID] ASC,
	[PMT_Quality_Score_Minimum] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Protein_Coverage]  WITH CHECK ADD  CONSTRAINT [FK_T_Protein_Coverage_T_Proteins] FOREIGN KEY([Ref_ID])
REFERENCES [T_Proteins] ([Ref_ID])
GO
ALTER TABLE [dbo].[T_Protein_Coverage] CHECK CONSTRAINT [FK_T_Protein_Coverage_T_Proteins]
GO
