if exists (select * from dbo.sysobjects where id = object_id(N'[T_Current_Activity]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Current_Activity]
GO

CREATE TABLE [T_Current_Activity] (
	[Database_ID] [int] NOT NULL ,
	[Database_Name] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Type] [char] (4) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Update_Began] [datetime] NULL ,
	[Update_Completed] [datetime] NULL ,
	[State] [int] NULL ,
	[Comment] [varchar] (512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Update_State] [int] NOT NULL CONSTRAINT [DF_T_Current_Activity_Update_State] DEFAULT (0),
	[ET_Minutes_Last24Hours] [decimal](9, 2) NULL ,
	[ET_Minutes_Last7Days] [decimal](9, 2) NULL ,
	CONSTRAINT [PK_T_Current_Activity] PRIMARY KEY  NONCLUSTERED 
	(
		[Database_ID],
		[Type]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_Current_Activity_T_Update_State_Name] FOREIGN KEY 
	(
		[Update_State]
	) REFERENCES [T_Update_State_Name] (
		[ID]
	)
) ON [PRIMARY]
GO

 CREATE  CLUSTERED  INDEX [IX_T_Current_Activity] ON [T_Current_Activity]([Database_Name]) WITH  FILLFACTOR = 90 ON [PRIMARY]
GO


