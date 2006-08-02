if exists (select * from dbo.sysobjects where id = object_id(N'[T_Peak_Matching_Processors]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Peak_Matching_Processors]
GO

CREATE TABLE [T_Peak_Matching_Processors] (
	[PM_AssignedProcessorName] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Active] [tinyint] NOT NULL CONSTRAINT [DF_T_Peak_Matching_Processors_Active] DEFAULT (1),
	CONSTRAINT [PK_T_Peak_Matching_Processors] PRIMARY KEY  CLUSTERED 
	(
		[PM_AssignedProcessorName]
	)  ON [PRIMARY] 
) ON [PRIMARY]
GO


