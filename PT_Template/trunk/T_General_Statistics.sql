if exists (select * from dbo.sysobjects where id = object_id(N'[T_General_Statistics]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_General_Statistics]
GO

CREATE TABLE [T_General_Statistics] (
	[category] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[label] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[value] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[sequence] [int] IDENTITY (1000, 1) NOT NULL 
) ON [PRIMARY]
GO


