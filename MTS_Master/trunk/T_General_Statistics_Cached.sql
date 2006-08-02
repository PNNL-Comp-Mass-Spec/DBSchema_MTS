if exists (select * from dbo.sysobjects where id = object_id(N'[T_General_Statistics_Cached]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_General_Statistics_Cached]
GO

CREATE TABLE [T_General_Statistics_Cached] (
	[Server_Name] [varchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[DBName] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Category] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Label] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Value] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Entry_ID] [int] NOT NULL ,
	CONSTRAINT [PK_T_General_Statistics_MT_DBs] PRIMARY KEY  CLUSTERED 
	(
		[Server_Name],
		[DBName],
		[Entry_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] 
) ON [PRIMARY]
GO


