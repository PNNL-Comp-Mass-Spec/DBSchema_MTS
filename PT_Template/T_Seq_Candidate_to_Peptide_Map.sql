/****** Object:  Table [dbo].[T_Seq_Candidate_to_Peptide_Map] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Seq_Candidate_to_Peptide_Map](
	[Job] [int] NOT NULL,
	[Seq_ID_Local] [int] NOT NULL,
	[Peptide_ID] [int] NOT NULL,
 CONSTRAINT [PK_T_Seq_Candidate_to_Peptide_Map] PRIMARY KEY CLUSTERED 
(
	[Job] ASC,
	[Seq_ID_Local] ASC,
	[Peptide_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Seq_Candidate_to_Peptide_Map]  WITH CHECK ADD  CONSTRAINT [FK_T_Seq_Candidate_to_Peptide_Map_T_Peptides] FOREIGN KEY([Peptide_ID])
REFERENCES [dbo].[T_Peptides] ([Peptide_ID])
GO
ALTER TABLE [dbo].[T_Seq_Candidate_to_Peptide_Map] CHECK CONSTRAINT [FK_T_Seq_Candidate_to_Peptide_Map_T_Peptides]
GO
ALTER TABLE [dbo].[T_Seq_Candidate_to_Peptide_Map]  WITH CHECK ADD  CONSTRAINT [FK_T_Seq_Candidate_to_Peptide_Map_T_Seq_Candidates] FOREIGN KEY([Job], [Seq_ID_Local])
REFERENCES [dbo].[T_Seq_Candidates] ([Job], [Seq_ID_Local])
GO
ALTER TABLE [dbo].[T_Seq_Candidate_to_Peptide_Map] CHECK CONSTRAINT [FK_T_Seq_Candidate_to_Peptide_Map_T_Seq_Candidates]
GO
