if exists (select * from dbo.sysobjects where id = object_id(N'[T_NET_Update_Task]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_NET_Update_Task]
GO

CREATE TABLE [T_NET_Update_Task] (
	[Task_ID] [int] IDENTITY (1, 1) NOT NULL ,
	[Processing_State] [tinyint] NOT NULL ,
	[Task_Created] [datetime] NULL CONSTRAINT [DF_T_NET_Update_Task_Task_Created] DEFAULT (getdate()),
	[Task_Start] [datetime] NULL ,
	[Task_Finish] [datetime] NULL ,
	[Task_AssignedProcessorName] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Output_Folder_Path] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Out_File_Name] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Results_Folder_Path] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Results_File_Name] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[PredictNETs_File_Name] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	CONSTRAINT [PK_T_NET_Update_Task] PRIMARY KEY  CLUSTERED 
	(
		[Task_ID]
	)  ON [PRIMARY] ,
	CONSTRAINT [FK_T_NET_Update_Task_T_NET_Update_Task_State_Name] FOREIGN KEY 
	(
		[Processing_State]
	) REFERENCES [T_NET_Update_Task_State_Name] (
		[Processing_State]
	)
) ON [PRIMARY]
GO


