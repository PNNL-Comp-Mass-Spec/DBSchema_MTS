/****** Object:  Table [dbo].[T_Score_Inspect] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Score_Inspect](
	[Peptide_ID] [int] NOT NULL,
	[MQScore] [real] NULL,
	[TotalPRMScore] [real] NULL,
	[MedianPRMScore] [real] NULL,
	[FractionY] [real] NULL,
	[FractionB] [real] NULL,
	[Intensity] [real] NULL,
	[PValue] [real] NULL,
	[FScore] [real] NULL,
	[DeltaScore] [real] NULL,
	[DeltaScoreOther] [real] NULL,
	[DeltaNormMQScore] [real] NULL,
	[DeltaNormTotalPRMScore] [real] NULL,
	[RankTotalPRMScore] [smallint] NULL,
	[RankFScore] [smallint] NULL,
	[DelM] [real] NULL,
	[Normalized_Score] [real] NULL,
	[PrecursorError] [real] NULL,
 CONSTRAINT [PK_T_Score_Inspect] PRIMARY KEY CLUSTERED 
(
	[Peptide_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Score_Inspect]  WITH CHECK ADD  CONSTRAINT [FK_T_Score_Inspect_T_Peptides] FOREIGN KEY([Peptide_ID])
REFERENCES [T_Peptides] ([Peptide_ID])
GO
ALTER TABLE [dbo].[T_Score_Inspect] CHECK CONSTRAINT [FK_T_Score_Inspect_T_Peptides]
GO
