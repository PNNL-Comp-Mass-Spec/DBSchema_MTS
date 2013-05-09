/****** Object:  Table [dbo].[T_Current_Activity_History] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Current_Activity_History](
	[History_ID] [int] IDENTITY(1,1) NOT NULL,
	[Database_ID] [int] NOT NULL,
	[Database_Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Snapshot_Date] [datetime] NOT NULL,
	[TableCount1] [int] NULL,
	[TableCount2] [int] NULL,
	[TableCount3] [int] NULL,
	[TableCount4] [int] NULL,
	[Update_Completion_Date] [datetime] NULL,
	[Pause_Length_Minutes] [real] NOT NULL,
 CONSTRAINT [PK_T_Current_Activity_History] PRIMARY KEY NONCLUSTERED 
(
	[History_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Current_Activity_History] ******/
CREATE CLUSTERED INDEX [IX_T_Current_Activity_History] ON [dbo].[T_Current_Activity_History] 
(
	[Database_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 90) ON [PRIMARY]
GO

/****** Object:  Index [IX_T_Current_Activity_History_Snapshot_Date] ******/
CREATE NONCLUSTERED INDEX [IX_T_Current_Activity_History_Snapshot_Date] ON [dbo].[T_Current_Activity_History] 
(
	[Snapshot_Date] ASC
)
INCLUDE ( [History_ID],
[Database_ID]) WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_Current_Activity_History] ADD  CONSTRAINT [DF_T_Current_Activity_History_Pause_Length_Minutes]  DEFAULT (0) FOR [Pause_Length_Minutes]
GO
