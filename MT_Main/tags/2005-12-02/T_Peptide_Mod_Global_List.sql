if exists (select * from dbo.sysobjects where id = object_id(N'[T_Peptide_Mod_Global_List]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Peptide_Mod_Global_List]
GO

CREATE TABLE [T_Peptide_Mod_Global_List] (
	[Mod_ID] [int] NOT NULL ,
	[Symbol] [char] (8) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Description] [varchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[SD_Flag] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Mass_Correction_Factor] [float] NULL ,
	[Affected_Residues] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_Peptide_Mod_Global_List_Affected_Residues] DEFAULT (''),
	CONSTRAINT [PK_T_Peptide_Mod_Global_List] PRIMARY KEY  CLUSTERED 
	(
		[Mod_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [IX_T_Peptide_Mod_Global_List_Residue_and_Mass] UNIQUE  NONCLUSTERED 
	(
		[SD_Flag],
		[Affected_Residues],
		[Mass_Correction_Factor]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [IX_T_Peptide_Mod_Global_List_Symbol_and_SD] UNIQUE  NONCLUSTERED 
	(
		[Symbol],
		[SD_Flag]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] 
) ON [PRIMARY]
GO


