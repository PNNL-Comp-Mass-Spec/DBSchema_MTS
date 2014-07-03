/****** Object:  Table [dbo].[T_Seq_Candidate_ModDetails] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Seq_Candidate_ModDetails](
	[Job] [int] NOT NULL,
	[Seq_ID_Local] [int] NOT NULL,
	[Mass_Correction_Tag] [char](8) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Position] [smallint] NOT NULL,
	[Seq_Candidate_ModDetail_ID] [int] IDENTITY(1,1) NOT NULL,
 CONSTRAINT [PK_T_Seq_Candidate_ModDetails] PRIMARY KEY CLUSTERED 
(
	[Seq_Candidate_ModDetail_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Index [IX_T_Seq_Candidate_ModDetails_Seq_ID_Local] ******/
CREATE NONCLUSTERED INDEX [IX_T_Seq_Candidate_ModDetails_Seq_ID_Local] ON [dbo].[T_Seq_Candidate_ModDetails]
(
	[Seq_ID_Local] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_Seq_Candidate_ModDetails]  WITH CHECK ADD  CONSTRAINT [FK_T_Seq_Candidate_ModDetails_T_Seq_Candidates] FOREIGN KEY([Job], [Seq_ID_Local])
REFERENCES [dbo].[T_Seq_Candidates] ([Job], [Seq_ID_Local])
GO
ALTER TABLE [dbo].[T_Seq_Candidate_ModDetails] CHECK CONSTRAINT [FK_T_Seq_Candidate_ModDetails_T_Seq_Candidates]
GO
