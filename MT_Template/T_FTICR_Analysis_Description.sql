/****** Object:  Table [dbo].[T_FTICR_Analysis_Description] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_FTICR_Analysis_Description](
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
	[Experiment_Organism] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Instrument_Class] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Instrument] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Analysis_Tool] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Parameter_File_Name] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Settings_File_Name] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Organism_DB_Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Protein_Collection_List] [varchar](2048) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Protein_Options_List] [varchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Vol_Client] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Vol_Server] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Storage_Path] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Dataset_Folder] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Results_Folder] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[MyEMSLState] [tinyint] NOT NULL,
	[Completed] [datetime] NULL,
	[ResultType] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Separation_Sys_Type] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[PreDigest_Internal_Std] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[PostDigest_Internal_Std] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Dataset_Internal_Std] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Labelling] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Created] [datetime] NOT NULL,
	[Auto_Addition] [tinyint] NOT NULL,
	[State] [int] NOT NULL,
	[GANET_Fit] [float] NULL,
	[GANET_Slope] [float] NULL,
	[GANET_Intercept] [float] NULL,
	[Total_Scans] [int] NULL,
	[Scan_Start] [int] NULL,
	[Scan_End] [int] NULL,
	[Duration] [real] NULL,
 CONSTRAINT [PK_T_FTICR_Analysis_Description] PRIMARY KEY CLUSTERED 
(
	[Job] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Trigger [dbo].[trig_d_FTICRAnalysisDescription] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Trigger [dbo].[trig_d_FTICRAnalysisDescription] on [dbo].[T_FTICR_Analysis_Description]
For Delete
AS
	If @@RowCount = 0
		Return

	INSERT INTO T_Event_Log	(Target_Type, Target_ID, Target_State, Prev_Target_State, Entered)
	SELECT 2, deleted.Job, 0, deleted.State, GetDate()
	FROM deleted
	order by deleted.Job

GO
/****** Object:  Trigger [dbo].[trig_i_FTICRAnalysisDescription] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Trigger [dbo].[trig_i_FTICRAnalysisDescription] on [dbo].[T_FTICR_Analysis_Description]
For Insert
AS
	If @@RowCount = 0
		Return

	INSERT INTO T_Event_Log	(Target_Type, Target_ID, Target_State, Prev_Target_State, Entered)
	SELECT 2, inserted.Job, inserted.State, 0, GetDate()
	FROM inserted
	ORDER BY inserted.Job

GO
/****** Object:  Trigger [dbo].[trig_u_FTICRAnalysisDescription] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Trigger [dbo].[trig_u_FTICRAnalysisDescription] on [dbo].[T_FTICR_Analysis_Description]
For Update
AS
	If @@RowCount = 0
		Return

	if update(State)
		INSERT INTO T_Event_Log	(Target_Type, Target_ID, Target_State, Prev_Target_State, Entered)
		SELECT 2, inserted.Job, inserted.State, deleted.State, GetDate()
		FROM deleted INNER JOIN inserted ON deleted.Job = inserted.Job
		ORDER BY inserted.Job

GO
ALTER TABLE [dbo].[T_FTICR_Analysis_Description]  WITH CHECK ADD  CONSTRAINT [FK_T_FTICR_Analysis_Description_T_FAD_State_Name] FOREIGN KEY([State])
REFERENCES [T_FAD_State_Name] ([FAD_State_ID])
GO
ALTER TABLE [dbo].[T_FTICR_Analysis_Description] CHECK CONSTRAINT [FK_T_FTICR_Analysis_Description_T_FAD_State_Name]
GO
ALTER TABLE [dbo].[T_FTICR_Analysis_Description] ADD  CONSTRAINT [DF_T_FTICR_Analysis_Description_Protein_Collection_List]  DEFAULT ('na') FOR [Protein_Collection_List]
GO
ALTER TABLE [dbo].[T_FTICR_Analysis_Description] ADD  CONSTRAINT [DF_T_FTICR_Analysis_Description_Protein_Options_List]  DEFAULT ('na') FOR [Protein_Options_List]
GO
ALTER TABLE [dbo].[T_FTICR_Analysis_Description] ADD  CONSTRAINT [DF_T_FTICR_Analysis_Description_MyEMSLState]  DEFAULT ((0)) FOR [MyEMSLState]
GO
ALTER TABLE [dbo].[T_FTICR_Analysis_Description] ADD  CONSTRAINT [DF_T_FTICR_Analysis_Description_Created]  DEFAULT (getdate()) FOR [Created]
GO
ALTER TABLE [dbo].[T_FTICR_Analysis_Description] ADD  CONSTRAINT [DF_T_FTICR_Analysis_Description_Auto_Addition]  DEFAULT ((0)) FOR [Auto_Addition]
GO
ALTER TABLE [dbo].[T_FTICR_Analysis_Description] ADD  CONSTRAINT [DF_T_FTICR_Analysis_Description_State]  DEFAULT ((1)) FOR [State]
GO
