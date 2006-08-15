/****** Object:  Table [dbo].[T_Usage_Log] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Usage_Log](
	[Entry_ID] [int] IDENTITY(1,1) NOT NULL,
	[Posted_By] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Posting_time] [datetime] NOT NULL CONSTRAINT [DF_T_Usage_Log_Posting_time]  DEFAULT (getdate()),
	[Target_DB_Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Message] [varchar](4096) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Calling_User] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Usage_Count] [int] NULL,
 CONSTRAINT [PK_T_Usage_Log] PRIMARY KEY CLUSTERED 
(
	[Entry_ID] ASC
)WITH FILLFACTOR = 90 ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Usage_Log_Calling_User] ******/
CREATE NONCLUSTERED INDEX [IX_T_Usage_Log_Calling_User] ON [dbo].[T_Usage_Log] 
(
	[Calling_User] ASC
) ON [PRIMARY]
GO

/****** Object:  Index [IX_T_Usage_Log_Posted_By] ******/
CREATE NONCLUSTERED INDEX [IX_T_Usage_Log_Posted_By] ON [dbo].[T_Usage_Log] 
(
	[Posted_By] ASC
)WITH FILLFACTOR = 90 ON [PRIMARY]
GO

/****** Object:  Index [IX_T_Usage_Log_Target_DB_Name] ******/
CREATE NONCLUSTERED INDEX [IX_T_Usage_Log_Target_DB_Name] ON [dbo].[T_Usage_Log] 
(
	[Target_DB_Name] ASC
)WITH FILLFACTOR = 90 ON [PRIMARY]
GO
