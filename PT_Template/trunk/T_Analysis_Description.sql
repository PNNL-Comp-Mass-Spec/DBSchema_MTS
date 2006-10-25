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
	[Organism] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Instrument_Class] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Instrument] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Analysis_Tool] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Parameter_File_Name] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Settings_File_Name] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Organism_DB_Name] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Protein_Collection_List] [varchar](2048) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_Analysis_Description_Protein_Collection_List]  DEFAULT ('na'),
	[Protein_Options_List] [varchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_Analysis_Description_Protein_Options_List]  DEFAULT ('na'),
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
	[Created] [datetime] NOT NULL CONSTRAINT [DF_T_Analysis_Description_Created]  DEFAULT (getdate()),
	[Last_Affected] [datetime] NULL,
	[Process_State] [int] NOT NULL CONSTRAINT [DF_T_Analysis_Description_Process_State]  DEFAULT (0),
	[Import_Priority] [int] NOT NULL CONSTRAINT [DF_T_Analysis_Description_Import_Priority]  DEFAULT (5),
	[GANET_Fit] [float] NULL,
	[GANET_Slope] [float] NULL,
	[GANET_Intercept] [float] NULL,
	[GANET_RSquared] [real] NULL,
	[ScanTime_NET_Slope] [real] NULL,
	[ScanTime_NET_Intercept] [real] NULL,
	[ScanTime_NET_RSquared] [real] NULL,
	[ScanTime_NET_Fit] [real] NULL,
	[RowCount_Loaded] [int] NULL,
 CONSTRAINT [PK_T_Analysis_Description] PRIMARY KEY CLUSTERED 
(
	[Job] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Analysis_Description_Instrument] ******/
CREATE NONCLUSTERED INDEX [IX_T_Analysis_Description_Instrument] ON [dbo].[T_Analysis_Description] 
(
	[Instrument] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
GO

/****** Object:  Index [IX_T_Analysis_Description_Process_State] ******/
CREATE NONCLUSTERED INDEX [IX_T_Analysis_Description_Process_State] ON [dbo].[T_Analysis_Description] 
(
	[Process_State] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
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

GO
ALTER TABLE [dbo].[T_Analysis_Description]  WITH NOCHECK ADD  CONSTRAINT [FK_T_Analysis_Description_T_Datasets] FOREIGN KEY([Dataset_ID])
REFERENCES [T_Datasets] ([Dataset_ID])
GO
ALTER TABLE [dbo].[T_Analysis_Description] CHECK CONSTRAINT [FK_T_Analysis_Description_T_Datasets]
GO
ALTER TABLE [dbo].[T_Analysis_Description]  WITH NOCHECK ADD  CONSTRAINT [FK_T_Analysis_Description_T_Process_State] FOREIGN KEY([Process_State])
REFERENCES [T_Process_State] ([ID])
GO
ALTER TABLE [dbo].[T_Analysis_Description] CHECK CONSTRAINT [FK_T_Analysis_Description_T_Process_State]
GO
