if exists (select * from dbo.sysobjects where id = object_id(N'[T_Proteins]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Proteins]
GO

CREATE TABLE [T_Proteins] (
	[Ref_ID] [int] IDENTITY (100, 1) NOT NULL ,
	[Reference] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	CONSTRAINT [PK_T_Proteins] PRIMARY KEY  CLUSTERED 
	(
		[Ref_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] 
) ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_Proteins] ON [T_Proteins]([Reference]) WITH  FILLFACTOR = 90 ON [PRIMARY]
GO


