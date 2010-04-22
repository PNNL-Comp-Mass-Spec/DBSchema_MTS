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
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = ON, IGNORE_DUP_KEY = ON, ALLOW_ROW_LOCKS  = OFF, ALLOW_PAGE_LOCKS  = OFF, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Seq_to_Archived_Protein_Collection_File_Map] ******/
CREATE NONCLUSTERED INDEX [IX_T_Seq_to_Archived_Protein_Collection_File_Map] ON [dbo].[T_Seq_to_Archived_Protein_Collection_File_Map] 
(
	[File_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 90) ON [PRIMARY]
GO
GRANT INSERT ON [dbo].[T_Seq_to_Archived_Protein_Collection_File_Map] TO [DMS_SP_User] AS [dbo]
GO
