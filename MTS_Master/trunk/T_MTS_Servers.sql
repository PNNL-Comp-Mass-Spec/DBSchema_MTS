if exists (select * from dbo.sysobjects where id = object_id(N'[T_MTS_Servers]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_MTS_Servers]
GO

CREATE TABLE [T_MTS_Servers] (
	[Server_ID] [int] NOT NULL ,
	[Server_Name] [varchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Active] [tinyint] NOT NULL ,
	CONSTRAINT [PK_T_MTS_Servers] PRIMARY KEY  CLUSTERED 
	(
		[Server_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] 
) ON [PRIMARY]
GO

 CREATE  UNIQUE  INDEX [IX_T_MTS_Servers] ON [T_MTS_Servers]([Server_Name]) WITH  FILLFACTOR = 90 ON [PRIMARY]
GO


