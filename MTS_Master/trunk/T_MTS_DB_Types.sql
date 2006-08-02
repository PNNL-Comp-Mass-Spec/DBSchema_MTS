if exists (select * from dbo.sysobjects where id = object_id(N'[T_MTS_DB_Types]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_MTS_DB_Types]
GO

CREATE TABLE [T_MTS_DB_Types] (
	[DB_Type_ID] [tinyint] NOT NULL ,
	[DB_Type_Name] [varchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[DB_Name_Prefix] [varchar] (8) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	CONSTRAINT [PK_T_MTS_DB_Types] PRIMARY KEY  CLUSTERED 
	(
		[DB_Type_ID]
	)  ON [PRIMARY] 
) ON [PRIMARY]
GO


