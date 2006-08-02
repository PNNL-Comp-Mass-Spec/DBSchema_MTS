if exists (select * from dbo.sysobjects where id = object_id(N'[T_Process_Config]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Process_Config]
GO

CREATE TABLE [T_Process_Config] (
	[Process_Config_ID] [int] IDENTITY (100, 1) NOT NULL ,
	[Name] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Value] [varchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	CONSTRAINT [PK_T_Process_Config] PRIMARY KEY  NONCLUSTERED 
	(
		[Process_Config_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [IX_T_Process_Config_UniqueNameValue] UNIQUE  NONCLUSTERED 
	(
		[Name],
		[Value]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_Process_Config_T_Process_Config_Parameters] FOREIGN KEY 
	(
		[Name]
	) REFERENCES [T_Process_Config_Parameters] (
		[Name]
	)
) ON [PRIMARY]
GO

 CREATE  CLUSTERED  INDEX [IX_T_Process_Config] ON [T_Process_Config]([Name]) WITH  FILLFACTOR = 90 ON [PRIMARY]
GO


