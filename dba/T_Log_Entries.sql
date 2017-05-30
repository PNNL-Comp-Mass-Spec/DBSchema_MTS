/****** Object:  Table [dbo].[T_Log_Entries] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Log_Entries](
	[Entry_ID] [int] IDENTITY(1,1) NOT NULL,
	[posted_by] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[posting_time] [datetime] NULL,
	[type] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[message] [varchar](512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [PK_T_Log_Entries] PRIMARY KEY CLUSTERED 
(
	[Entry_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [IX_T_Log_Entries_Posted_By] ******/
CREATE NONCLUSTERED INDEX [IX_T_Log_Entries_Posted_By] ON [dbo].[T_Log_Entries]
(
	[posted_by] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
/****** Object:  Index [IX_T_Log_Entries_Posting_Time] ******/
CREATE NONCLUSTERED INDEX [IX_T_Log_Entries_Posting_Time] ON [dbo].[T_Log_Entries]
(
	[posting_time] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_Log_Entries] ADD  CONSTRAINT [DF_T_Log_Entries_posting_time]  DEFAULT (getdate()) FOR [posting_time]
GO
