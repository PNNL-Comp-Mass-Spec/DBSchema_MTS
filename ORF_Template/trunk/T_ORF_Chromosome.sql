if exists (select * from dbo.sysobjects where id = object_id(N'[T_ORF_Chromosome]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_ORF_Chromosome]
GO

CREATE TABLE [T_ORF_Chromosome] (
	[Chromosome_ID] [int] IDENTITY (1, 1) NOT NULL ,
	[Chromosome_Name] [varchar] (32) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Chromosome_Full_Name] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Chromosome_Type] [varchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Nucleotide_File_Path] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Nucleotide_File_Name] [varchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Date_Modified] [datetime] NULL ,
	CONSTRAINT [PK_T_ORF_Chromosome] PRIMARY KEY  NONCLUSTERED 
	(
		[Chromosome_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [IX_T_ORF_Chromosome] UNIQUE  NONCLUSTERED 
	(
		[Chromosome_Name]
	)  ON [PRIMARY] 
) ON [PRIMARY]
GO


