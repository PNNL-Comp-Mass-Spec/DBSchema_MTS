if exists (select * from dbo.sysobjects where id = object_id(N'[T_FTICR_UMC_ResultDetails]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_FTICR_UMC_ResultDetails]
GO

CREATE TABLE [T_FTICR_UMC_ResultDetails] (
	[UMC_ResultDetails_ID] [int] IDENTITY (1, 1) NOT NULL ,
	[UMC_Results_ID] [int] NOT NULL ,
	[Mass_Tag_ID] [int] NOT NULL ,
	[Match_Score] [decimal](9, 5) NOT NULL ,
	[Match_State] [tinyint] NOT NULL CONSTRAINT [DF_T_FTICR_UMC_ResultDetails_Match_State] DEFAULT (1),
	[Expected_NET] [real] NULL ,
	[Mass_Tag_Mods] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_FTICR_UMC_ResultDetails_Mass_Tag_Mods] DEFAULT (''),
	[Mass_Tag_Mod_Mass] [float] NOT NULL CONSTRAINT [DF_T_FTICR_UMC_ResultDetails_Mass_Tag_Mod_Mass] DEFAULT (0),
	[Matching_Member_Count] [int] NOT NULL ,
	[Del_Match_Score] [decimal](9, 5) NOT NULL ,
	CONSTRAINT [PK_T_FTICR_UMC_ResultDetails] PRIMARY KEY  NONCLUSTERED 
	(
		[UMC_ResultDetails_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_FTICR_UMC_ResultDetails_T_FPR_State_Name] FOREIGN KEY 
	(
		[Match_State]
	) REFERENCES [T_FPR_State_Name] (
		[Match_State]
	) ON UPDATE CASCADE ,
	CONSTRAINT [FK_T_FTICR_UMC_ResultDetails_T_FTICR_UMC_Results] FOREIGN KEY 
	(
		[UMC_Results_ID]
	) REFERENCES [T_FTICR_UMC_Results] (
		[UMC_Results_ID]
	),
	CONSTRAINT [FK_T_FTICR_UMC_ResultDetails_T_Mass_Tags] FOREIGN KEY 
	(
		[Mass_Tag_ID]
	) REFERENCES [T_Mass_Tags] (
		[Mass_Tag_ID]
	)
) ON [PRIMARY]
GO

 CREATE  CLUSTERED  INDEX [IX_T_FTICR_UMC_ResultDetails] ON [T_FTICR_UMC_ResultDetails]([UMC_Results_ID]) WITH  FILLFACTOR = 90 ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_FTICR_UMC_ResultDetails_Mass_Tag_ID] ON [T_FTICR_UMC_ResultDetails]([Mass_Tag_ID]) WITH  FILLFACTOR = 90 ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_FTICR_UMC_ResultDetails_MatchState] ON [T_FTICR_UMC_ResultDetails]([Match_State]) ON [PRIMARY]
GO


