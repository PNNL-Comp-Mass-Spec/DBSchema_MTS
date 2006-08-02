if exists (select * from dbo.sysobjects where id = object_id(N'[T_Dataset_Scan_Type_Name]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Dataset_Scan_Type_Name]
GO

CREATE TABLE [T_Dataset_Scan_Type_Name] (
	[Scan_Type] [tinyint] NOT NULL ,
	[Scan_Type_Name] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	CONSTRAINT [PK_T_Dataset_Scan_Type_Name] PRIMARY KEY  CLUSTERED 
	(
		[Scan_Type]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] 
) ON [PRIMARY]
GO


