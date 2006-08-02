if exists (select * from dbo.sysobjects where id = object_id(N'[T_Peptide_Filter_Flags]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Peptide_Filter_Flags]
GO

CREATE TABLE [T_Peptide_Filter_Flags] (
	[Filter_ID] [int] NOT NULL ,
	[Peptide_ID] [int] NOT NULL ,
	CONSTRAINT [PK_T_Peptide_Filter_Flags] PRIMARY KEY  NONCLUSTERED 
	(
		[Filter_ID],
		[Peptide_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_Peptide_Filter_Flags_T_Peptides] FOREIGN KEY 
	(
		[Peptide_ID]
	) REFERENCES [T_Peptides] (
		[Peptide_ID]
	)
) ON [PRIMARY]
GO

 CREATE  CLUSTERED  INDEX [IX_T_Peptide_Filter_Flags_Peptide_ID] ON [T_Peptide_Filter_Flags]([Peptide_ID]) ON [PRIMARY]
GO


