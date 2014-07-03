/****** Object:  Table [dbo].[T_Sequence] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Sequence](
	[Seq_ID] [int] IDENTITY(1000,1) NOT NULL,
	[Clean_Sequence] [varchar](850) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Mod_Count] [smallint] NULL,
	[Mod_Description] [varchar](2048) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Monoisotopic_Mass] [float] NULL,
	[GANET_Predicted] [real] NULL,
	[Last_Affected] [smalldatetime] NULL,
 CONSTRAINT [PK_T_Sequence] PRIMARY KEY CLUSTERED 
(
	[Seq_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
GRANT INSERT ON [dbo].[T_Sequence] TO [DMS_SP_User] AS [dbo]
GO
GRANT UPDATE ON [dbo].[T_Sequence] ([Seq_ID]) TO [DMS_SP_User] AS [dbo]
GO
GRANT UPDATE ON [dbo].[T_Sequence] ([GANET_Predicted]) TO [DMS_SP_User] AS [dbo]
GO
GRANT UPDATE ON [dbo].[T_Sequence] ([Last_Affected]) TO [DMS_SP_User] AS [dbo]
GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [IX_T_Sequence] ******/
CREATE NONCLUSTERED INDEX [IX_T_Sequence] ON [dbo].[T_Sequence]
(
	[Clean_Sequence] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
GO
/****** Object:  Index [IX_T_Sequence_Mod_Count] ******/
CREATE NONCLUSTERED INDEX [IX_T_Sequence_Mod_Count] ON [dbo].[T_Sequence]
(
	[Mod_Count] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
GO
/****** Object:  Index [IX_T_Sequence_Monoisotopic_Mass] ******/
CREATE NONCLUSTERED INDEX [IX_T_Sequence_Monoisotopic_Mass] ON [dbo].[T_Sequence]
(
	[Monoisotopic_Mass] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_Sequence] ADD  CONSTRAINT [DF_T_Sequence_Last_Affected]  DEFAULT (getdate()) FOR [Last_Affected]
GO
