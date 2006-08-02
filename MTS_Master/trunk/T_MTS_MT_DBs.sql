if exists (select * from dbo.sysobjects where id = object_id(N'[T_MTS_MT_DBs]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_MTS_MT_DBs]
GO

CREATE TABLE [T_MTS_MT_DBs] (
	[MT_DB_ID] [int] NOT NULL ,
	[MT_DB_Name] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Server_ID] [int] NOT NULL ,
	[State_ID] [int] NOT NULL ,
	[Last_Affected] [datetime] NOT NULL CONSTRAINT [DF_T_MTS_MT_DBs_Last_Affected] DEFAULT (getdate()),
	[DB_Schema_Version] [real] NOT NULL CONSTRAINT [DF_T_MTS_MT_DBs_DB_Schema_Version] DEFAULT (2),
	[Comment] [varchar] (256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_MTS_MT_DBs_Comment] DEFAULT (''),
	CONSTRAINT [PK_T_MTS_MT_DBs] PRIMARY KEY  CLUSTERED 
	(
		[MT_DB_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_MTS_MT_DBs_T_MTS_Servers] FOREIGN KEY 
	(
		[Server_ID]
	) REFERENCES [T_MTS_Servers] (
		[Server_ID]
	)
) ON [PRIMARY]
GO

 CREATE  UNIQUE  INDEX [IX_T_MTS_MT_DBs] ON [T_MTS_MT_DBs]([MT_DB_Name]) WITH  FILLFACTOR = 90 ON [PRIMARY]
GO


