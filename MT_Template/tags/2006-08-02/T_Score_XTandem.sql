if exists (select * from dbo.sysobjects where id = object_id(N'[T_Score_XTandem]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Score_XTandem]
GO

CREATE TABLE [T_Score_XTandem] (
	[Peptide_ID] [int] NOT NULL ,
	[Hyperscore] [real] NULL ,
	[Log_EValue] [real] NULL ,
	[DeltaCn2] [real] NULL ,
	[Y_Score] [real] NULL ,
	[Y_Ions] [tinyint] NULL ,
	[B_Score] [real] NULL ,
	[B_Ions] [tinyint] NULL ,
	[DelM] [real] NULL ,
	[Intensity] [real] NULL ,
	[Normalized_Score] [real] NULL ,
	CONSTRAINT [PK_T_Score_XTandem] PRIMARY KEY  CLUSTERED 
	(
		[Peptide_ID]
	)  ON [PRIMARY] ,
	CONSTRAINT [FK_T_Score_XTandem_T_Peptides] FOREIGN KEY 
	(
		[Peptide_ID]
	) REFERENCES [T_Peptides] (
		[Peptide_ID]
	)
) ON [PRIMARY]
GO


