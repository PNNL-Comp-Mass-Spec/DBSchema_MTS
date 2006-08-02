if exists (select * from dbo.sysobjects where id = object_id(N'[T_FTICR_UMC_InternalStdDetails]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_FTICR_UMC_InternalStdDetails]
GO

CREATE TABLE [T_FTICR_UMC_InternalStdDetails] (
	[UMC_InternalStdDetails_ID] [int] IDENTITY (1, 1) NOT NULL ,
	[UMC_Results_ID] [int] NOT NULL ,
	[Seq_ID] [int] NOT NULL ,
	[Match_Score] [decimal](9, 5) NOT NULL ,
	[Match_State] [tinyint] NOT NULL ,
	[Expected_NET] [real] NOT NULL ,
	[Matching_Member_Count] [int] NOT NULL ,
	[Del_Match_Score] [decimal](9, 5) NOT NULL ,
	CONSTRAINT [PK_T_FTICR_UMC_InternalStdDetails] PRIMARY KEY  NONCLUSTERED 
	(
		[UMC_InternalStdDetails_ID]
	)  ON [PRIMARY] ,
	CONSTRAINT [FK_T_FTICR_UMC_InternalStdDetails_T_FPR_State_Name] FOREIGN KEY 
	(
		[Match_State]
	) REFERENCES [T_FPR_State_Name] (
		[Match_State]
	),
	CONSTRAINT [FK_T_FTICR_UMC_InternalStdDetails_T_FTICR_UMC_Results] FOREIGN KEY 
	(
		[UMC_Results_ID]
	) REFERENCES [T_FTICR_UMC_Results] (
		[UMC_Results_ID]
	),
	CONSTRAINT [FK_T_FTICR_UMC_InternalStdDetails_T_Mass_Tags] FOREIGN KEY 
	(
		[Seq_ID]
	) REFERENCES [T_Mass_Tags] (
		[Mass_Tag_ID]
	)
) ON [PRIMARY]
GO

 CREATE  CLUSTERED  INDEX [IX_T_FTICR_UMC_InternalStdDetails] ON [T_FTICR_UMC_InternalStdDetails]([UMC_Results_ID]) ON [PRIMARY]
GO


