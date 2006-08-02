if exists (select * from dbo.sysobjects where id = object_id(N'[T_MTS_Protein_DBs]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_MTS_Protein_DBs]
GO

CREATE TABLE [T_MTS_Protein_DBs] (
	[Protein_DB_ID] [int] NOT NULL ,
	[Protein_DB_Name] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Server_ID] [int] NOT NULL ,
	[State_ID] [int] NOT NULL ,
	[Last_Affected] [datetime] NOT NULL CONSTRAINT [DF_T_MTS_Protein_DBs_Last_Affected] DEFAULT (getdate()),
	[DB_Schema_Version] [real] NOT NULL CONSTRAINT [DF_T_MTS_Protein_DBs_DB_Schema_Version] DEFAULT (1),
	CONSTRAINT [PK_T_MTS_Protein_DBs] PRIMARY KEY  CLUSTERED 
	(
		[Protein_DB_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_MTS_Protein_DBs_T_MTS_Servers] FOREIGN KEY 
	(
		[Server_ID]
	) REFERENCES [T_MTS_Servers] (
		[Server_ID]
	)
) ON [PRIMARY]
GO

 CREATE  UNIQUE  INDEX [IX_T_MTS_Protein_DBs] ON [T_MTS_Protein_DBs]([Protein_DB_Name]) WITH  FILLFACTOR = 90 ON [PRIMARY]
GO


