if exists (select * from dbo.sysobjects where id = object_id(N'[T_Log_Entries]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Log_Entries]
GO

CREATE TABLE [T_Log_Entries] (
	[Entry_ID] [int] IDENTITY (1, 1) NOT NULL ,
	[posted_by] [varchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[posting_time] [datetime] NOT NULL ,
	[type] [varchar] (32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[message] [varchar] (244) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	CONSTRAINT [PK_T_Log_Entries] PRIMARY KEY  CLUSTERED 
	(
		[Entry_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] 
) ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_Log_Entries_Type] ON [T_Log_Entries]([type]) ON [PRIMARY]
GO


