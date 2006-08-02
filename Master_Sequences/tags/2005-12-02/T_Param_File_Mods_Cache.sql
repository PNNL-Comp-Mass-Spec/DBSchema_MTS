if exists (select * from dbo.sysobjects where id = object_id(N'[T_Param_File_Mods_Cache]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Param_File_Mods_Cache]
GO

CREATE TABLE [T_Param_File_Mods_Cache] (
	[Parameter_File_Name] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Param_File_ID] [int] NULL ,
	[Last_Update] [datetime] NULL ,
	[PM_Target_Symbol_List] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[PM_Mass_Correction_Tag_List] [varchar] (512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[NP_Mass_Correction_Tag_List] [varchar] (512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	CONSTRAINT [PK_T_Param_File_Mods_Cache] PRIMARY KEY  CLUSTERED 
	(
		[Parameter_File_Name]
	)  ON [PRIMARY] 
) ON [PRIMARY]
GO


