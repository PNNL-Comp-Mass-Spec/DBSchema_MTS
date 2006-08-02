if exists (select * from dbo.sysobjects where id = object_id(N'[T_Internal_Standards]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Internal_Standards]
GO

CREATE TABLE [T_Internal_Standards] (
	[Internal_Std_Mix_ID] [int] IDENTITY (1, 1) NOT NULL ,
	[Name] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Description] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Type] [varchar] (32) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	CONSTRAINT [PK_T_Internal_Standards] PRIMARY KEY  CLUSTERED 
	(
		[Internal_Std_Mix_ID]
	)  ON [PRIMARY] ,
	CONSTRAINT [CK_T_Internal_Standards] CHECK ([Type] = 'All' or ([Type] = 'Postdigest' or [Type] = 'Predigest'))
) ON [PRIMARY]
GO

 CREATE  UNIQUE  INDEX [IX_T_Internal_Standards] ON [T_Internal_Standards]([Name]) ON [PRIMARY]
GO


