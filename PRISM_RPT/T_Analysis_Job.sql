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
	[AMT_Count_1pct_FDR] [int] NULL,
	[AMT_Count_5pct_FDR] [int] NULL,
	[AMT_Count_10pct_FDR] [int] NULL,
	[AMT_Count_25pct_FDR] [int] NULL,
	[AMT_Count_50pct_FDR] [int] NULL,
	[Refine_Mass_Cal_PPMShift] [numeric](9, 4) NULL,
	[MD_ID] [int] NULL,
	[QID] [int] NULL,
	[Ini_File_Name] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Comparison_Mass_Tag_Count] [int] NULL,
	[MD_State] [tinyint] NULL,
 CONSTRAINT [T_Analysis_Job_PK] PRIMARY KEY CLUSTERED 
(
	[Job_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [IX_T_Analysis_Job_Server_Database] ******/
CREATE NONCLUSTERED INDEX [IX_T_Analysis_Job_Server_Database] ON [dbo].[T_Analysis_Job]
(
	[Task_Server] ASC,
	[Task_Database] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [IX_T_Analysis_Job_ToolID_TaskDB] ******/
CREATE NONCLUSTERED INDEX [IX_T_Analysis_Job_ToolID_TaskDB] ON [dbo].[T_Analysis_Job]
(
	[Tool_ID] ASC,
	[Task_Database] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
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
ALTER TABLE [dbo].[T_Analysis_Job]  WITH CHECK ADD  CONSTRAINT [FK_T_Analysis_Job_T_Analysis_Job_State_Name] FOREIGN KEY([State_ID])
REFERENCES [dbo].[T_Analysis_Job_State_Name] ([State_ID])
GO
ALTER TABLE [dbo].[T_Analysis_Job] CHECK CONSTRAINT [FK_T_Analysis_Job_T_Analysis_Job_State_Name]
GO
ALTER TABLE [dbo].[T_Analysis_Job]  WITH CHECK ADD  CONSTRAINT [FK_T_Analysis_Job_T_Analysis_Tool] FOREIGN KEY([Tool_ID])
REFERENCES [dbo].[T_Analysis_Tool] ([Tool_ID])
GO
ALTER TABLE [dbo].[T_Analysis_Job] CHECK CONSTRAINT [FK_T_Analysis_Job_T_Analysis_Tool]
GO
