if exists (select * from dbo.sysobjects where id = object_id(N'[T_Tmp_File_ID_Updates]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Tmp_File_ID_Updates]
GO

CREATE TABLE [T_Tmp_File_ID_Updates] (
	[Old_File_ID] [smallint] NULL ,
	[New_File_ID] [smallint] NULL 
) ON [PRIMARY]
GO


