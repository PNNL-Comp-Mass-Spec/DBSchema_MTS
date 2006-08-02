if exists (select * from dbo.sysobjects where id = object_id(N'[T_Seq_Candidate_to_Peptide_Map]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Seq_Candidate_to_Peptide_Map]
GO

CREATE TABLE [T_Seq_Candidate_to_Peptide_Map] (
	[Job] [int] NOT NULL ,
	[Seq_ID_Local] [int] NOT NULL ,
	[Peptide_ID] [int] NOT NULL ,
	CONSTRAINT [PK_T_Seq_Candidate_to_Peptide_Map] PRIMARY KEY  CLUSTERED 
	(
		[Job],
		[Seq_ID_Local],
		[Peptide_ID]
	)  ON [PRIMARY] ,
	CONSTRAINT [FK_T_Seq_Candidate_to_Peptide_Map_T_Peptides] FOREIGN KEY 
	(
		[Peptide_ID]
	) REFERENCES [T_Peptides] (
		[Peptide_ID]
	),
	CONSTRAINT [FK_T_Seq_Candidate_to_Peptide_Map_T_Seq_Candidates] FOREIGN KEY 
	(
		[Job],
		[Seq_ID_Local]
	) REFERENCES [T_Seq_Candidates] (
		[Job],
		[Seq_ID_Local]
	)
) ON [PRIMARY]
GO


