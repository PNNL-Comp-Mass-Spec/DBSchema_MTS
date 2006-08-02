if exists (select * from dbo.sysobjects where id = object_id(N'[T_Proteins]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Proteins]
GO

CREATE TABLE [T_Proteins] (
	[Ref_ID] [int] IDENTITY (100, 1) NOT NULL ,
	[Reference] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Description] [varchar] (7500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Protein_Sequence] [text] COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Protein_Residue_Count] [int] NULL ,
	[Monoisotopic_Mass] [float] NULL ,
	[Protein_DB_ID] [int] NULL ,
	[External_Reference_ID] [int] NULL ,
	[External_Protein_ID] [int] NULL ,
	[Protein_Collection_ID] [int] NULL ,
	[Last_Affected] [datetime] NOT NULL CONSTRAINT [DF_T_Proteins_Last_Affected] DEFAULT (getdate()),
	CONSTRAINT [PK_T_Proteins] PRIMARY KEY  CLUSTERED 
	(
		[Ref_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] 
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_Proteins_Reference] ON [T_Proteins]([Reference]) WITH  FILLFACTOR = 90 ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_Proteins_Protein_Collection_ID] ON [T_Proteins]([Protein_Collection_ID]) ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_Proteins_External_Reference_ID] ON [T_Proteins]([External_Reference_ID]) ON [PRIMARY]
GO


