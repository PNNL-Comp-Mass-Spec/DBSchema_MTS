/****** Object:  Table [dbo].[T_MyEMSL_FileCache] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_MyEMSL_FileCache](
	[Entry_ID] [int] IDENTITY(1,1) NOT NULL,
	[Job] [int] NOT NULL,
	[Filename] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[State] [tinyint] NOT NULL,
	[Cache_PathID] [int] NOT NULL,
	[Queued] [datetime] NOT NULL,
	[Optional] [tinyint] NOT NULL,
	[Task_ID] [int] NULL,
 CONSTRAINT [PK_T_MyEMSL_FileCache] PRIMARY KEY CLUSTERED 
(
	[Entry_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_MyEMSL_FileCache] ******/
CREATE NONCLUSTERED INDEX [IX_T_MyEMSL_FileCache] ON [dbo].[T_MyEMSL_FileCache] 
(
	[Task_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [IX_T_MyEMSL_FileCache_JobFile] ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_T_MyEMSL_FileCache_JobFile] ON [dbo].[T_MyEMSL_FileCache] 
(
	[Job] ASC,
	[Filename] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [IX_T_MyEMSL_FileCache_State] ******/
CREATE NONCLUSTERED INDEX [IX_T_MyEMSL_FileCache_State] ON [dbo].[T_MyEMSL_FileCache] 
(
	[State] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_MyEMSL_FileCache]  WITH CHECK ADD  CONSTRAINT [FK_T_MyEMSL_FileCache_T_MyEMSL_Cache_Paths] FOREIGN KEY([Cache_PathID])
REFERENCES [T_MyEMSL_Cache_Paths] ([Cache_PathID])
GO
ALTER TABLE [dbo].[T_MyEMSL_FileCache] CHECK CONSTRAINT [FK_T_MyEMSL_FileCache_T_MyEMSL_Cache_Paths]
GO
ALTER TABLE [dbo].[T_MyEMSL_FileCache]  WITH CHECK ADD  CONSTRAINT [FK_T_MyEMSL_FileCache_T_MyEMSL_Cache_State] FOREIGN KEY([State])
REFERENCES [T_MyEMSL_Cache_State] ([State])
GO
ALTER TABLE [dbo].[T_MyEMSL_FileCache] CHECK CONSTRAINT [FK_T_MyEMSL_FileCache_T_MyEMSL_Cache_State]
GO
ALTER TABLE [dbo].[T_MyEMSL_FileCache]  WITH CHECK ADD  CONSTRAINT [FK_T_MyEMSL_FileCache_T_MyEMSL_Cache_Task] FOREIGN KEY([Task_ID])
REFERENCES [T_MyEMSL_Cache_Task] ([Task_ID])
GO
ALTER TABLE [dbo].[T_MyEMSL_FileCache] CHECK CONSTRAINT [FK_T_MyEMSL_FileCache_T_MyEMSL_Cache_Task]
GO
ALTER TABLE [dbo].[T_MyEMSL_FileCache] ADD  CONSTRAINT [DF_Table_1_Entered]  DEFAULT (getdate()) FOR [Queued]
GO
ALTER TABLE [dbo].[T_MyEMSL_FileCache] ADD  CONSTRAINT [DF_T_MyEMSL_FileCache_Optional]  DEFAULT ((0)) FOR [Optional]
GO
