if exists (select * from dbo.sysobjects where id = object_id(N'[T_FTICR_Analysis_Description]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_FTICR_Analysis_Description]
GO

CREATE TABLE [T_FTICR_Analysis_Description] (
	[Job] [int] NOT NULL ,
	[Dataset] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Dataset_ID] [int] NOT NULL ,
	[Dataset_Created_DMS] [datetime] NULL ,
	[Dataset_Acq_Time_Start] [datetime] NULL ,
	[Dataset_Acq_Time_End] [datetime] NULL ,
	[Dataset_Scan_Count] [int] NULL ,
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
	[Labelling] [varchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Created] [datetime] NOT NULL CONSTRAINT [DF_T_FTICR_Analysis_Description_Created] DEFAULT (getdate()),
	[Auto_Addition] [tinyint] NOT NULL CONSTRAINT [DF_T_FTICR_Analysis_Description_Auto_Addition] DEFAULT (0),
	[State] [int] NOT NULL CONSTRAINT [DF_T_FTICR_Analysis_Description_State] DEFAULT (1),
	[GANET_Fit] [float] NULL ,
	[GANET_Slope] [float] NULL ,
	[GANET_Intercept] [float] NULL ,
	[Total_Scans] [int] NULL ,
	[Scan_Start] [int] NULL ,
	[Scan_End] [int] NULL ,
	[Duration] [real] NULL ,
	CONSTRAINT [PK_T_FTICR_Analysis_Description] PRIMARY KEY  CLUSTERED 
	(
		[Job]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_FTICR_Analysis_Description_T_FAD_State_Name] FOREIGN KEY 
	(
		[State]
	) REFERENCES [T_FAD_State_Name] (
		[FAD_State_ID]
	)
) ON [PRIMARY]
GO


