if exists (select * from dbo.sysobjects where id = object_id(N'[T_GANET_Locker_State_Name]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_GANET_Locker_State_Name]
GO

CREATE TABLE [T_GANET_Locker_State_Name] (
	[GANET_Locker_State] [tinyint] NOT NULL ,
	[GANET_Locker_State_Name] [varchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	CONSTRAINT [PK_T_GANET_Locker_State_Name] PRIMARY KEY  CLUSTERED 
	(
		[GANET_Locker_State]
	)  ON [PRIMARY] 
) ON [PRIMARY]
GO


