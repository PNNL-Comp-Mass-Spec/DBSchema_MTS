if exists (select * from dbo.sysobjects where id = object_id(N'[T_Peptide_Prophet_Task_Job_Map]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Peptide_Prophet_Task_Job_Map]
GO

CREATE TABLE [T_Peptide_Prophet_Task_Job_Map] (
	[Task_ID] [int] NOT NULL ,
	[Job] [int] NOT NULL ,
	CONSTRAINT [PK_T_Peptide_Prophet_Task_Job_Map] PRIMARY KEY  CLUSTERED 
	(
		[Task_ID],
		[Job]
	)  ON [PRIMARY] ,
	CONSTRAINT [FK_T_Peptide_Prophet_Task_Job_Map_T_Analysis_Description] FOREIGN KEY 
	(
		[Job]
	) REFERENCES [T_Analysis_Description] (
		[Job]
	),
	CONSTRAINT [FK_T_Peptide_Prophet_Task_Job_Map_T_Peptide_Prophet_Task] FOREIGN KEY 
	(
		[Task_ID]
	) REFERENCES [T_Peptide_Prophet_Task] (
		[Task_ID]
	)
) ON [PRIMARY]
GO


