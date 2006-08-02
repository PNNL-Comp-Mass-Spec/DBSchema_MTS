if exists (select * from dbo.sysobjects where id = object_id(N'[T_Mass_Tag_to_Protein_Map]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Mass_Tag_to_Protein_Map]
GO

CREATE TABLE [T_Mass_Tag_to_Protein_Map] (
	[Mass_Tag_ID] [int] NOT NULL ,
	[Mass_Tag_Name] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Ref_ID] [int] NOT NULL ,
	[Cleavage_State] [tinyint] NULL ,
	[Fragment_Number] [smallint] NULL ,
	[Fragment_Span] [smallint] NULL ,
	[Residue_Start] [int] NULL ,
	[Residue_End] [int] NULL ,
	[Repeat_Count] [smallint] NULL ,
	[Terminus_State] [tinyint] NULL ,
	CONSTRAINT [PK_T_Mass_Tag_to_Protein_Map] PRIMARY KEY  CLUSTERED 
	(
		[Mass_Tag_ID],
		[Ref_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_Mass_Tag_to_Protein_Map_T_Mass_Tags] FOREIGN KEY 
	(
		[Mass_Tag_ID]
	) REFERENCES [T_Mass_Tags] (
		[Mass_Tag_ID]
	),
	CONSTRAINT [FK_T_Mass_Tag_to_Protein_Map_T_Peptide_Cleavage_State_Name] FOREIGN KEY 
	(
		[Cleavage_State]
	) REFERENCES [T_Peptide_Cleavage_State_Name] (
		[Cleavage_State]
	),
	CONSTRAINT [FK_T_Mass_Tag_to_Protein_Map_T_Peptide_Terminus_State_Name] FOREIGN KEY 
	(
		[Terminus_State]
	) REFERENCES [T_Peptide_Terminus_State_Name] (
		[Terminus_State]
	),
	CONSTRAINT [FK_T_Mass_Tag_to_Protein_Map_T_Proteins] FOREIGN KEY 
	(
		[Ref_ID]
	) REFERENCES [T_Proteins] (
		[Ref_ID]
	)
) ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_Mass_Tag_to_Protein_Map_CleavageState] ON [T_Mass_Tag_to_Protein_Map]([Cleavage_State]) ON [PRIMARY]
GO

 CREATE  INDEX [T_Mass_Tag_to_Protein_Map_Cleavage_And_Terminus_State] ON [T_Mass_Tag_to_Protein_Map]([Mass_Tag_ID], [Cleavage_State], [Terminus_State]) ON [PRIMARY]
GO


