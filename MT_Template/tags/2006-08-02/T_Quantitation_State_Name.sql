if exists (select * from dbo.sysobjects where id = object_id(N'[T_Quantitation_State_Name]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Quantitation_State_Name]
GO

CREATE TABLE [T_Quantitation_State_Name] (
	[Quantitation_State] [tinyint] NOT NULL ,
	[Quantitation_State_Name] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	CONSTRAINT [PK_T_Quantitation_State_Name] PRIMARY KEY  CLUSTERED 
	(
		[Quantitation_State]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] 
) ON [PRIMARY]
GO


