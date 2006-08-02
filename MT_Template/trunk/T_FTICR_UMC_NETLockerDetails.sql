if exists (select * from dbo.sysobjects where id = object_id(N'[T_FTICR_UMC_NETLockerDetails]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_FTICR_UMC_NETLockerDetails]
GO

CREATE TABLE [T_FTICR_UMC_NETLockerDetails] (
	[UMC_NETLockerDetails_ID] [int] IDENTITY (1, 1) NOT NULL ,
	[UMC_Results_ID] [int] NOT NULL ,
	[Seq_ID] [int] NOT NULL ,
	[Match_Score] [decimal](9, 5) NOT NULL ,
	[Match_State] [tinyint] NOT NULL ,
	[Predicted_NET] [real] NOT NULL ,
	[Matching_Member_Count] [int] NOT NULL ,
	[Del_Match_Score] [decimal](9, 5) NOT NULL ,
	CONSTRAINT [PK_T_FTICR_UMC_NETLockerDetails] PRIMARY KEY  NONCLUSTERED 
	(
		[UMC_NETLockerDetails_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_FTICR_UMC_NETLockerDetails_T_FPR_State_Name] FOREIGN KEY 
	(
		[Match_State]
	) REFERENCES [T_FPR_State_Name] (
		[Match_State]
	) ON UPDATE CASCADE ,
	CONSTRAINT [FK_T_FTICR_UMC_NETLockerDetails_T_FTICR_UMC_Results] FOREIGN KEY 
	(
		[UMC_Results_ID]
	) REFERENCES [T_FTICR_UMC_Results] (
		[UMC_Results_ID]
	),
	CONSTRAINT [FK_T_FTICR_UMC_NETLockerDetails_T_GANET_Lockers] FOREIGN KEY 
	(
		[Seq_ID]
	) REFERENCES [T_GANET_Lockers] (
		[Seq_ID]
	)
) ON [PRIMARY]
GO

 CREATE  CLUSTERED  INDEX [IX_T_FTICR_UMC_NETLockerDetails] ON [T_FTICR_UMC_NETLockerDetails]([UMC_Results_ID]) WITH  FILLFACTOR = 90 ON [PRIMARY]
GO


