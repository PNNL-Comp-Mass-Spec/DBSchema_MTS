if exists (select * from dbo.sysobjects where id = object_id(N'[T_Usage_Stats]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Usage_Stats]
GO

CREATE TABLE [T_Usage_Stats] (
	[Posted_By] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Last_Posting_Time] [datetime] NOT NULL CONSTRAINT [DF_T_Usage_Stats_Last_Posting_Time] DEFAULT (getdate()),
	[Usage_Count] [int] NOT NULL CONSTRAINT [DF_T_Usage_Stats_Usage_Count] DEFAULT (1),
	CONSTRAINT [PK_T_Usage_Stats] PRIMARY KEY  CLUSTERED 
	(
		[Posted_By]
	)  ON [PRIMARY] 
) ON [PRIMARY]
GO


