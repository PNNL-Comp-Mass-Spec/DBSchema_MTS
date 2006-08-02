if exists (select * from dbo.sysobjects where id = object_id(N'[T_GANET_Lockers]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_GANET_Lockers]
GO

CREATE TABLE [T_GANET_Lockers] (
	[Seq_ID] [int] NOT NULL ,
	[Description] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Charge_Minimum] [int] NOT NULL ,
	[Charge_Maximum] [int] NOT NULL ,
	[Charge_Highest_Abu] [int] NOT NULL ,
	[Min_GANET] [real] NULL ,
	[Max_GANET] [real] NULL ,
	[Avg_GANET] [real] NOT NULL ,
	[Cnt_GANET] [int] NULL ,
	[StD_GANET] [real] NULL ,
	[PNET] [real] NULL ,
	[GANET_Locker_State] [tinyint] NOT NULL CONSTRAINT [DF_T_GANET_Lockers_GANET_Locker_State] DEFAULT (1),
	CONSTRAINT [PK_T_GANET_Lockers] PRIMARY KEY  CLUSTERED 
	(
		[Seq_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_GANET_Lockers_T_GANET_Locker_State_Name] FOREIGN KEY 
	(
		[GANET_Locker_State]
	) REFERENCES [T_GANET_Locker_State_Name] (
		[GANET_Locker_State]
	),
	CONSTRAINT [FK_T_GANET_Lockers_T_Mass_Tags] FOREIGN KEY 
	(
		[Seq_ID]
	) REFERENCES [T_Mass_Tags] (
		[Mass_Tag_ID]
	)
) ON [PRIMARY]
GO


