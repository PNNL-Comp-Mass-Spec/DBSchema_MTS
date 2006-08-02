if exists (select * from dbo.sysobjects where id = object_id(N'[T_Peptide_Prophet_Task]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Peptide_Prophet_Task]
GO

CREATE TABLE [T_Peptide_Prophet_Task] (
	[Task_ID] [int] IDENTITY (1, 1) NOT NULL ,
	[Processing_State] [tinyint] NOT NULL ,
	[Task_Created] [datetime] NULL ,
	[Task_Start] [datetime] NULL ,
	[Task_Finish] [datetime] NULL ,
	[Task_AssignedProcessorName] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Transfer_Folder_Path] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[JobList_File_Name] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Results_File_Name] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	CONSTRAINT [PK_T_Peptide_Prophet_Task] PRIMARY KEY  CLUSTERED 
	(
		[Task_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_Peptide_Prophet_Task_T_Peptide_Prophet_Task_State_Name] FOREIGN KEY 
	(
		[Processing_State]
	) REFERENCES [T_Peptide_Prophet_Task_State_Name] (
		[Processing_State]
	)
) ON [PRIMARY]
GO


