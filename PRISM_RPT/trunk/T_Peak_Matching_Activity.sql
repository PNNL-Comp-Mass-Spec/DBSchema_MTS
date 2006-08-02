if exists (select * from dbo.sysobjects where id = object_id(N'[T_Peak_Matching_Activity]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Peak_Matching_Activity]
GO

CREATE TABLE [T_Peak_Matching_Activity] (
	[PM_AssignedProcessorName] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Working] [tinyint] NOT NULL CONSTRAINT [DF_T_Peak_Matching_Activity_Working] DEFAULT (0),
	[Server_Name] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[MTDBName] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[TaskID] [int] NULL ,
	[Job] [int] NULL ,
	[Output_Folder_Path] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[PM_Start] [datetime] NULL ,
	[PM_Finish] [datetime] NULL ,
	[TasksCompleted] [int] NOT NULL CONSTRAINT [DF_T_Peak_Matching_Activity_TasksCompleted] DEFAULT (0),
	[PM_History_ID] [int] NULL ,
	CONSTRAINT [PK_T_Peak_Matching_Activity] PRIMARY KEY  CLUSTERED 
	(
		[PM_AssignedProcessorName]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] 
) ON [PRIMARY]
GO


