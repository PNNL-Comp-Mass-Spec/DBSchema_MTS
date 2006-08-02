if exists (select * from dbo.sysobjects where id = object_id(N'[T_MMD_Type_Name]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_MMD_Type_Name]
GO

CREATE TABLE [T_MMD_Type_Name] (
	[MD_Type] [int] NOT NULL ,
	[MD_Type_Name] [varchar] (256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	CONSTRAINT [PK_T_MM_TypeName] PRIMARY KEY  CLUSTERED 
	(
		[MD_Type]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] 
) ON [PRIMARY]
GO


