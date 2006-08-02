if exists (select * from dbo.sysobjects where id = object_id(N'[T_GANET_Update_Task_State_Name]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_GANET_Update_Task_State_Name]
GO

CREATE TABLE [T_GANET_Update_Task_State_Name] (
	[Processing_State] [tinyint] NOT NULL ,
	[Processing_State_Name] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	CONSTRAINT [PK_T_GANET_Update_Task_State_Name] PRIMARY KEY  CLUSTERED 
	(
		[Processing_State]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] 
) ON [PRIMARY]
GO


