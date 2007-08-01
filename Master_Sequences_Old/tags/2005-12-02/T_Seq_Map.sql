if exists (select * from dbo.sysobjects where id = object_id(N'[T_Seq_Map]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Seq_Map]
GO

CREATE TABLE [T_Seq_Map] (
	[Seq_ID] [int] NOT NULL ,
	[Map_ID] [int] NOT NULL ,
	CONSTRAINT [PK_T_Seq_Map] PRIMARY KEY  NONCLUSTERED 
	(
		[Seq_ID],
		[Map_ID]
	)  ON [PRIMARY] ,
	CONSTRAINT [FK_T_Seq_Map_T_Sequence] FOREIGN KEY 
	(
		[Seq_ID]
	) REFERENCES [T_Sequence] (
		[Seq_ID]
	)
) ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_Seq_Map_Map_ID] ON [T_Seq_Map]([Map_ID]) ON [PRIMARY]
GO


