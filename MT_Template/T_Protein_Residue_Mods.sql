/****** Object:  Table [dbo].[T_Protein_Residue_Mods] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Protein_Residue_Mods](
	[Residue_Mod_ID] [int] IDENTITY(100,1) NOT NULL,
	[Ref_ID] [int] NOT NULL,
	[Residue_Num] [int] NOT NULL,
	[Mod_Name] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Entered] [datetime] NOT NULL CONSTRAINT [DF_T_Protein_Residue_Mods_Entered]  DEFAULT (getdate()),
 CONSTRAINT [PK_T_Protein_Residue_Mods] PRIMARY KEY NONCLUSTERED 
(
	[Residue_Mod_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Protein_Residue_Mods_RefID_ResidueNum] ******/
CREATE CLUSTERED INDEX [IX_T_Protein_Residue_Mods_RefID_ResidueNum] ON [dbo].[T_Protein_Residue_Mods] 
(
	[Ref_ID] ASC,
	[Residue_Num] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [IX_T_Protein_Residue_Mods_RefID_ResidueNum_ModName] ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_T_Protein_Residue_Mods_RefID_ResidueNum_ModName] ON [dbo].[T_Protein_Residue_Mods] 
(
	[Ref_ID] ASC,
	[Residue_Num] ASC,
	[Mod_Name] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_Protein_Residue_Mods]  WITH CHECK ADD  CONSTRAINT [FK_T_Protein_Residue_Mods_T_Proteins] FOREIGN KEY([Ref_ID])
REFERENCES [T_Proteins] ([Ref_ID])
GO
ALTER TABLE [dbo].[T_Protein_Residue_Mods] CHECK CONSTRAINT [FK_T_Protein_Residue_Mods_T_Proteins]
GO
