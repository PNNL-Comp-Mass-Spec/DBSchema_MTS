if exists (select * from dbo.sysobjects where id = object_id(N'[T_Match_Methods]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Match_Methods]
GO

CREATE TABLE [T_Match_Methods] (
	[Name] [varchar] (32) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Internal_Code] [varchar] (32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	CONSTRAINT [PK_T_Match_Mathods] PRIMARY KEY  CLUSTERED 
	(
		[Name]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] 
) ON [PRIMARY]
GO


