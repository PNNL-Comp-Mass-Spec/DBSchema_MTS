/****** Object:  Table [dbo].[T_Mass_Tag_to_Protein_Map] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Mass_Tag_to_Protein_Map](
	[Mass_Tag_ID] [int] NOT NULL,
	[Mass_Tag_Name] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Ref_ID] [int] NOT NULL,
	[Cleavage_State] [tinyint] NULL,
	[Fragment_Number] [smallint] NULL,
	[Fragment_Span] [smallint] NULL,
	[Residue_Start] [int] NULL,
	[Residue_End] [int] NULL,
	[Repeat_Count] [smallint] NULL,
	[Terminus_State] [tinyint] NULL,
	[Missed_Cleavage_Count] [smallint] NULL,
 CONSTRAINT [PK_T_Mass_Tag_to_Protein_Map] PRIMARY KEY CLUSTERED 
(
	[Mass_Tag_ID] ASC,
	[Ref_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Mass_Tag_to_Protein_Map_Cleavage_And_Terminus_State] ******/
CREATE NONCLUSTERED INDEX [IX_T_Mass_Tag_to_Protein_Map_Cleavage_And_Terminus_State] ON [dbo].[T_Mass_Tag_to_Protein_Map] 
(
	[Mass_Tag_ID] ASC,
	[Cleavage_State] ASC,
	[Terminus_State] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [IX_T_Mass_Tag_to_Protein_Map_CleavageState] ******/
CREATE NONCLUSTERED INDEX [IX_T_Mass_Tag_to_Protein_Map_CleavageState] ON [dbo].[T_Mass_Tag_to_Protein_Map] 
(
	[Cleavage_State] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_Mass_Tag_to_Protein_Map]  WITH NOCHECK ADD  CONSTRAINT [FK_T_Mass_Tag_to_Protein_Map_T_Mass_Tags] FOREIGN KEY([Mass_Tag_ID])
REFERENCES [T_Mass_Tags] ([Mass_Tag_ID])
GO
ALTER TABLE [dbo].[T_Mass_Tag_to_Protein_Map] CHECK CONSTRAINT [FK_T_Mass_Tag_to_Protein_Map_T_Mass_Tags]
GO
ALTER TABLE [dbo].[T_Mass_Tag_to_Protein_Map]  WITH CHECK ADD  CONSTRAINT [FK_T_Mass_Tag_to_Protein_Map_T_Peptide_Cleavage_State_Name] FOREIGN KEY([Cleavage_State])
REFERENCES [T_Peptide_Cleavage_State_Name] ([Cleavage_State])
GO
ALTER TABLE [dbo].[T_Mass_Tag_to_Protein_Map] CHECK CONSTRAINT [FK_T_Mass_Tag_to_Protein_Map_T_Peptide_Cleavage_State_Name]
GO
ALTER TABLE [dbo].[T_Mass_Tag_to_Protein_Map]  WITH CHECK ADD  CONSTRAINT [FK_T_Mass_Tag_to_Protein_Map_T_Peptide_Terminus_State_Name] FOREIGN KEY([Terminus_State])
REFERENCES [T_Peptide_Terminus_State_Name] ([Terminus_State])
GO
ALTER TABLE [dbo].[T_Mass_Tag_to_Protein_Map] CHECK CONSTRAINT [FK_T_Mass_Tag_to_Protein_Map_T_Peptide_Terminus_State_Name]
GO
ALTER TABLE [dbo].[T_Mass_Tag_to_Protein_Map]  WITH CHECK ADD  CONSTRAINT [FK_T_Mass_Tag_to_Protein_Map_T_Proteins] FOREIGN KEY([Ref_ID])
REFERENCES [T_Proteins] ([Ref_ID])
GO
ALTER TABLE [dbo].[T_Mass_Tag_to_Protein_Map] CHECK CONSTRAINT [FK_T_Mass_Tag_to_Protein_Map_T_Proteins]
GO
