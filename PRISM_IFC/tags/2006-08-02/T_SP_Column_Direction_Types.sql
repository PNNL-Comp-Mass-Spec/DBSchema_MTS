if exists (select * from dbo.sysobjects where id = object_id(N'[T_SP_Column_Direction_Types]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_SP_Column_Direction_Types]
GO

CREATE TABLE [T_SP_Column_Direction_Types] (
	[Direction_ID] [int] NOT NULL ,
	[Direction_Name] [varchar] (32) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	CONSTRAINT [PK_T_SP_Column_Direction_Types] PRIMARY KEY  CLUSTERED 
	(
		[Direction_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] 
) ON [PRIMARY]
GO


