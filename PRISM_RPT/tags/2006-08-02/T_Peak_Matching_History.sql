if exists (select * from dbo.sysobjects where id = object_id(N'[T_Peak_Matching_History]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Peak_Matching_History]
GO

CREATE TABLE [T_Peak_Matching_History] (
	[PM_History_ID] [int] IDENTITY (1, 1) NOT NULL ,
	[PM_AssignedProcessorName] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[PM_ToolVersion] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_Peak_Matching_History_PM_ToolVersion] DEFAULT ('Unknown'),
	[Server_Name] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[MTDBName] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[TaskID] [int] NOT NULL ,
	[Job] [int] NOT NULL ,
	[Output_Folder_Path] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[PM_Start] [datetime] NULL ,
	[PM_Finish] [datetime] NULL ,
	CONSTRAINT [PK_T_Peak_Matching_History] PRIMARY KEY  CLUSTERED 
	(
		[PM_History_ID]
	)  ON [PRIMARY] 
) ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_Peak_Matching_History_ProcessorName] ON [T_Peak_Matching_History]([PM_AssignedProcessorName]) ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_Peak_Matching_History_MTDBName] ON [T_Peak_Matching_History]([MTDBName]) ON [PRIMARY]
GO


