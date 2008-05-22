/****** Object:  Table [dbo].[T_Mass_Tag_to_Protein_Mod_Map] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Mass_Tag_to_Protein_Mod_Map](
	[Mass_Tag_ID] [int] NOT NULL,
	[Residue_Mod_ID] [int] NOT NULL,
	[Entered] [smalldatetime] NOT NULL CONSTRAINT [DF_T_Mass_Tag_to_Protein_Mod_Map_Entered]  DEFAULT (getdate()),
 CONSTRAINT [PK_T_Mass_Tag_to_Protein_Mod_Map] PRIMARY KEY CLUSTERED 
(
	[Mass_Tag_ID] ASC,
	[Residue_Mod_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Mass_Tag_to_Protein_Mod_Map_Residue_Mod_ID_Mass_Tag_ID] ******/
CREATE NONCLUSTERED INDEX [IX_T_Mass_Tag_to_Protein_Mod_Map_Residue_Mod_ID_Mass_Tag_ID] ON [dbo].[T_Mass_Tag_to_Protein_Mod_Map] 
(
	[Residue_Mod_ID] ASC,
	[Mass_Tag_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_Mass_Tag_to_Protein_Mod_Map]  WITH CHECK ADD  CONSTRAINT [FK_T_Mass_Tag_to_Protein_Mod_Map_T_Mass_Tags] FOREIGN KEY([Mass_Tag_ID])
REFERENCES [T_Mass_Tags] ([Mass_Tag_ID])
GO
ALTER TABLE [dbo].[T_Mass_Tag_to_Protein_Mod_Map] CHECK CONSTRAINT [FK_T_Mass_Tag_to_Protein_Mod_Map_T_Mass_Tags]
GO
ALTER TABLE [dbo].[T_Mass_Tag_to_Protein_Mod_Map]  WITH CHECK ADD  CONSTRAINT [FK_T_Mass_Tag_to_Protein_Mod_Map_T_Protein_Residue_Mods] FOREIGN KEY([Residue_Mod_ID])
REFERENCES [T_Protein_Residue_Mods] ([Residue_Mod_ID])
GO
ALTER TABLE [dbo].[T_Mass_Tag_to_Protein_Mod_Map] CHECK CONSTRAINT [FK_T_Mass_Tag_to_Protein_Mod_Map_T_Protein_Residue_Mods]
GO
