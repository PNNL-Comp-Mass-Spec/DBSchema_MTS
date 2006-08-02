if exists (select * from dbo.sysobjects where id = object_id(N'[T_Event_Log]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Event_Log]
GO

CREATE TABLE [T_Event_Log] (
	[Event_ID] [int] IDENTITY (100, 1) NOT NULL ,
	[Target_Type] [int] NULL ,
	[Target_ID] [int] NULL ,
	[Target_State] [smallint] NULL ,
	[Prev_Target_State] [smallint] NULL ,
	[Entered] [datetime] NULL ,
	CONSTRAINT [PK_T_Event_Log] PRIMARY KEY  CLUSTERED 
	(
		[Event_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_Event_Log_T_Event_Target1] FOREIGN KEY 
	(
		[Target_Type]
	) REFERENCES [T_Event_Target] (
		[ID]
	)
) ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_Event_Log] ON [T_Event_Log]([Target_ID]) WITH  FILLFACTOR = 90 ON [PRIMARY]
GO


