if exists (select * from dbo.sysobjects where id = object_id(N'[T_Filter_List]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Filter_List]
GO

CREATE TABLE [T_Filter_List] (
	[Filter_ID] [int] NOT NULL ,
	[Name] [varchar] (32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Description] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[P1] [varchar] (32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[P2] [varchar] (32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Filter_Method] [varchar] (12) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	CONSTRAINT [PK_T_Filter_List] PRIMARY KEY  CLUSTERED 
	(
		[Filter_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] 
) ON [PRIMARY]
GO


