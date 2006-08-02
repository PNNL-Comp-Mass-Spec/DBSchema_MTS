if exists (select * from dbo.sysobjects where id = object_id(N'[T_Event_Target]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Event_Target]
GO

CREATE TABLE [T_Event_Target] (
	[ID] [int] NOT NULL ,
	[Name] [varchar] (32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	CONSTRAINT [PK_T_Event_Target] PRIMARY KEY  CLUSTERED 
	(
		[ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] 
) ON [PRIMARY]
GO


