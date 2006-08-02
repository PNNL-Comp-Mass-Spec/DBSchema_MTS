if exists (select * from dbo.sysobjects where id = object_id(N'[T_Quantitation_ResultDetails]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Quantitation_ResultDetails]
GO

CREATE TABLE [T_Quantitation_ResultDetails] (
	[QRD_ID] [int] IDENTITY (1, 1) NOT NULL ,
	[QR_ID] [int] NOT NULL ,
	[Internal_Standard_Match] [tinyint] NOT NULL CONSTRAINT [DF_T_Quantitation_ResultDetails_Internal_Standard_Match] DEFAULT (0),
	[Mass_Tag_ID] [int] NOT NULL ,
	[Mass_Tag_Mods] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_Quantitation_ResultDetails_Mass_Tag_Mods] DEFAULT (''),
	[MT_Abundance] [float] NOT NULL ,
	[MT_Abundance_StDev] [float] NOT NULL ,
	[Member_Count_Used_For_Abundance] [decimal](9, 5) NOT NULL ,
	[ER] [float] NOT NULL ,
	[ER_StDev] [float] NOT NULL ,
	[ER_Charge_State_Basis_Count] [decimal](9, 5) NOT NULL ,
	[Scan_Minimum] [int] NOT NULL ,
	[Scan_Maximum] [int] NOT NULL ,
	[NET_Minimum] [decimal](9, 6) NOT NULL ,
	[NET_Maximum] [decimal](9, 6) NOT NULL ,
	[Class_Stats_Charge_Basis_Avg] [decimal](9, 5) NOT NULL ,
	[Charge_State_Min] [tinyint] NOT NULL ,
	[Charge_State_Max] [tinyint] NOT NULL ,
	[Mass_Error_PPM_Avg] [float] NOT NULL ,
	[MT_Match_Score_Avg] [float] NOT NULL ,
	[MT_Del_Match_Score_Avg] [decimal](9, 5) NULL ,
	[NET_Error_Obs_Avg] [decimal](9, 5) NULL ,
	[NET_Error_Pred_Avg] [decimal](9, 5) NULL ,
	[UMC_MatchCount_Avg] [decimal](9, 5) NOT NULL ,
	[UMC_MatchCount_StDev] [decimal](9, 5) NOT NULL ,
	[SingleMT_MassTagMatchingIonCount] [decimal](9, 5) NOT NULL ,
	[SingleMT_FractionScansMatchingSingleMT] [decimal](9, 8) NOT NULL ,
	[UMC_MassTagHitCount_Avg] [decimal](9, 5) NOT NULL ,
	[UMC_MassTagHitCount_Min] [int] NOT NULL ,
	[UMC_MassTagHitCount_Max] [int] NOT NULL ,
	[Used_For_Abundance_Computation] [tinyint] NOT NULL ,
	[ReplicateCountAvg] [decimal](9, 5) NOT NULL ,
	[ReplicateCountMin] [smallint] NOT NULL ,
	[ReplicateCountMax] [smallint] NOT NULL ,
	[FractionCountAvg] [decimal](9, 5) NOT NULL ,
	[FractionMin] [smallint] NOT NULL ,
	[FractionMax] [smallint] NOT NULL ,
	[TopLevelFractionCount] [smallint] NOT NULL ,
	[TopLevelFractionMin] [smallint] NOT NULL ,
	[TopLevelFractionMax] [smallint] NOT NULL ,
	[ORF_Count] [smallint] NOT NULL ,
	[PMT_Quality_Score] [decimal](9, 5) NOT NULL ,
	CONSTRAINT [PK_T_Quantitation_ResultDetails] PRIMARY KEY  NONCLUSTERED 
	(
		[QRD_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_Quantitation_ResultDetails_T_Mass_Tags] FOREIGN KEY 
	(
		[Mass_Tag_ID]
	) REFERENCES [T_Mass_Tags] (
		[Mass_Tag_ID]
	),
	CONSTRAINT [FK_T_Quantitation_ResultDetails_T_Quantitation_Results] FOREIGN KEY 
	(
		[QR_ID]
	) REFERENCES [T_Quantitation_Results] (
		[QR_ID]
	) ON DELETE CASCADE 
) ON [PRIMARY]
GO

 CREATE  CLUSTERED  INDEX [IX_T_Quantitation_ResultDetails] ON [T_Quantitation_ResultDetails]([QR_ID]) WITH  FILLFACTOR = 90 ON [PRIMARY]
GO

/****** The index created by the following statement is for internal use only. ******/
/****** It is not a real index but exists as statistics only. ******/
if (@@microsoftversion > 0x07000000 )
EXEC ('CREATE STATISTICS [Statistic_Mass_Tag_Mods] ON [T_Quantitation_ResultDetails] ([Mass_Tag_Mods]) ')
GO

/****** The index created by the following statement is for internal use only. ******/
/****** It is not a real index but exists as statistics only. ******/
if (@@microsoftversion > 0x07000000 )
EXEC ('CREATE STATISTICS [Statistic_Internal_Standard_Match] ON [T_Quantitation_ResultDetails] ([Internal_Standard_Match]) ')
GO

GRANT  SELECT ,  UPDATE ,  INSERT ,  DELETE  ON [dbo].[T_Quantitation_ResultDetails]  TO [DMS_SP_User]
GO


