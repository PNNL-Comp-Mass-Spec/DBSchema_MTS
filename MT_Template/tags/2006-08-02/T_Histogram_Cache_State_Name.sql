if exists (select * from dbo.sysobjects where id = object_id(N'[T_Histogram_Cache_State_Name]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Histogram_Cache_State_Name]
GO

CREATE TABLE [T_Histogram_Cache_State_Name] (
	[Histogram_Cache_State] [smallint] NOT NULL ,
	[Histogram_Cache_State_Name] [varchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	CONSTRAINT [PK_T_Histogram_Cache_State_Name] PRIMARY KEY  CLUSTERED 
	(
		[Histogram_Cache_State]
	)  ON [PRIMARY] 
) ON [PRIMARY]
GO


