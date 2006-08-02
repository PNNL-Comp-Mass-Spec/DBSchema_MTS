if exists (select * from dbo.sysobjects where id = object_id(N'[T_Analysis_State_Name]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Analysis_State_Name]
GO

CREATE TABLE [T_Analysis_State_Name] (
	[AD_State_ID] [int] NOT NULL ,
	[AD_State_Name] [varchar] (32) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	CONSTRAINT [PK_T_Analysis_State_Name] PRIMARY KEY  CLUSTERED 
	(
		[AD_State_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] 
) ON [PRIMARY]
GO


