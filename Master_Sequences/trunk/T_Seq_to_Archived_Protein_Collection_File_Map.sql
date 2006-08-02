if exists (select * from dbo.sysobjects where id = object_id(N'[T_Seq_to_Archived_Protein_Collection_File_Map]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Seq_to_Archived_Protein_Collection_File_Map]
GO

CREATE TABLE [T_Seq_to_Archived_Protein_Collection_File_Map] (
	[Seq_ID] [int] NOT NULL ,
	[File_ID] [int] NOT NULL ,
	CONSTRAINT [PK_T_Seq_to_Archived_Protein_Collection_File_Map] PRIMARY KEY  NONCLUSTERED 
	(
		[Seq_ID],
		[File_ID]
	)  ON [PRIMARY] 
) ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_Seq_to_Archived_Protein_Collection_File_Map] ON [T_Seq_to_Archived_Protein_Collection_File_Map]([File_ID]) ON [PRIMARY]
GO

GRANT  INSERT  ON [dbo].[T_Seq_to_Archived_Protein_Collection_File_Map]  TO [DMS_SP_User]
GO


