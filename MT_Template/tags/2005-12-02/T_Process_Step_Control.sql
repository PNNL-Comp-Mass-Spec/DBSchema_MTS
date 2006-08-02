if exists (select * from dbo.sysobjects where id = object_id(N'[T_Process_Step_Control]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Process_Step_Control]
GO

CREATE TABLE [T_Process_Step_Control] (
	[Processing_Step_Name] [varchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[enabled] [int] NOT NULL CONSTRAINT [DF_T_Process_Step_Control_enabled] DEFAULT (0),
	CONSTRAINT [PK_T_Process_Step_Control] PRIMARY KEY  CLUSTERED 
	(
		[Processing_Step_Name]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] 
) ON [PRIMARY]
GO


