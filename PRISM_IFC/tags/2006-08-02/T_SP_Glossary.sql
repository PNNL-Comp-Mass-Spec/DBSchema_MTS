if exists (select * from dbo.sysobjects where id = object_id(N'[T_SP_Glossary]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_SP_Glossary]
GO

CREATE TABLE [T_SP_Glossary] (
	[SP_ID] [int] NOT NULL ,
	[Column_Name] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Direction_ID] [int] NOT NULL ,
	[Ordinal_Position] [smallint] NOT NULL ,
	[Data_Type_Name] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Field_Length] [int] NULL ,
	[Description] [varchar] (1024) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	CONSTRAINT [PK_T_SP_Glossary] PRIMARY KEY  NONCLUSTERED 
	(
		[SP_ID],
		[Column_Name]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_SP_Glossary_T_SP_List] FOREIGN KEY 
	(
		[SP_ID]
	) REFERENCES [T_SP_List] (
		[SP_ID]
	)
) ON [PRIMARY]
GO

 CREATE  CLUSTERED  INDEX [IX_T_SP_Glossary] ON [T_SP_Glossary]([SP_ID], [Direction_ID], [Ordinal_Position]) WITH  FILLFACTOR = 90 ON [PRIMARY]
GO


