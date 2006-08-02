if exists (select * from dbo.sysobjects where id = object_id(N'[T_Process_Step_Control_States]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Process_Step_Control_States]
GO

CREATE TABLE [T_Process_Step_Control_States] (
	[Execution_State] [int] NOT NULL ,
	[Execution_State_Name] [varchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	CONSTRAINT [PK_T_Process_Step_Control_States] PRIMARY KEY  CLUSTERED 
	(
		[Execution_State]
	)  ON [PRIMARY] 
) ON [PRIMARY]
GO


