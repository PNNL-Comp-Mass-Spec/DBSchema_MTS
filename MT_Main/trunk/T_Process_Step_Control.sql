if exists (select * from dbo.sysobjects where id = object_id(N'[T_Process_Step_Control]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Process_Step_Control]
GO

CREATE TABLE [T_Process_Step_Control] (
	[Processing_Step_Name] [varchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Execution_State] [int] NOT NULL CONSTRAINT [DF_T_Process_Step_Control_Execution_State] DEFAULT (0),
	[Last_Query_Date] [datetime] NULL ,
	[Last_Query_Description] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Last_Query_Update_Count] [int] NOT NULL ,
	[Pause_Location] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	CONSTRAINT [PK_T_Process_Step_Control] PRIMARY KEY  CLUSTERED 
	(
		[Processing_Step_Name]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_Process_Step_Control_T_Process_Step_Control_States] FOREIGN KEY 
	(
		[Execution_State]
	) REFERENCES [T_Process_Step_Control_States] (
		[Execution_State]
	)
) ON [PRIMARY]
GO


