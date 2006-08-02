if exists (select * from dbo.sysobjects where id = object_id(N'[T_Sequence]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Sequence]
GO

CREATE TABLE [T_Sequence] (
	[Seq_ID] [int] IDENTITY (1000, 1) NOT NULL ,
	[Clean_Sequence] [varchar] (850) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Mod_Count] [smallint] NULL ,
	[Mod_Description] [varchar] (2048) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Monoisotopic_Mass] [float] NULL ,
	[GANET_Predicted] [real] NULL ,
	[Last_Affected] [smalldatetime] NULL CONSTRAINT [DF_T_Sequence_Last_Affected] DEFAULT (getdate()),
	CONSTRAINT [PK_T_Sequence] PRIMARY KEY  CLUSTERED 
	(
		[Seq_ID]
	)  ON [PRIMARY] 
) ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_Sequence] ON [T_Sequence]([Clean_Sequence]) ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_Sequence_Monoisotopic_Mass] ON [T_Sequence]([Monoisotopic_Mass]) ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_Sequence_Mod_Count] ON [T_Sequence]([Mod_Count]) ON [PRIMARY]
GO

GRANT  INSERT  ON [dbo].[T_Sequence]  TO [DMS_SP_User]
GO

GRANT  UPDATE  ON [dbo].[T_Sequence] (
	[Seq_ID], 
	[GANET_Predicted], 
	[Last_Affected]
	) TO [DMS_SP_User]
GO

GRANT  INSERT  ON [dbo].[T_Sequence]  TO [MTUser]
GO

GRANT  UPDATE  ON [dbo].[T_Sequence] (
	[Seq_ID], 
	[GANET_Predicted], 
	[Last_Affected]
	) TO [MTUser]
GO


