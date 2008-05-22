/****** Object:  Table [dbo].[T_MultiAlign_Activity] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_MultiAlign_Activity](
	[Assigned_Processor_Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Tool_Version] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_MultiAlign_Activity_Tool_Version]  DEFAULT ('Unknown'),
	[Tool_Query_Date] [datetime] NULL,
	[Working] [tinyint] NOT NULL CONSTRAINT [DF_T_MultiAlign_Activity_Working]  DEFAULT ((0)),
	[Server_Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Database_Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Task_ID] [int] NULL,
	[Output_Folder_Path] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Task_Start] [datetime] NULL,
	[Task_Finish] [datetime] NULL,
	[Tasks_Completed] [int] NOT NULL CONSTRAINT [DF_T_MultiAlign_Activity_Tasks_Completed]  DEFAULT ((0)),
	[Job_ID] [int] NULL,
 CONSTRAINT [PK_T_MultiAlign_Activity] PRIMARY KEY CLUSTERED 
(
	[Assigned_Processor_Name] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
