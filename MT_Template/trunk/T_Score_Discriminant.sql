/****** Object:  Table [dbo].[T_Score_Discriminant] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Score_Discriminant](
	[Peptide_ID] [int] NOT NULL,
	[MScore] [real] NULL,
	[DiscriminantScore] [float] NULL,
	[DiscriminantScoreNorm] [real] NULL,
	[PassFilt] [int] NULL,
	[Peptide_Prophet_FScore] [real] NULL,
	[Peptide_Prophet_Probability] [real] NULL,
 CONSTRAINT [PK_T_Score_Discriminant] PRIMARY KEY CLUSTERED 
(
	[Peptide_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Score_Discriminant] ******/
CREATE NONCLUSTERED INDEX [IX_T_Score_Discriminant] ON [dbo].[T_Score_Discriminant] 
(
	[DiscriminantScoreNorm] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 90) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_Score_Discriminant]  WITH CHECK ADD  CONSTRAINT [FK_T_Score_Discriminant_T_Peptides] FOREIGN KEY([Peptide_ID])
REFERENCES [T_Peptides] ([Peptide_ID])
GO
ALTER TABLE [dbo].[T_Score_Discriminant] CHECK CONSTRAINT [FK_T_Score_Discriminant_T_Peptides]
GO
