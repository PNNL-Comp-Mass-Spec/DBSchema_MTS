/****** Object:  Table [dbo].[T_Seq_Candidates] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Seq_Candidates](
	[Job] [int] NOT NULL,
	[Seq_ID_Local] [int] NOT NULL,
	[Clean_Sequence] [varchar](850) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Mod_Count] [smallint] NOT NULL,
	[Mod_Description] [varchar](2048) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Monoisotopic_Mass] [float] NULL,
	[Seq_ID] [int] NULL,
	[Add_Sequence] [tinyint] NULL,
 CONSTRAINT [PK_T_Seq_Candidates] PRIMARY KEY CLUSTERED 
(
	[Job] ASC,
	[Seq_ID_Local] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
GRANT UPDATE ON [dbo].[T_Seq_Candidates] ([Seq_ID]) TO [DMS_SP_User] AS [dbo]
GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [IX_T_Seq_Candidates_CleanSequence] ******/
CREATE NONCLUSTERED INDEX [IX_T_Seq_Candidates_CleanSequence] ON [dbo].[T_Seq_Candidates]
(
	[Clean_Sequence] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
/****** Object:  Index [IX_T_Seq_Candidates_ModCount] ******/
CREATE NONCLUSTERED INDEX [IX_T_Seq_Candidates_ModCount] ON [dbo].[T_Seq_Candidates]
(
	[Mod_Count] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
/****** Object:  Index [IX_T_Seq_Candidates_Seq_ID_Local] ******/
CREATE NONCLUSTERED INDEX [IX_T_Seq_Candidates_Seq_ID_Local] ON [dbo].[T_Seq_Candidates]
(
	[Seq_ID_Local] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_Seq_Candidates] ADD  CONSTRAINT [DF_T_Seq_Candidates_Add_Sequence]  DEFAULT (0) FOR [Add_Sequence]
GO
ALTER TABLE [dbo].[T_Seq_Candidates]  WITH CHECK ADD  CONSTRAINT [FK_T_Seq_Candidates_T_Analysis_Description] FOREIGN KEY([Job])
REFERENCES [dbo].[T_Analysis_Description] ([Job])
GO
ALTER TABLE [dbo].[T_Seq_Candidates] CHECK CONSTRAINT [FK_T_Seq_Candidates_T_Analysis_Description]
GO
