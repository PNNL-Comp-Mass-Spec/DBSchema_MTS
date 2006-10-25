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
	[Dataset_Scan_Count] [int] NULL,
	[Experiment] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Campaign] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Organism] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Instrument_Class] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Instrument] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Analysis_Tool] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Parameter_File_Name] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Settings_File_Name] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Organism_DB_Name] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Protein_Collection_List] [varchar](2048) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_FTICR_Analysis_Description_Protein_Collection_List]  DEFAULT ('na'),
	[Protein_Options_List] [varchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_FTICR_Analysis_Description_Protein_Options_List]  DEFAULT ('na'),
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
	[Labelling] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Created] [datetime] NOT NULL CONSTRAINT [DF_T_FTICR_Analysis_Description_Created]  DEFAULT (getdate()),
	[Auto_Addition] [tinyint] NOT NULL CONSTRAINT [DF_T_FTICR_Analysis_Description_Auto_Addition]  DEFAULT (0),
	[State] [int] NOT NULL CONSTRAINT [DF_T_FTICR_Analysis_Description_State]  DEFAULT (1),
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
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Trigger [dbo].[trig_i_FTICRAnalysisDescription] ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE Trigger trig_i_FTICRAnalysisDescription on dbo.T_FTICR_Analysis_Description
For Insert
AS
	If @@RowCount = 0
		Return

	INSERT INTO T_Event_Log	(Target_Type, Target_ID, Target_State, Prev_Target_State, Entered)
	SELECT 2, inserted.Job, inserted.State, 0, GetDate()
	FROM inserted


GO

/****** Object:  Trigger [dbo].[trig_u_FTICRAnalysisDescription] ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE Trigger trig_u_FTICRAnalysisDescription on dbo.T_FTICR_Analysis_Description
For Update
AS
	If @@RowCount = 0
		Return

	if update(State)
		INSERT INTO T_Event_Log	(Target_Type, Target_ID, Target_State, Prev_Target_State, Entered)
		SELECT 2, inserted.Job, inserted.State, deleted.State, GetDate()
		FROM deleted INNER JOIN inserted ON deleted.Job = inserted.Job


GO
ALTER TABLE [dbo].[T_FTICR_Analysis_Description]  WITH NOCHECK ADD  CONSTRAINT [FK_T_FTICR_Analysis_Description_T_FAD_State_Name] FOREIGN KEY([State])
REFERENCES [T_FAD_State_Name] ([FAD_State_ID])
GO
ALTER TABLE [dbo].[T_FTICR_Analysis_Description] CHECK CONSTRAINT [FK_T_FTICR_Analysis_Description_T_FAD_State_Name]
GO
