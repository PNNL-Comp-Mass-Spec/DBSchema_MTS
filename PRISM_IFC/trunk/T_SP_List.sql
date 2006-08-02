if exists (select * from dbo.sysobjects where id = object_id(N'[T_SP_List]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_SP_List]
GO

CREATE TABLE [T_SP_List] (
	[SP_ID] [int] IDENTITY (1, 1) NOT NULL ,
	[Category_ID] [int] NOT NULL CONSTRAINT [DF_T_SP_List_Category_ID] DEFAULT (0),
	[SP_Name] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[SP_Description] [varchar] (512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	CONSTRAINT [PK_T_SP_List] PRIMARY KEY  NONCLUSTERED 
	(
		[SP_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_SP_List_T_SP_Categories] FOREIGN KEY 
	(
		[Category_ID]
	) REFERENCES [T_SP_Categories] (
		[Category_ID]
	)
) ON [PRIMARY]
GO

 CREATE  UNIQUE  CLUSTERED  INDEX [IX_T_SP_List] ON [T_SP_List]([SP_Name]) WITH  FILLFACTOR = 90 ON [PRIMARY]
GO


