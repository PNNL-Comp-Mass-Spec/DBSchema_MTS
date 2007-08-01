if exists (select * from dbo.sysobjects where id = object_id(N'[T_ORF]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_ORF]
GO

CREATE TABLE [T_ORF] (
	[Reference] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Description_From_FASTA] [text] COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Modified_Fasta_Description] [text] COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Protein_ID] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[GI_ID] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Monoisotopic_Mass] [float] NULL ,
	[Average_Mass] [float] NULL ,
	[Most_Abundant_Isotope] [float] NULL ,
	[Molecular_Formula] [varchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Protein_Sequence] [text] COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Isoelectric_Point] [float] NULL ,
	[Location_Start] [int] NULL ,
	[Location_Stop] [int] NULL ,
	[Strand] [varchar] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Reading_Frame] [int] NULL ,
	[Intergenic_Gap] [int] NULL ,
	[Upstream_Gap] [int] NULL ,
	[Is_Coding_Region] [bit] NULL ,
	[CAI] [float] NULL ,
	[Amino_Acid_Count] [int] NULL ,
	[Amino_Acid_Formula] [varchar] (512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Promoter_ID] [int] NULL ,
	[Chromosome_ID] [int] NULL ,
	[ORF_ID] [int] IDENTITY (1, 1) NOT NULL ,
	[Transmembrane_ID] [int] NULL ,
	[Date_Modified] [datetime] NULL ,
	[Date_Created] [datetime] NULL ,
	CONSTRAINT [PK_T_ORF] PRIMARY KEY  CLUSTERED 
	(
		[ORF_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_ORF_T_ORF_Chromosome] FOREIGN KEY 
	(
		[Chromosome_ID]
	) REFERENCES [T_ORF_Chromosome] (
		[Chromosome_ID]
	)
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_ORF] ON [T_ORF]([Reference]) WITH  FILLFACTOR = 90 ON [PRIMARY]
GO


