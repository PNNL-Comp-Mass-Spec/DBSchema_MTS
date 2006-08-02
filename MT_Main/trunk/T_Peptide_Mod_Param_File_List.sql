if exists (select * from dbo.sysobjects where id = object_id(N'[T_Peptide_Mod_Param_File_List]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Peptide_Mod_Param_File_List]
GO

CREATE TABLE [T_Peptide_Mod_Param_File_List] (
	[Parm_File_Name] [varchar] (256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Local_Symbol] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Mod_ID] [int] NOT NULL ,
	[RefNum] [int] NOT NULL ,
	[Param_File_ID] [int] NULL ,
	CONSTRAINT [PK_T_Peptide_Mod_Param_File_List] PRIMARY KEY  NONCLUSTERED 
	(
		[RefNum]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [IX_T_Peptide_Mod_Param_File_List] UNIQUE  NONCLUSTERED 
	(
		[Parm_File_Name],
		[Mod_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_Peptide_Mod_Param_File_List_T_Peptide_Mod_Global_List] FOREIGN KEY 
	(
		[Mod_ID]
	) REFERENCES [T_Peptide_Mod_Global_List] (
		[Mod_ID]
	)
) ON [PRIMARY]
GO


