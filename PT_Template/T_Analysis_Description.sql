/****** Object:  Table [dbo].[T_Analysis_Description] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Analysis_Description](
	[Job] [int] NOT NULL,
	[Dataset] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Dataset_ID] [int] NOT NULL,
	[Experiment] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Campaign] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Experiment_Organism] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Instrument_Class] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Instrument] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Analysis_Tool] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Parameter_File_Name] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Settings_File_Name] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Organism_DB_Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Protein_Collection_List] [varchar](max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Protein_Options_List] [varchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Vol_Client] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Vol_Server] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Storage_Path] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Dataset_Folder] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Results_Folder] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[MyEMSLState] [tinyint] NOT NULL,
	[Completed] [datetime] NULL,
	[ResultType] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Result_File_Suffix] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Separation_Sys_Type] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[PreDigest_Internal_Std] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[PostDigest_Internal_Std] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Dataset_Internal_Std] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Enzyme_ID] [int] NULL,
	[Labelling] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Created] [datetime] NOT NULL,
	[Last_Affected] [datetime] NULL,
	[Process_State] [int] NOT NULL,
	[Import_Priority] [int] NOT NULL,
	[RowCount_Loaded] [int] NULL,
	[GANET_Fit] [float] NULL,
	[GANET_Slope] [float] NULL,
	[GANET_Intercept] [float] NULL,
	[GANET_RSquared] [real] NULL,
	[ScanTime_NET_Slope] [real] NULL,
	[ScanTime_NET_Intercept] [real] NULL,
	[ScanTime_NET_RSquared] [real] NULL,
	[ScanTime_NET_Fit] [real] NULL,
	[Regression_Order] [tinyint] NULL,
	[Regression_Filtered_Data_Count] [int] NULL,
	[Regression_Equation] [varchar](512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Regression_Equation_XML] [varchar](max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Regression_Param_File] [varchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Retry_Load_Count] [tinyint] NOT NULL,
	[Regression_Failure_Count] [tinyint] NOT NULL,
 CONSTRAINT [PK_T_Analysis_Description] PRIMARY KEY CLUSTERED 
(
	[Job] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
GRANT UPDATE ON [dbo].[T_Analysis_Description] TO [pnl\svc-dms] AS [dbo]
GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [IX_T_Analysis_Description_Instrument] ******/
CREATE NONCLUSTERED INDEX [IX_T_Analysis_Description_Instrument] ON [dbo].[T_Analysis_Description]
(
	[Instrument] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
GO
/****** Object:  Index [IX_T_Analysis_Description_Process_State] ******/
CREATE NONCLUSTERED INDEX [IX_T_Analysis_Description_Process_State] ON [dbo].[T_Analysis_Description]
(
	[Process_State] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_Analysis_Description] ADD  CONSTRAINT [DF_T_Analysis_Description_Protein_Collection_List]  DEFAULT ('na') FOR [Protein_Collection_List]
GO
ALTER TABLE [dbo].[T_Analysis_Description] ADD  CONSTRAINT [DF_T_Analysis_Description_Protein_Options_List]  DEFAULT ('na') FOR [Protein_Options_List]
GO
ALTER TABLE [dbo].[T_Analysis_Description] ADD  CONSTRAINT [DF_T_Analysis_Description_MyEMSLState]  DEFAULT ((0)) FOR [MyEMSLState]
GO
ALTER TABLE [dbo].[T_Analysis_Description] ADD  CONSTRAINT [DF_T_Analysis_Description_Created]  DEFAULT (getdate()) FOR [Created]
GO
ALTER TABLE [dbo].[T_Analysis_Description] ADD  CONSTRAINT [DF_T_Analysis_Description_Process_State]  DEFAULT ((0)) FOR [Process_State]
GO
ALTER TABLE [dbo].[T_Analysis_Description] ADD  CONSTRAINT [DF_T_Analysis_Description_Import_Priority]  DEFAULT ((5)) FOR [Import_Priority]
GO
ALTER TABLE [dbo].[T_Analysis_Description] ADD  CONSTRAINT [DF_T_Analysis_Description_Regression_Param_File]  DEFAULT ('') FOR [Regression_Param_File]
GO
ALTER TABLE [dbo].[T_Analysis_Description] ADD  CONSTRAINT [DF_T_Analysis_Description_Retry_Load_Count]  DEFAULT ((0)) FOR [Retry_Load_Count]
GO
ALTER TABLE [dbo].[T_Analysis_Description] ADD  CONSTRAINT [DF_T_Analysis_Description_Regression_Failure_Count]  DEFAULT ((0)) FOR [Regression_Failure_Count]
GO
ALTER TABLE [dbo].[T_Analysis_Description]  WITH CHECK ADD  CONSTRAINT [FK_T_Analysis_Description_T_Datasets] FOREIGN KEY([Dataset_ID])
REFERENCES [dbo].[T_Datasets] ([Dataset_ID])
GO
ALTER TABLE [dbo].[T_Analysis_Description] CHECK CONSTRAINT [FK_T_Analysis_Description_T_Datasets]
GO
ALTER TABLE [dbo].[T_Analysis_Description]  WITH CHECK ADD  CONSTRAINT [FK_T_Analysis_Description_T_Process_State] FOREIGN KEY([Process_State])
REFERENCES [dbo].[T_Process_State] ([ID])
GO
ALTER TABLE [dbo].[T_Analysis_Description] CHECK CONSTRAINT [FK_T_Analysis_Description_T_Process_State]
GO
/****** Object:  Trigger [dbo].[trig_d_AnalysisJob] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Trigger [dbo].[trig_d_AnalysisJob] on [dbo].[T_Analysis_Description]
For Delete
AS
	If @@RowCount = 0
		Return

	INSERT INTO T_Event_Log	(Target_Type, Target_ID, Target_State, Prev_Target_State, Entered)
	SELECT 1, deleted.Job, 0, deleted.Process_State, GetDate()
	FROM deleted
	order by deleted.Job

GO
/****** Object:  Trigger [dbo].[trig_i_AnalysisJob] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Trigger trig_i_AnalysisJob on dbo.T_Analysis_Description
For Insert
AS
	If @@RowCount = 0
		Return

	INSERT INTO T_Event_Log	(Target_Type, Target_ID, Target_State, Prev_Target_State, Entered)
	SELECT 1, inserted.Job, inserted.Process_State, 0, GetDate()
	FROM inserted
	ORDER BY inserted.Job

GO
/****** Object:  Trigger [dbo].[trig_u_AnalysisJob] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Trigger trig_u_AnalysisJob on dbo.T_Analysis_Description
For Update
AS
	If @@RowCount = 0
		Return

	if update(Process_State)
		INSERT INTO T_Event_Log	(Target_Type, Target_ID, Target_State, Prev_Target_State, Entered)
		SELECT 1, inserted.Job, inserted.Process_State, deleted.Process_State, GetDate()
		FROM deleted INNER JOIN inserted ON deleted.Job = inserted.Job
		ORDER BY inserted.Job

GO
