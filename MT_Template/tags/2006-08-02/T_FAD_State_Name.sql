if exists (select * from dbo.sysobjects where id = object_id(N'[T_FAD_State_Name]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_FAD_State_Name]
GO

CREATE TABLE [T_FAD_State_Name] (
	[FAD_State_ID] [int] NOT NULL ,
	[FAD_State_Name] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	CONSTRAINT [PK_T_FTICR_Analysis_State_Name] PRIMARY KEY  CLUSTERED 
	(
		[FAD_State_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] 
) ON [PRIMARY]
GO


