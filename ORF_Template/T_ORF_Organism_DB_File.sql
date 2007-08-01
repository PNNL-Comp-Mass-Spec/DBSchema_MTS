if exists (select * from dbo.sysobjects where id = object_id(N'[T_ORF_Organism_DB_File]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_ORF_Organism_DB_File]
GO

CREATE TABLE [T_ORF_Organism_DB_File] (
	[Organism_DB_File_Name] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Organism_DB_Path] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Organism] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL 
) ON [PRIMARY]
GO


