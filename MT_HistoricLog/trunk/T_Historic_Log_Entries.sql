/****** Object:  Table [dbo].[T_Historic_Log_Entries] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Historic_Log_Entries](
	[Entry_ID] [int] NOT NULL,
	[posted_by] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[posting_time] [smalldatetime] NOT NULL,
	[type] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[message] [varchar](512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[DBName] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Entered_By] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Historic_Log_Entries] ******/
CREATE NONCLUSTERED INDEX [IX_T_Historic_Log_Entries] ON [dbo].[T_Historic_Log_Entries] 
(
	[Entry_ID] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF, FILLFACTOR = 90) ON [PRIMARY]
GO

/****** Object:  Index [IX_T_Historic_Log_Entries_DBName] ******/
CREATE NONCLUSTERED INDEX [IX_T_Historic_Log_Entries_DBName] ON [dbo].[T_Historic_Log_Entries] 
(
	[DBName] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF, FILLFACTOR = 90) ON [PRIMARY]
GO

/****** Object:  Index [IX_T_Historic_Log_Entries_Posted_By] ******/
CREATE NONCLUSTERED INDEX [IX_T_Historic_Log_Entries_Posted_By] ON [dbo].[T_Historic_Log_Entries] 
(
	[posted_by] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
GO

/****** Object:  Index [IX_T_Historic_Log_Entries_Posting_Time] ******/
CREATE NONCLUSTERED INDEX [IX_T_Historic_Log_Entries_Posting_Time] ON [dbo].[T_Historic_Log_Entries] 
(
	[posting_time] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF, FILLFACTOR = 90) ON [PRIMARY]
GO