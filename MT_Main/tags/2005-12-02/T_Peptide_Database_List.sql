if exists (select * from dbo.sysobjects where id = object_id(N'[T_Peptide_Database_List]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Peptide_Database_List]
GO

CREATE TABLE [T_Peptide_Database_List] (
	[PDB_ID] [int] NOT NULL ,
	[PDB_Name] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[PDB_Description] [varchar] (2048) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[PDB_Organism] [varchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[PDB_Connection_String] [varchar] (1024) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[PDB_NetSQL_Conn_String] [varchar] (512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[PDB_NetOleDB_Conn_String] [varchar] (512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[PDB_State] [int] NULL ,
	[PDB_Last_Update] [datetime] NULL ,
	[PDB_Last_Import] [datetime] NULL ,
	[PDB_Import_Holdoff] [int] NULL CONSTRAINT [DF_T_Peptide_Database_List_PDB_Import_Holdoff] DEFAULT (24),
	[PDB_Created] [datetime] NOT NULL CONSTRAINT [DF_T_Peptide_Database_List_PDB_Created] DEFAULT (getdate()),
	[PDB_Demand_Import] [tinyint] NULL CONSTRAINT [DF_T_Peptide_Database_List_PDB_Demand_Import] DEFAULT (0),
	[PDB_Max_Jobs_To_Process] [int] NULL CONSTRAINT [DF_T_Peptide_Database_List_PDB_Max_Jobs_To_Process] DEFAULT (50),
	[PDB_DB_Schema_Version] [real] NOT NULL CONSTRAINT [DF_T_Peptide_Database_List_PDB_DB_Schema_Version] DEFAULT (2),
	CONSTRAINT [PK_T_Peptide_Database_List] PRIMARY KEY  CLUSTERED 
	(
		[PDB_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_Peptide_Database_List_T_MT_Database_State_Name] FOREIGN KEY 
	(
		[PDB_State]
	) REFERENCES [T_MT_Database_State_Name] (
		[ID]
	)
) ON [PRIMARY]
GO

 CREATE  UNIQUE  INDEX [IX_T_Peptide_Database_List] ON [T_Peptide_Database_List]([PDB_Name]) WITH  FILLFACTOR = 90 ON [PRIMARY]
GO


