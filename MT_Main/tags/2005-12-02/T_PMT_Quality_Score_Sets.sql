if exists (select * from dbo.sysobjects where id = object_id(N'[T_PMT_Quality_Score_Sets]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_PMT_Quality_Score_Sets]
GO

CREATE TABLE [T_PMT_Quality_Score_Sets] (
	[PMT_Quality_Score_Set_ID] [int] IDENTITY (1, 1) NOT NULL ,
	[PMT_Quality_Score_Set_Name] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[PMT_Quality_Score_Set_Description] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Created] [datetime] NOT NULL CONSTRAINT [DF_T_PMT_Quality_Score_Sets_PMT_Created] DEFAULT (getdate()),
	CONSTRAINT [PK_T_PMT_Quality_Score_Sets] PRIMARY KEY  CLUSTERED 
	(
		[PMT_Quality_Score_Set_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] 
) ON [PRIMARY]
GO


