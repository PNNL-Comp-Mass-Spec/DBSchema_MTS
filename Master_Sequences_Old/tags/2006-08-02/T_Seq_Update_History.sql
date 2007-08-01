if exists (select * from dbo.sysobjects where id = object_id(N'[T_Seq_Update_History]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Seq_Update_History]
GO

CREATE TABLE [T_Seq_Update_History] (
	[Seq_ID] [int] NOT NULL ,
	[Clean_Sequence] [varchar] (850) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Mod_Count] [smallint] NOT NULL ,
	[Mod_Description_Old] [varchar] (2048) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Mod_Description_New] [varchar] (2048) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Seq_ID_Pointer] [int] NULL ,
	[Last_Affected] [datetime] NOT NULL CONSTRAINT [DF_T_Seq_Update_History_Last_Affected] DEFAULT (getdate()),
	[Monoisotopic_Mass] [float] NULL ,
	[GANET_Predicted] [real] NULL ,
	CONSTRAINT [PK_T_Seq_Update_History] PRIMARY KEY  CLUSTERED 
	(
		[Seq_ID]
	)  ON [PRIMARY] 
) ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_Seq_Update_History_Seq_ID_Pointer] ON [T_Seq_Update_History]([Seq_ID_Pointer]) ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_Seq_Update_History_Mod_Count] ON [T_Seq_Update_History]([Mod_Count]) ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_Seq_Update_History_Last_Affected] ON [T_Seq_Update_History]([Last_Affected]) ON [PRIMARY]
GO


