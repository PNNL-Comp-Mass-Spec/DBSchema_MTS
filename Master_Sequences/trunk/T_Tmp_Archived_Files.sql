if exists (select * from dbo.sysobjects where id = object_id(N'[T_Tmp_Archived_Files]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Tmp_Archived_Files]
GO

CREATE TABLE [T_Tmp_Archived_Files] (
	[Archived_File_ID] [smallint] NULL ,
	[FileName] [nvarchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL 
) ON [PRIMARY]
GO


