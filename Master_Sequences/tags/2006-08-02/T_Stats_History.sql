if exists (select * from dbo.sysobjects where id = object_id(N'[T_Stats_History]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Stats_History]
GO

CREATE TABLE [T_Stats_History] (
	[Entry_ID] [int] IDENTITY (1, 1) NOT NULL ,
	[Posting_Time] [datetime] NOT NULL CONSTRAINT [DF_T_Stats_History_Posting_Time] DEFAULT (getdate()),
	[Sequence_Count] [int] NOT NULL ,
	CONSTRAINT [PK_T_Stats_History] PRIMARY KEY  NONCLUSTERED 
	(
		[Entry_ID]
	)  ON [PRIMARY] 
) ON [PRIMARY]
GO

 CREATE  UNIQUE  CLUSTERED  INDEX [IX_T_Stats_History] ON [T_Stats_History]([Posting_Time]) ON [PRIMARY]
GO


