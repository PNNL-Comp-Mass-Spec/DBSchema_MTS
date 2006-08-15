/****** Object:  Table [dbo].[T_Log_Entries] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Log_Entries](
	[Entry_ID] [int] IDENTITY(1,1) NOT NULL,
	[posted_by] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[posting_time] [datetime] NOT NULL,
	[type] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[message] [varchar](244) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [PK_T_Log_Entries] PRIMARY KEY CLUSTERED 
(
	[Entry_ID] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Log_Entries_Type] ******/
CREATE NONCLUSTERED INDEX [IX_T_Log_Entries_Type] ON [dbo].[T_Log_Entries] 
(
	[type] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
GO
GRANT INSERT ON [dbo].[T_Log_Entries] TO [DMS_SP_User]
GO
