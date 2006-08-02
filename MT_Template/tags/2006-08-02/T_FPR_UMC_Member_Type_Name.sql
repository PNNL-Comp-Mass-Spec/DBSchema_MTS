if exists (select * from dbo.sysobjects where id = object_id(N'[T_FPR_UMC_Member_Type_Name]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_FPR_UMC_Member_Type_Name]
GO

CREATE TABLE [T_FPR_UMC_Member_Type_Name] (
	[Member_Type_ID] [tinyint] NOT NULL ,
	[Member_Type_Name] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	CONSTRAINT [PK_T_FPR_UMC_Member_Type_Name] PRIMARY KEY  CLUSTERED 
	(
		[Member_Type_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] 
) ON [PRIMARY]
GO


