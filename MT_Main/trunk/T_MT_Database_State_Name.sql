if exists (select * from dbo.sysobjects where id = object_id(N'[T_MT_Database_State_Name]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_MT_Database_State_Name]
GO

CREATE TABLE [T_MT_Database_State_Name] (
	[ID] [int] NOT NULL ,
	[Name] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	CONSTRAINT [PK_T_MT_Database_State_Name] PRIMARY KEY  NONCLUSTERED 
	(
		[ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] 
) ON [PRIMARY]
GO


