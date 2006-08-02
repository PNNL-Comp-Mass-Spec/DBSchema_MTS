if exists (select * from dbo.sysobjects where id = object_id(N'[T_SP_Categories]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_SP_Categories]
GO

CREATE TABLE [T_SP_Categories] (
	[Category_ID] [int] NOT NULL ,
	[Category_Name] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	CONSTRAINT [PK_T_SP_Categories] PRIMARY KEY  CLUSTERED 
	(
		[Category_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] 
) ON [PRIMARY]
GO


