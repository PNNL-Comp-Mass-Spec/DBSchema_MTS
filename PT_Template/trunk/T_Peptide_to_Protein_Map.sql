/****** Object:  Table [dbo].[T_Peptide_to_Protein_Map] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Peptide_to_Protein_Map](
	[Peptide_ID] [int] NOT NULL,
	[Ref_ID] [int] NOT NULL,
	[Cleavage_State] [tinyint] NULL,
	[Terminus_State] [tinyint] NULL,
	[XTandem_Log_EValue] [real] NULL,
 CONSTRAINT [PK_T_Peptide_to_Protein_Map] PRIMARY KEY CLUSTERED 
(
	[Peptide_ID] ASC,
	[Ref_ID] ASC
)WITH FILLFACTOR = 90 ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Peptide_to_Protein_Map]  WITH CHECK ADD  CONSTRAINT [FK_T_Peptide_to_Protein_Map_T_Peptide_Cleavage_State_Name] FOREIGN KEY([Cleavage_State])
REFERENCES [T_Peptide_Cleavage_State_Name] ([Cleavage_State])
GO
ALTER TABLE [dbo].[T_Peptide_to_Protein_Map] CHECK CONSTRAINT [FK_T_Peptide_to_Protein_Map_T_Peptide_Cleavage_State_Name]
GO
ALTER TABLE [dbo].[T_Peptide_to_Protein_Map]  WITH CHECK ADD  CONSTRAINT [FK_T_Peptide_to_Protein_Map_T_Peptide_Terminus_State_Name] FOREIGN KEY([Terminus_State])
REFERENCES [T_Peptide_Terminus_State_Name] ([Terminus_State])
GO
ALTER TABLE [dbo].[T_Peptide_to_Protein_Map] CHECK CONSTRAINT [FK_T_Peptide_to_Protein_Map_T_Peptide_Terminus_State_Name]
GO
ALTER TABLE [dbo].[T_Peptide_to_Protein_Map]  WITH CHECK ADD  CONSTRAINT [FK_T_Peptide_to_Protein_Map_T_Peptides] FOREIGN KEY([Peptide_ID])
REFERENCES [T_Peptides] ([Peptide_ID])
GO
ALTER TABLE [dbo].[T_Peptide_to_Protein_Map] CHECK CONSTRAINT [FK_T_Peptide_to_Protein_Map_T_Peptides]
GO
ALTER TABLE [dbo].[T_Peptide_to_Protein_Map]  WITH CHECK ADD  CONSTRAINT [FK_T_Peptide_to_Protein_Map_T_Proteins] FOREIGN KEY([Ref_ID])
REFERENCES [T_Proteins] ([Ref_ID])
GO
ALTER TABLE [dbo].[T_Peptide_to_Protein_Map] CHECK CONSTRAINT [FK_T_Peptide_to_Protein_Map_T_Proteins]
GO
