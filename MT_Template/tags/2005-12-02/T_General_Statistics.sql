if exists (select * from dbo.sysobjects where id = object_id(N'[T_General_Statistics]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_General_Statistics]
GO

CREATE TABLE [T_General_Statistics] (
	[Category] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Label] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Value] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Previous_Value] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Entry_ID] [int] IDENTITY (1000, 1) NOT NULL ,
	CONSTRAINT [PK_T_General_Statistics] PRIMARY KEY  CLUSTERED 
	(
		[Entry_ID]
	)  ON [PRIMARY] 
) ON [PRIMARY]
GO


