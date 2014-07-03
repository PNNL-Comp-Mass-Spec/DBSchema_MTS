/****** Object:  Table [dbo].[T_Score_MSGFDB] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Score_MSGFDB](
	[Peptide_ID] [int] NOT NULL,
	[FragMethod] [varchar](24) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[PrecursorMZ] [real] NULL,
	[DelM] [real] NULL,
	[DeNovoScore] [real] NULL,
	[MSGFScore] [real] NULL,
	[SpecProb] [real] NULL,
	[RankSpecProb] [smallint] NULL,
	[PValue] [real] NULL,
	[Normalized_Score] [real] NULL,
	[FDR] [real] NULL,
	[PepFDR] [real] NULL,
 CONSTRAINT [PK_T_Score_MSGFDB] PRIMARY KEY CLUSTERED 
(
	[Peptide_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Score_MSGFDB]  WITH CHECK ADD  CONSTRAINT [FK_T_Score_MSGFDB_T_Peptides] FOREIGN KEY([Peptide_ID])
REFERENCES [dbo].[T_Peptides] ([Peptide_ID])
GO
ALTER TABLE [dbo].[T_Score_MSGFDB] CHECK CONSTRAINT [FK_T_Score_MSGFDB_T_Peptides]
GO
