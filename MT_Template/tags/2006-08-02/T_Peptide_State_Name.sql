if exists (select * from dbo.sysobjects where id = object_id(N'[T_Peptide_State_Name]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Peptide_State_Name]
GO

CREATE TABLE [T_Peptide_State_Name] (
	[State_ID] [tinyint] NOT NULL ,
	[State_Name] [varchar] (32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	CONSTRAINT [PK_T_Peptide_State_Name] PRIMARY KEY  CLUSTERED 
	(
		[State_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] 
) ON [PRIMARY]
GO


