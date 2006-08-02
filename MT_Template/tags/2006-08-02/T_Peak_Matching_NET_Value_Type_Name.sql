if exists (select * from dbo.sysobjects where id = object_id(N'[T_Peak_Matching_NET_Value_Type_Name]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Peak_Matching_NET_Value_Type_Name]
GO

CREATE TABLE [T_Peak_Matching_NET_Value_Type_Name] (
	[NET_Value_Type] [tinyint] NOT NULL ,
	[NET_Value_Type_Name] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	CONSTRAINT [PK_T_Peak_Matching_NET_Value_Type_Name] PRIMARY KEY  CLUSTERED 
	(
		[NET_Value_Type]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] 
) ON [PRIMARY]
GO


