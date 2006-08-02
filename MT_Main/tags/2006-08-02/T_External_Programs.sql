if exists (select * from dbo.sysobjects where id = object_id(N'[T_External_Programs]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_External_Programs]
GO

CREATE TABLE [T_External_Programs] (
	[Program_Name] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Path_To_Executable] [varchar] (260) COLLATE SQL_Latin1_General_CP1_CI_AS NULL 
) ON [PRIMARY]
GO


