/****** Object:  Table [dbo].[T_Peak_Matching_Activity] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Peak_Matching_Activity](
	[Assigned_Processor_Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Tool_Version] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Tool_Query_Date] [datetime] NULL,
	[Working] [tinyint] NOT NULL,
	[Server_Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Database_Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Task_ID] [int] NULL,
	[Job] [int] NULL,
	[Output_Folder_Path] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Task_Start] [datetime] NULL,
	[Task_Finish] [datetime] NULL,
	[Tasks_Completed] [int] NOT NULL,
	[Job_ID] [int] NULL,
 CONSTRAINT [PK_T_Peak_Matching_Activity] PRIMARY KEY CLUSTERED 
(
	[Assigned_Processor_Name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Peak_Matching_Activity] ADD  CONSTRAINT [DF_T_Peak_Matching_Activity_PM_ToolVersion]  DEFAULT ('Unknown') FOR [Tool_Version]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Activity] ADD  CONSTRAINT [DF_T_Peak_Matching_Activity_Working]  DEFAULT (0) FOR [Working]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Activity] ADD  CONSTRAINT [DF_T_Peak_Matching_Activity_TasksCompleted]  DEFAULT (0) FOR [Tasks_Completed]
GO
