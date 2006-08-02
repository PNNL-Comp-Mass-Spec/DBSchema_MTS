if exists (select * from dbo.sysobjects where id = object_id(N'[T_Score_Discriminant]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Score_Discriminant]
GO

CREATE TABLE [T_Score_Discriminant] (
	[Peptide_ID] [int] NOT NULL ,
	[MScore] [real] NULL ,
	[DiscriminantScore] [float] NULL ,
	[DiscriminantScoreNorm] [real] NULL ,
	[PassFilt] [int] NULL ,
	CONSTRAINT [PK_T_Score_Discriminant] PRIMARY KEY  CLUSTERED 
	(
		[Peptide_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_Score_Discriminant_T_Peptides] FOREIGN KEY 
	(
		[Peptide_ID]
	) REFERENCES [T_Peptides] (
		[Peptide_ID]
	)
) ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_Score_Discriminant] ON [T_Score_Discriminant]([DiscriminantScoreNorm]) WITH  FILLFACTOR = 90 ON [PRIMARY]
GO


