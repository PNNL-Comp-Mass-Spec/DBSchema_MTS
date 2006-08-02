if exists (select * from dbo.sysobjects where id = object_id(N'[T_UMC_Database_List]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_UMC_Database_List]
GO

CREATE TABLE [T_UMC_Database_List] (
	[UDB_ID] [int] NOT NULL ,
	[UDB_Name] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[UDB_Description] [varchar] (2048) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[UDB_Organism] [varchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[UDB_Connection_String] [varchar] (1024) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[UDB_NetSQL_Conn_String] [varchar] (512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[UDB_NetOleDB_Conn_String] [varchar] (512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[UDB_State] [int] NULL ,
	[UDB_Update_Schedule] [varchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[UDB_Last_Update] [datetime] NULL ,
	[UDB_Last_Import] [datetime] NULL ,
	[UDB_Import_Holdoff] [int] NULL ,
	[UDB_Created] [datetime] NOT NULL CONSTRAINT [DF_T_UMC_Database_List_UDB_Created] DEFAULT (getdate()),
	[UDB_Demand_Import] [tinyint] NULL ,
	[UDB_Max_Jobs_To_Process] [int] NULL CONSTRAINT [DF_T_UMC_Database_List_UDB_Max_Jobs_To_Process] DEFAULT (500),
	[UDB_DB_Schema_Version] [real] NOT NULL CONSTRAINT [DF_T_UMC_Database_List_UDB_DB_Schema_Version] DEFAULT (2),
	CONSTRAINT [PK_T_UMC_Database_List] PRIMARY KEY  CLUSTERED 
	(
		[UDB_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_UMC_Database_List_T_MT_Database_State_Name] FOREIGN KEY 
	(
		[UDB_State]
	) REFERENCES [T_MT_Database_State_Name] (
		[ID]
	)
) ON [PRIMARY]
GO

 CREATE  UNIQUE  INDEX [IX_T_UMC_Database_List] ON [T_UMC_Database_List]([UDB_Name]) WITH  FILLFACTOR = 90 ON [PRIMARY]
GO


