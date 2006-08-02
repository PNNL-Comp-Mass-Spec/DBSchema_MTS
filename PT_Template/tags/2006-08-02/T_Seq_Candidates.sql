if exists (select * from dbo.sysobjects where id = object_id(N'[T_Seq_Candidates]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Seq_Candidates]
GO

CREATE TABLE [T_Seq_Candidates] (
	[Job] [int] NOT NULL ,
	[Seq_ID_Local] [int] NOT NULL ,
	[Clean_Sequence] [varchar] (850) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Mod_Count] [smallint] NOT NULL ,
	[Mod_Description] [varchar] (2048) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Monoisotopic_Mass] [float] NULL ,
	[Seq_ID] [int] NULL ,
	[Add_Sequence] [tinyint] NULL CONSTRAINT [DF_T_Seq_Candidates_Add_Sequence] DEFAULT (0),
	CONSTRAINT [PK_T_Seq_Candidates] PRIMARY KEY  CLUSTERED 
	(
		[Job],
		[Seq_ID_Local]
	)  ON [PRIMARY] ,
	CONSTRAINT [FK_T_Seq_Candidates_T_Analysis_Description] FOREIGN KEY 
	(
		[Job]
	) REFERENCES [T_Analysis_Description] (
		[Job]
	)
) ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_Seq_Candidates_ModCount] ON [T_Seq_Candidates]([Mod_Count]) ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_Seq_Candidates_CleanSequence] ON [T_Seq_Candidates]([Clean_Sequence]) ON [PRIMARY]
GO

GRANT  UPDATE  ON [dbo].[T_Seq_Candidates] (
	[Seq_ID]
	) TO [MTUser]
GO


