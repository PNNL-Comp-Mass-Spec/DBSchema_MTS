if exists (select * from dbo.sysobjects where id = object_id(N'[T_Mod_Descriptors]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Mod_Descriptors]
GO

CREATE TABLE [T_Mod_Descriptors] (
	[Seq_ID] [int] NOT NULL ,
	[Mass_Correction_Tag] [char] (8) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Position] [smallint] NOT NULL ,
	CONSTRAINT [PK_T_Mod_Descriptors] PRIMARY KEY  NONCLUSTERED 
	(
		[Seq_ID],
		[Mass_Correction_Tag],
		[Position]
	)  ON [PRIMARY] ,
	CONSTRAINT [FK_T_Mod_Descriptors_T_Sequence] FOREIGN KEY 
	(
		[Seq_ID]
	) REFERENCES [T_Sequence] (
		[Seq_ID]
	)
) ON [PRIMARY]
GO

 CREATE  CLUSTERED  INDEX [IX_T_Mod_Descriptors] ON [T_Mod_Descriptors]([Seq_ID]) ON [PRIMARY]
GO


