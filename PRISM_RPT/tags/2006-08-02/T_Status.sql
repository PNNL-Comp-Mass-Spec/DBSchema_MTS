if exists (select * from dbo.sysobjects where id = object_id(N'[T_Status]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Status]
GO

CREATE TABLE [T_Status] (
	[statuskey] [int] NOT NULL ,
	[name] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[description] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	CONSTRAINT [PK_T_Status] PRIMARY KEY  CLUSTERED 
	(
		[statuskey]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] 
) ON [PRIMARY]
GO


