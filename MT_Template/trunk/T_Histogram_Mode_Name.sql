if exists (select * from dbo.sysobjects where id = object_id(N'[T_Histogram_Mode_Name]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Histogram_Mode_Name]
GO

CREATE TABLE [T_Histogram_Mode_Name] (
	[Histogram_Mode] [smallint] NOT NULL ,
	[Histogram_Mode_Name] [varchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	CONSTRAINT [PK_T_Histogram_Mode_Name] PRIMARY KEY  CLUSTERED 
	(
		[Histogram_Mode]
	)  ON [PRIMARY] 
) ON [PRIMARY]
GO


