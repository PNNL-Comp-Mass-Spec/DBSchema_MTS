if exists (select * from dbo.sysobjects where id = object_id(N'[T_Usage_Log]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Usage_Log]
GO

CREATE TABLE [T_Usage_Log] (
	[Entry_ID] [int] IDENTITY (1, 1) NOT NULL ,
	[Posted_By] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Posting_time] [datetime] NOT NULL CONSTRAINT [DF_T_Usage_Log_Posting_time] DEFAULT (getdate()),
	[Target_DB_Name] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Message] [varchar] (4096) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Calling_User] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Usage_Count] [int] NULL ,
	CONSTRAINT [PK_T_Usage_Log] PRIMARY KEY  CLUSTERED 
	(
		[Entry_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] 
) ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_Usage_Log_Posted_By] ON [T_Usage_Log]([Posted_By]) WITH  FILLFACTOR = 90 ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_Usage_Log_Target_DB_Name] ON [T_Usage_Log]([Target_DB_Name]) WITH  FILLFACTOR = 90 ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_Usage_Log_Calling_User] ON [T_Usage_Log]([Calling_User]) ON [PRIMARY]
GO


