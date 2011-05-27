/****** Object:  Table [dbo].[T_Analysis_Description] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Analysis_Description](
	[Job] [int] NOT NULL,
	[Dataset] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Dataset_ID] [int] NOT NULL,
	[Dataset_Created_DMS] [datetime] NULL,
	[Dataset_Acq_Time_Start] [datetime] NULL,
	[Dataset_Acq_Time_End] [datetime] NULL,
	[Dataset_Acq_Length] [decimal](9, 2) NULL,
	[Dataset_Scan_Count] [int] NULL,
	[Experiment] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Campaign] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[PDB_ID] [int] NULL,
	[Dataset_SIC_Job] [int] NULL,
	[Experiment_Organism] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Instrument_Class] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Instrument] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Analysis_Tool] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Parameter_File_Name] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Settings_File_Name] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Organism_DB_Name] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Protein_Collection_List] [varchar](max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Protein_Options_List] [varchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Vol_Client] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Vol_Server] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Storage_Path] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Dataset_Folder] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Results_Folder] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Completed] [datetime] NULL,
	[ResultType] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Separation_Sys_Type] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[PreDigest_Internal_Std] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[PostDigest_Internal_Std] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Dataset_Internal_Std] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Enzyme_ID] [int] NULL,
	[Labelling] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Created_Peptide_DB] [datetime] NOT NULL,
	[Created_PMT_Tag_DB] [datetime] NOT NULL,
	[State] [int] NOT NULL,
	[Import_Priority] [int] NOT NULL,
	[PMTs_Last_Affected] [datetime] NULL,
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
 CONSTRAINT [PK_T_Analysis_Description] PRIMARY KEY CLUSTERED 
(
	[Job] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Analysis_Description_Job_Dataset_ID] ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_T_Analysis_Description_Job_Dataset_ID] ON [dbo].[T_Analysis_Description] 
(
	[Job] ASC,
	[Dataset_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 90) ON [PRIMARY]
GO

/****** Object:  Index [IX_T_Analysis_Description_Organism_DB_Name] ******/
CREATE NONCLUSTERED INDEX [IX_T_Analysis_Description_Organism_DB_Name] ON [dbo].[T_Analysis_Description] 
(
	[Job] ASC,
	[Organism_DB_Name] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
/****** Object:  Trigger [dbo].[trig_d_AnalysisDescription] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Trigger [dbo].[trig_d_AnalysisDescription] on [dbo].[T_Analysis_Description]
For Delete
AS
	If @@RowCount = 0
		Return

	INSERT INTO T_Event_Log	(Target_Type, Target_ID, Target_State, Prev_Target_State, Entered)
	SELECT 1, deleted.Job, 0, deleted.State, GetDate()
	FROM deleted
	order by deleted.Job

GO
/****** Object:  Trigger [dbo].[trig_i_AnalysisDescription] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Trigger [dbo].[trig_i_AnalysisDescription] on [dbo].[T_Analysis_Description]
For Insert
AS
	If @@RowCount = 0
		Return

	INSERT INTO T_Event_Log	(Target_Type, Target_ID, Target_State, Prev_Target_State, Entered)
	SELECT 1, inserted.Job, inserted.State, 0, GetDate()
	FROM inserted
	ORDER BY inserted.job

GO
/****** Object:  Trigger [dbo].[trig_u_AnalysisDescription] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Trigger [dbo].[trig_u_AnalysisDescription] on [dbo].[T_Analysis_Description]
For Update
AS
	If @@RowCount = 0
		Return

	if update(State)
		INSERT INTO T_Event_Log	(Target_Type, Target_ID, Target_State, Prev_Target_State, Entered)
		SELECT 1, inserted.Job, inserted.State, deleted.State, GetDate()
		FROM deleted INNER JOIN inserted ON deleted.Job = inserted.Job
		ORDER BY inserted.job

GO
ALTER TABLE [dbo].[T_Analysis_Description]  WITH NOCHECK ADD  CONSTRAINT [FK_T_Analysis_Description_T_Analysis_State_Name] FOREIGN KEY([State])
REFERENCES [T_Analysis_State_Name] ([AD_State_ID])
GO
ALTER TABLE [dbo].[T_Analysis_Description] CHECK CONSTRAINT [FK_T_Analysis_Description_T_Analysis_State_Name]
GO
ALTER TABLE [dbo].[T_Analysis_Description] ADD  CONSTRAINT [DF_T_Analysis_Description_Protein_Collection_List]  DEFAULT ('na') FOR [Protein_Collection_List]
GO
ALTER TABLE [dbo].[T_Analysis_Description] ADD  CONSTRAINT [DF_T_Analysis_Description_Protein_Options_List]  DEFAULT ('na') FOR [Protein_Options_List]
GO
ALTER TABLE [dbo].[T_Analysis_Description] ADD  CONSTRAINT [DF_T_Analysis_Description_Created_PMT_Tag_DB]  DEFAULT (getdate()) FOR [Created_PMT_Tag_DB]
GO
ALTER TABLE [dbo].[T_Analysis_Description] ADD  CONSTRAINT [DF_T_Analysis_Description_State]  DEFAULT ((1)) FOR [State]
GO
ALTER TABLE [dbo].[T_Analysis_Description] ADD  CONSTRAINT [DF_T_Analysis_Description_Import_Priority]  DEFAULT ((5)) FOR [Import_Priority]
GO
