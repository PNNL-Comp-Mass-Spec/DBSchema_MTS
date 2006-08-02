if exists (select * from dbo.sysobjects where id = object_id(N'[T_Peptide_to_Protein_Map]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Peptide_to_Protein_Map]
GO

CREATE TABLE [T_Peptide_to_Protein_Map] (
	[Peptide_ID] [int] NOT NULL ,
	[Ref_ID] [int] NOT NULL ,
	[Cleavage_State] [tinyint] NULL ,
	[Terminus_State] [tinyint] NULL ,
	CONSTRAINT [PK_T_Peptide_to_Protein_Map] PRIMARY KEY  CLUSTERED 
	(
		[Peptide_ID],
		[Ref_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_Peptide_to_Protein_Map_T_Peptide_Cleavage_State_Name] FOREIGN KEY 
	(
		[Cleavage_State]
	) REFERENCES [T_Peptide_Cleavage_State_Name] (
		[Cleavage_State]
	),
	CONSTRAINT [FK_T_Peptide_to_Protein_Map_T_Peptide_Terminus_State_Name] FOREIGN KEY 
	(
		[Terminus_State]
	) REFERENCES [T_Peptide_Terminus_State_Name] (
		[Terminus_State]
	),
	CONSTRAINT [FK_T_Peptide_to_Protein_Map_T_Peptides] FOREIGN KEY 
	(
		[Peptide_ID]
	) REFERENCES [T_Peptides] (
		[Peptide_ID]
	),
	CONSTRAINT [FK_T_Peptide_to_Protein_Map_T_Proteins] FOREIGN KEY 
	(
		[Ref_ID]
	) REFERENCES [T_Proteins] (
		[Ref_ID]
	)
) ON [PRIMARY]
GO


