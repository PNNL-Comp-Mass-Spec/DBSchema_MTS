if exists (select * from dbo.sysobjects where id = object_id(N'[T_Folder_Paths]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Folder_Paths]
GO

CREATE TABLE [T_Folder_Paths] (
	[Function] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Client_Path] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Server_Path] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	CONSTRAINT [PK_T_Folder_Paths] PRIMARY KEY  CLUSTERED 
	(
		[Function]
	)  ON [PRIMARY] 
) ON [PRIMARY]
GO


