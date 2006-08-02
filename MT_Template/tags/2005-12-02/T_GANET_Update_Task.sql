if exists (select * from dbo.sysobjects where id = object_id(N'[T_GANET_Update_Task]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_GANET_Update_Task]
GO

CREATE TABLE [T_GANET_Update_Task] (
	[Task_ID] [int] IDENTITY (1, 1) NOT NULL ,
	[Processing_State] [tinyint] NOT NULL ,
	[Task_Created] [datetime] NULL ,
	[Task_Start] [datetime] NULL ,
	[Task_Finish] [datetime] NULL ,
	[Task_AssignedProcessorName] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	CONSTRAINT [PK_T_GANET_Update_Task] PRIMARY KEY  CLUSTERED 
	(
		[Task_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_GANET_Update_Task_T_GANET_Update_Task_State_Name] FOREIGN KEY 
	(
		[Processing_State]
	) REFERENCES [T_GANET_Update_Task_State_Name] (
		[Processing_State]
	)
) ON [PRIMARY]
GO


