/****** Object:  Table [dbo].[BlitzFirst_WaitStats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BlitzFirst_WaitStats](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[ServerName] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[CheckDate] [datetimeoffset](7) NULL,
	[wait_type] [nvarchar](60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[wait_time_ms] [bigint] NULL,
	[signal_wait_time_ms] [bigint] NULL,
	[waiting_tasks_count] [bigint] NULL,
 CONSTRAINT [PK_FB8AC682-6790-4C76-AD2B-3D1EFC9334D9] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [IX_ServerName_wait_type_CheckDate_Includes] ******/
CREATE NONCLUSTERED INDEX [IX_ServerName_wait_type_CheckDate_Includes] ON [dbo].[BlitzFirst_WaitStats]
(
	[ServerName] ASC,
	[wait_type] ASC,
	[CheckDate] ASC
)
INCLUDE ( 	[wait_time_ms],
	[signal_wait_time_ms],
	[waiting_tasks_count]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
GO
