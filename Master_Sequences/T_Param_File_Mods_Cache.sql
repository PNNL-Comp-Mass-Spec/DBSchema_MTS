/****** Object:  Table [dbo].[T_Param_File_Mods_Cache] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Param_File_Mods_Cache](
	[Parameter_File_Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Param_File_ID] [int] NULL,
	[Last_Update] [datetime] NULL,
	[PM_Target_Symbol_List] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[PM_Mass_Correction_Tag_List] [varchar](512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[NP_Mass_Correction_Tag_List] [varchar](512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [PK_T_Param_File_Mods_Cache] PRIMARY KEY CLUSTERED 
(
	[Parameter_File_Name] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
GRANT INSERT ON [dbo].[T_Param_File_Mods_Cache] TO [DMS_SP_User] AS [dbo]
GO
GRANT UPDATE ON [dbo].[T_Param_File_Mods_Cache] TO [DMS_SP_User] AS [dbo]
GO
