/****** Object:  Table [dbo].[T_Analysis_Job] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Analysis_Job](
	[Job_ID] [int] IDENTITY(10000,1) NOT NULL,
	[Priority] [smallint] NULL,
	[Job_Start] [datetime] NULL,
	[Job_Finish] [datetime] NULL,
	[Tool_ID] [int] NOT NULL,
	[Comment] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[State_ID] [int] NOT NULL,
	[Task_ID] [int] NOT NULL,
	[Task_Server] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Task_Database] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Assigned_Processor_Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Tool_Version] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[DMS_Job_Count] [int] NULL,
	[DMS_Job_Min] [int] NULL,
	[DMS_Job_Max] [int] NULL,
	[Output_Folder_Path] [varchar](512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Analysis_Manager_Error] [int] NOT NULL,
	[Analysis_Manager_Warning] [int] NOT NULL,
	[Analysis_Manager_ResultsID] [int] NULL,
	[Results_URL] [varchar](512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [T_Analysis_Job_PK] PRIMARY KEY CLUSTERED 
(
	[Job_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Analysis_Job]  WITH CHECK ADD  CONSTRAINT [FK_T_Analysis_Job_T_Analysis_Tool] FOREIGN KEY([Tool_ID])
REFERENCES [T_Analysis_Tool] ([Tool_ID])
GO
ALTER TABLE [dbo].[T_Analysis_Job] CHECK CONSTRAINT [FK_T_Analysis_Job_T_Analysis_Tool]
GO
ALTER TABLE [dbo].[T_Analysis_Job] ADD  CONSTRAINT [DF_T_Analysis_Job_Priority]  DEFAULT ((3)) FOR [Priority]
GO
ALTER TABLE [dbo].[T_Analysis_Job] ADD  CONSTRAINT [DF_T_Analysis_Job_Tool_ID]  DEFAULT ((0)) FOR [Tool_ID]
GO
ALTER TABLE [dbo].[T_Analysis_Job] ADD  CONSTRAINT [DF_T_Analysis_Job_State_ID]  DEFAULT ((1)) FOR [State_ID]
GO
ALTER TABLE [dbo].[T_Analysis_Job] ADD  CONSTRAINT [DF_T_Analysis_Job_Analysis_Manager_Error]  DEFAULT ((0)) FOR [Analysis_Manager_Error]
GO
ALTER TABLE [dbo].[T_Analysis_Job] ADD  CONSTRAINT [DF_T_Analysis_Job_Analysis_Manager_Warning]  DEFAULT ((0)) FOR [Analysis_Manager_Warning]
GO
