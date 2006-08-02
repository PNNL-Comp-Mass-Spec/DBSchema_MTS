if exists (select * from dbo.sysobjects where id = object_id(N'[T_NET_Update_Task_State_Name]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_NET_Update_Task_State_Name]
GO

CREATE TABLE [T_NET_Update_Task_State_Name] (
	[Processing_State] [tinyint] NOT NULL ,
	[Processing_State_Name] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	CONSTRAINT [PK_T_NET_Update_Task_State_Name] PRIMARY KEY  CLUSTERED 
	(
		[Processing_State]
	)  ON [PRIMARY] 
) ON [PRIMARY]
GO


