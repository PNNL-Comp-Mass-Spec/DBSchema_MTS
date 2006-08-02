if exists (select * from dbo.sysobjects where id = object_id(N'[T_Process_Config_Parameters]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Process_Config_Parameters]
GO

CREATE TABLE [T_Process_Config_Parameters] (
	[Name] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Function] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Min_Occurrences] [smallint] NOT NULL CONSTRAINT [DF_T_Process_Config_Parameters_Min_Occurrences] DEFAULT (1),
	[Max_Occurrences] [smallint] NOT NULL CONSTRAINT [DF_T_Process_Config_Parameters_Max_Occurrences] DEFAULT (99),
	[Description] [varchar] (512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	CONSTRAINT [PK_T_Process_Config_Parameters] PRIMARY KEY  CLUSTERED 
	(
		[Name]
	)  ON [PRIMARY] 
) ON [PRIMARY]
GO


