if exists (select * from dbo.sysobjects where id = object_id(N'[T_Sequence]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Sequence]
GO

CREATE TABLE [T_Sequence] (
	[Seq_ID] [int] NOT NULL ,
	[Clean_Sequence] [varchar] (850) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Mod_Count] [smallint] NULL ,
	[Mod_Description] [varchar] (2048) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Monoisotopic_Mass] [float] NULL ,
	[GANET_Predicted] [real] NULL ,
	[Cleavage_State_Max] [tinyint] NOT NULL CONSTRAINT [DF_T_Sequence_Cleavage_State_Max] DEFAULT (0),
	CONSTRAINT [PK_T_Sequence] PRIMARY KEY  NONCLUSTERED 
	(
		[Seq_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] 
) ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_Sequence] ON [T_Sequence]([Clean_Sequence]) WITH  FILLFACTOR = 90 ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_Sequence_ModCount] ON [T_Sequence]([Mod_Count]) ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_Sequence_Monoisotopic_Mass] ON [T_Sequence]([Monoisotopic_Mass]) ON [PRIMARY]
GO

 CREATE  UNIQUE  INDEX [IX_T_Sequence_Seq_ID_Monoisotopic_Mass] ON [T_Sequence]([Seq_ID], [Monoisotopic_Mass]) ON [PRIMARY]
GO

 CREATE  INDEX [T_Sequence_Seq_ID_Cleavage_State_Max] ON [T_Sequence]([Seq_ID], [Cleavage_State_Max]) ON [PRIMARY]
GO


