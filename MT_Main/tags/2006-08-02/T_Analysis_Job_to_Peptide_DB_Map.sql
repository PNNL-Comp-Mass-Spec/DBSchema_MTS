if exists (select * from dbo.sysobjects where id = object_id(N'[T_Analysis_Job_to_Peptide_DB_Map]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Analysis_Job_to_Peptide_DB_Map]
GO

CREATE TABLE [T_Analysis_Job_to_Peptide_DB_Map] (
	[Job] [int] NOT NULL ,
	[PDB_ID] [int] NOT NULL ,
	[ResultType] [varchar] (32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Created] [datetime] NOT NULL ,
	[Last_Affected] [datetime] NOT NULL CONSTRAINT [DF_T_Analysis_Job_to_Peptide_DB_Map_Last_Affected] DEFAULT (getdate()),
	CONSTRAINT [PK_T_Analysis_Job_to_Peptide_DB_Map] PRIMARY KEY  CLUSTERED 
	(
		[Job],
		[PDB_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_Analysis_Job_to_Peptide_DB_Map_T_Peptide_Database_List] FOREIGN KEY 
	(
		[PDB_ID]
	) REFERENCES [T_Peptide_Database_List] (
		[PDB_ID]
	)
) ON [PRIMARY]
GO

 CREATE  UNIQUE  INDEX [IX_T_Analysis_Job_to_Peptide_DB_Map] ON [T_Analysis_Job_to_Peptide_DB_Map]([PDB_ID], [Job]) WITH  FILLFACTOR = 90 ON [PRIMARY]
GO


