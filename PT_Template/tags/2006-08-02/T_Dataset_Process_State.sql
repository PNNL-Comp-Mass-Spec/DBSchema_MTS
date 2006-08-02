if exists (select * from dbo.sysobjects where id = object_id(N'[T_Dataset_Process_State]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Dataset_Process_State]
GO

CREATE TABLE [T_Dataset_Process_State] (
	[ID] [int] NOT NULL ,
	[Name] [varchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	CONSTRAINT [PK_T_Dataset_Process_State] PRIMARY KEY  CLUSTERED 
	(
		[ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] 
) ON [PRIMARY]
GO


