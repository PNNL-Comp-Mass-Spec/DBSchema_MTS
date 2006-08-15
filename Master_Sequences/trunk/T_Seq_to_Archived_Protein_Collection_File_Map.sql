/****** Object:  Table [dbo].[T_Seq_to_Archived_Protein_Collection_File_Map] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Seq_to_Archived_Protein_Collection_File_Map](
	[Seq_ID] [int] NOT NULL,
	[File_ID] [int] NOT NULL,
 CONSTRAINT [PK_T_Seq_to_Archived_Protein_Collection_File_Map] PRIMARY KEY NONCLUSTERED 
(
	[Seq_ID] ASC,
	[File_ID] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Seq_to_Archived_Protein_Collection_File_Map] ******/
CREATE NONCLUSTERED INDEX [IX_T_Seq_to_Archived_Protein_Collection_File_Map] ON [dbo].[T_Seq_to_Archived_Protein_Collection_File_Map] 
(
	[File_ID] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
GO
GRANT INSERT ON [dbo].[T_Seq_to_Archived_Protein_Collection_File_Map] TO [DMS_SP_User]
GO
