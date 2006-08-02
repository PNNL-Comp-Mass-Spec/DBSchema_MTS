if exists (select * from dbo.sysobjects where id = object_id(N'[T_Tmp_Map_ID_to_Archived_File_ID]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Tmp_Map_ID_to_Archived_File_ID]
GO

CREATE TABLE [T_Tmp_Map_ID_to_Archived_File_ID] (
	[Map_ID] [smallint] NULL ,
	[Archived_File_ID] [smallint] NULL 
) ON [PRIMARY]
GO


