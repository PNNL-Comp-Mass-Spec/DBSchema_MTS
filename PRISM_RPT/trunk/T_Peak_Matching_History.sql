/****** Object:  Table [dbo].[T_Peak_Matching_History] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Peak_Matching_History](
	[PM_History_ID] [int] IDENTITY(1,1) NOT NULL,
	[PM_AssignedProcessorName] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[PM_ToolVersion] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_Peak_Matching_History_PM_ToolVersion]  DEFAULT ('Unknown'),
	[Server_Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[MTDBName] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[TaskID] [int] NOT NULL,
	[Job] [int] NOT NULL,
	[Output_Folder_Path] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[PM_Start] [datetime] NULL,
	[PM_Finish] [datetime] NULL,
 CONSTRAINT [PK_T_Peak_Matching_History] PRIMARY KEY CLUSTERED 
(
	[PM_History_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Peak_Matching_History_MTDBName] ******/
CREATE NONCLUSTERED INDEX [IX_T_Peak_Matching_History_MTDBName] ON [dbo].[T_Peak_Matching_History] 
(
	[MTDBName] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [IX_T_Peak_Matching_History_ProcessorName] ******/
CREATE NONCLUSTERED INDEX [IX_T_Peak_Matching_History_ProcessorName] ON [dbo].[T_Peak_Matching_History] 
(
	[PM_AssignedProcessorName] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
