if exists (select * from dbo.sysobjects where id = object_id(N'[T_Score_Sequest]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Score_Sequest]
GO

CREATE TABLE [T_Score_Sequest] (
	[Peptide_ID] [int] NOT NULL ,
	[XCorr] [real] NULL ,
	[DeltaCn] [real] NULL ,
	[DeltaCn2] [real] NULL ,
	[Sp] [float] NULL ,
	[RankSp] [int] NULL ,
	[RankXc] [int] NULL ,
	[DelM] [float] NULL ,
	[XcRatio] [real] NULL ,
	CONSTRAINT [PK_T_Score_Sequest] PRIMARY KEY  CLUSTERED 
	(
		[Peptide_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_Score_Sequest_T_Peptides] FOREIGN KEY 
	(
		[Peptide_ID]
	) REFERENCES [T_Peptides] (
		[Peptide_ID]
	)
) ON [PRIMARY]
GO


