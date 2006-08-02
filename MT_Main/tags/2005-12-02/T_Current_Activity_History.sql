if exists (select * from dbo.sysobjects where id = object_id(N'[T_Current_Activity_History]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Current_Activity_History]
GO

CREATE TABLE [T_Current_Activity_History] (
	[History_ID] [int] IDENTITY (1, 1) NOT NULL ,
	[Database_ID] [int] NOT NULL ,
	[Database_Name] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Snapshot_Date] [datetime] NOT NULL ,
	[TableCount1] [int] NULL ,
	[TableCount2] [int] NULL ,
	[TableCount3] [int] NULL ,
	[TableCount4] [int] NULL ,
	[Update_Completion_Date] [datetime] NULL ,
	CONSTRAINT [PK_T_Current_Activity_History] PRIMARY KEY  NONCLUSTERED 
	(
		[History_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] 
) ON [PRIMARY]
GO

 CREATE  CLUSTERED  INDEX [IX_T_Current_Activity_History] ON [T_Current_Activity_History]([Database_ID]) WITH  FILLFACTOR = 90 ON [PRIMARY]
GO


