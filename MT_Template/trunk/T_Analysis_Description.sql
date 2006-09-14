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
	[Dataset_Scan_Count] [int] NULL,
	[Experiment] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Campaign] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[PDB_ID] [int] NULL,
	[Dataset_SIC_Job] [int] NULL,
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
	[Created_Peptide_DB] [datetime] NOT NULL,
	[Created_PMT_Tag_DB] [datetime] NOT NULL CONSTRAINT [DF_T_Analysis_Description_Created_PMT_Tag_DB]  DEFAULT (getdate()),
	[State] [int] NOT NULL CONSTRAINT [DF_T_Analysis_Description_State]  DEFAULT (1),
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
)WITH FILLFACTOR = 90 ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Analysis_Description_Job_Dataset_ID] ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_T_Analysis_Description_Job_Dataset_ID] ON [dbo].[T_Analysis_Description] 
(
	[Job] ASC,
	[Dataset_ID] ASC
)WITH FILLFACTOR = 90 ON [PRIMARY]
GO

/****** Object:  Index [IX_T_Analysis_Description_Organism_DB_Name] ******/
CREATE NONCLUSTERED INDEX [IX_T_Analysis_Description_Organism_DB_Name] ON [dbo].[T_Analysis_Description] 
(
	[Job] ASC,
	[Organism_DB_Name] ASC
) ON [PRIMARY]
GO

/****** Object:  Trigger [dbo].[trig_i_AnalysisDescription] ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE Trigger trig_i_AnalysisDescription on dbo.T_Analysis_Description
For Insert
AS
	If @@RowCount = 0
		Return

	INSERT INTO T_Event_Log	(Target_Type, Target_ID, Target_State, Prev_Target_State, Entered)
	SELECT 1, inserted.Job, inserted.State, 0, GetDate()
	FROM inserted


GO

/****** Object:  Trigger [dbo].[trig_u_AnalysisDescription] ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE Trigger trig_u_AnalysisDescription on dbo.T_Analysis_Description
For Update
AS
	If @@RowCount = 0
		Return

	if update(State)
		INSERT INTO T_Event_Log	(Target_Type, Target_ID, Target_State, Prev_Target_State, Entered)
		SELECT 1, inserted.Job, inserted.State, deleted.State, GetDate()
		FROM deleted INNER JOIN inserted ON deleted.Job = inserted.Job


GO
ALTER TABLE [dbo].[T_Analysis_Description]  WITH NOCHECK ADD  CONSTRAINT [FK_T_Analysis_Description_T_Analysis_State_Name] FOREIGN KEY([State])
REFERENCES [T_Analysis_State_Name] ([AD_State_ID])
GO
ALTER TABLE [dbo].[T_Analysis_Description] CHECK CONSTRAINT [FK_T_Analysis_Description_T_Analysis_State_Name]
GO
