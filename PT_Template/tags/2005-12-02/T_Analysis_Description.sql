if exists (select * from dbo.sysobjects where id = object_id(N'[T_Analysis_Description]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Analysis_Description]
GO

CREATE TABLE [T_Analysis_Description] (
	[Job] [int] NOT NULL ,
	[Dataset] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Dataset_ID] [int] NOT NULL ,
	[Experiment] [varchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Campaign] [varchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Organism] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Instrument_Class] [varchar] (32) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Instrument] [varchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Analysis_Tool] [varchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Parameter_File_Name] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Settings_File_Name] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Organism_DB_Name] [varchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Vol_Client] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Vol_Server] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Storage_Path] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Dataset_Folder] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Results_Folder] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Completed] [datetime] NULL ,
	[ResultType] [varchar] (32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Separation_Sys_Type] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Internal_Standard] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Enzyme_ID] [int] NULL ,
	[Labelling] [varchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Created] [datetime] NOT NULL CONSTRAINT [DF_T_Analysis_Description_Created] DEFAULT (getdate()),
	[Last_Affected] [datetime] NULL ,
	[Process_State] [int] NOT NULL CONSTRAINT [DF_T_Analysis_Description_Process_State] DEFAULT (0),
	[GANET_Fit] [float] NULL ,
	[GANET_Slope] [float] NULL ,
	[GANET_Intercept] [float] NULL ,
	[GANET_RSquared] [real] NULL ,
	[ScanTime_NET_Slope] [real] NULL ,
	[ScanTime_NET_Intercept] [real] NULL ,
	[ScanTime_NET_RSquared] [real] NULL ,
	[ScanTime_NET_Fit] [real] NULL ,
	CONSTRAINT [PK_T_Analysis_Description] PRIMARY KEY  CLUSTERED 
	(
		[Job]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_Analysis_Description_T_Datasets] FOREIGN KEY 
	(
		[Dataset_ID]
	) REFERENCES [T_Datasets] (
		[Dataset_ID]
	),
	CONSTRAINT [FK_T_Analysis_Description_T_Process_State] FOREIGN KEY 
	(
		[Process_State]
	) REFERENCES [T_Process_State] (
		[ID]
	)
) ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_Analysis_Description_Process_State] ON [T_Analysis_Description]([Process_State]) ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_Analysis_Description_Instrument] ON [T_Analysis_Description]([Instrument]) ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
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
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
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
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


