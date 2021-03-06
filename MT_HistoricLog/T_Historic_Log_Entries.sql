/****** Object:  Table [dbo].[T_Historic_Log_Entries] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Historic_Log_Entries](
	[Entry_ID] [int] NOT NULL,
	[posted_by] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[posting_time] [smalldatetime] NOT NULL,
	[type] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[message] [varchar](4096) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[DBName] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Entered_By] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]

GO
/****** Object:  Index [IX_T_Historic_Log_Entries] ******/
CREATE NONCLUSTERED INDEX [IX_T_Historic_Log_Entries] ON [dbo].[T_Historic_Log_Entries]
(
	[Entry_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [IX_T_Historic_Log_Entries_DBName] ******/
CREATE NONCLUSTERED INDEX [IX_T_Historic_Log_Entries_DBName] ON [dbo].[T_Historic_Log_Entries]
(
	[DBName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [IX_T_Historic_Log_Entries_Posted_By] ******/
CREATE NONCLUSTERED INDEX [IX_T_Historic_Log_Entries_Posted_By] ON [dbo].[T_Historic_Log_Entries]
(
	[posted_by] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
GO
/****** Object:  Index [IX_T_Historic_Log_Entries_Posting_Time] ******/
CREATE NONCLUSTERED INDEX [IX_T_Historic_Log_Entries_Posting_Time] ON [dbo].[T_Historic_Log_Entries]
(
	[posting_time] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
GO
