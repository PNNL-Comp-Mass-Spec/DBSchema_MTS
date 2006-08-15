/****** Object:  Table [dbo].[T_Score_Sequest] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Score_Sequest](
	[Peptide_ID] [int] NOT NULL,
	[XCorr] [real] NULL,
	[DeltaCn] [real] NULL,
	[DeltaCn2] [real] NULL,
	[Sp] [float] NULL,
	[RankSp] [int] NULL,
	[RankXc] [int] NULL,
	[DelM] [float] NULL,
	[XcRatio] [real] NULL,
 CONSTRAINT [PK_T_Score_Sequest] PRIMARY KEY CLUSTERED 
(
	[Peptide_ID] ASC
)WITH FILLFACTOR = 90 ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Score_Sequest]  WITH CHECK ADD  CONSTRAINT [FK_T_Score_Sequest_T_Peptides] FOREIGN KEY([Peptide_ID])
REFERENCES [T_Peptides] ([Peptide_ID])
GO
ALTER TABLE [dbo].[T_Score_Sequest] CHECK CONSTRAINT [FK_T_Score_Sequest_T_Peptides]
GO
