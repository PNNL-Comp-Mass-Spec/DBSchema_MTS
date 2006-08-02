if exists (select * from dbo.sysobjects where id = object_id(N'[T_Seq_Mass_Update_History]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Seq_Mass_Update_History]
GO

CREATE TABLE [T_Seq_Mass_Update_History] (
	[Batch_ID] [int] NOT NULL ,
	[Seq_ID] [int] NOT NULL ,
	[Monoisotopic_Mass_Old] [float] NULL ,
	[Monoisotopic_Mass_New] [float] NULL ,
	[Update_Date] [datetime] NULL ,
	CONSTRAINT [PK_T_Mass_Update_History] PRIMARY KEY  CLUSTERED 
	(
		[Batch_ID],
		[Seq_ID]
	)  ON [PRIMARY] 
) ON [PRIMARY]
GO


