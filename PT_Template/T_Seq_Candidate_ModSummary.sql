/****** Object:  Table [dbo].[T_Seq_Candidate_ModSummary] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Seq_Candidate_ModSummary](
	[Job] [int] NOT NULL,
	[Modification_Symbol] [varchar](4) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Modification_Mass] [real] NOT NULL,
	[Target_Residues] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Modification_Type] [varchar](4) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Mass_Correction_Tag] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Occurrence_Count] [int] NULL,
	[Seq_Candidate_ModSummary_ID] [int] IDENTITY(1,1) NOT NULL,
 CONSTRAINT [PK_T_Seq_Candidate_ModSummary] PRIMARY KEY CLUSTERED 
(
	[Seq_Candidate_ModSummary_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [IX_T_Seq_Candidate_ModSummary_Mass_Correction_Tag] ******/
CREATE NONCLUSTERED INDEX [IX_T_Seq_Candidate_ModSummary_Mass_Correction_Tag] ON [dbo].[T_Seq_Candidate_ModSummary]
(
	[Mass_Correction_Tag] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_Seq_Candidate_ModSummary]  WITH CHECK ADD  CONSTRAINT [FK_T_Seq_Candidate_ModSummary_T_Analysis_Description] FOREIGN KEY([Job])
REFERENCES [dbo].[T_Analysis_Description] ([Job])
GO
ALTER TABLE [dbo].[T_Seq_Candidate_ModSummary] CHECK CONSTRAINT [FK_T_Seq_Candidate_ModSummary_T_Analysis_Description]
GO
