if exists (select * from dbo.sysobjects where id = object_id(N'[T_Quantitation_MDIDs]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Quantitation_MDIDs]
GO

CREATE TABLE [T_Quantitation_MDIDs] (
	[Q_MDID_ID] [int] IDENTITY (1, 1) NOT NULL ,
	[Quantitation_ID] [int] NOT NULL ,
	[MD_ID] [int] NOT NULL ,
	[Replicate] [smallint] NOT NULL CONSTRAINT [DF_T_Quantitation_MDIDs_Replicate] DEFAULT (1),
	[Fraction] [smallint] NOT NULL CONSTRAINT [DF_T_Quantitation_MDIDs_Fraction] DEFAULT (1),
	[TopLevelFraction] [smallint] NOT NULL CONSTRAINT [DF_T_Quantitation_MDIDs_TopLevelFraction] DEFAULT (1),
	CONSTRAINT [PK_T_Quantitation_MDIDs] PRIMARY KEY  NONCLUSTERED 
	(
		[Q_MDID_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_Quantitation_MDIDs_T_Match_Making_Description] FOREIGN KEY 
	(
		[MD_ID]
	) REFERENCES [T_Match_Making_Description] (
		[MD_ID]
	),
	CONSTRAINT [FK_T_Quantitation_MDIDs_T_Quantitation_Description] FOREIGN KEY 
	(
		[Quantitation_ID]
	) REFERENCES [T_Quantitation_Description] (
		[Quantitation_ID]
	)
) ON [PRIMARY]
GO

 CREATE  CLUSTERED  INDEX [IX_T_Quantitation_MDIDs] ON [T_Quantitation_MDIDs]([Quantitation_ID]) WITH  FILLFACTOR = 90 ON [PRIMARY]
GO

GRANT  SELECT ,  UPDATE ,  INSERT ,  DELETE  ON [dbo].[T_Quantitation_MDIDs]  TO [DMS_SP_User]
GO


