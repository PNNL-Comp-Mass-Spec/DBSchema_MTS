if exists (select * from dbo.sysobjects where id = object_id(N'[T_FTICR_UMC_Results]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_FTICR_UMC_Results]
GO

CREATE TABLE [T_FTICR_UMC_Results] (
	[UMC_Results_ID] [int] IDENTITY (1, 1) NOT NULL ,
	[MD_ID] [int] NOT NULL ,
	[UMC_Ind] [int] NOT NULL ,
	[Member_Count] [int] NOT NULL CONSTRAINT [DF_T_FTICR_UMC_Results_Member_Count] DEFAULT (0),
	[Member_Count_Used_For_Abu] [int] NULL ,
	[UMC_Score] [float] NOT NULL CONSTRAINT [DF_T_FTICR_UMC_Results_UMC_Score] DEFAULT (0),
	[Scan_First] [int] NOT NULL ,
	[Scan_Last] [int] NOT NULL ,
	[Scan_Max_Abundance] [int] NOT NULL ,
	[Class_Mass] [float] NOT NULL ,
	[Monoisotopic_Mass_Min] [float] NULL ,
	[Monoisotopic_Mass_Max] [float] NULL ,
	[Monoisotopic_Mass_StDev] [float] NULL ,
	[Monoisotopic_Mass_MaxAbu] [float] NULL ,
	[Class_Abundance] [float] NOT NULL ,
	[Abundance_Min] [float] NULL ,
	[Abundance_Max] [float] NULL ,
	[Class_Stats_Charge_Basis] [smallint] NULL ,
	[Charge_State_Min] [smallint] NULL ,
	[Charge_State_Max] [smallint] NULL ,
	[Charge_State_MaxAbu] [smallint] NULL ,
	[Fit_Average] [real] NOT NULL ,
	[Fit_Min] [real] NULL ,
	[Fit_Max] [real] NULL ,
	[Fit_StDev] [real] NULL ,
	[ElutionTime] [real] NULL ,
	[Expression_Ratio] [float] NULL ,
	[FPR_Type_ID] [int] NOT NULL ,
	[MassTag_Hit_Count] [int] NOT NULL ,
	[Pair_UMC_Ind] [int] NOT NULL CONSTRAINT [DF_T_FTICR_UMC_Results_Pair_UMC_Ind] DEFAULT ((-1)),
	[GANET_Locker_Count] [int] NOT NULL CONSTRAINT [DF_T_FTICR_UMC_Results_GANET_Locker_Count] DEFAULT (0),
	[Expression_Ratio_StDev] [float] NULL ,
	[Expression_Ratio_Charge_State_Basis_Count] [smallint] NULL ,
	[Expression_Ratio_Member_Basis_Count] [int] NULL ,
	CONSTRAINT [PK_T_FTICR_UMC_Results] PRIMARY KEY  NONCLUSTERED 
	(
		[UMC_Results_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_FTICR_UMC_Results_T_FPR_Type_Name] FOREIGN KEY 
	(
		[FPR_Type_ID]
	) REFERENCES [T_FPR_Type_Name] (
		[FPR_Type_ID]
	),
	CONSTRAINT [FK_T_FTICR_UMC_Results_T_Match_Making_Description] FOREIGN KEY 
	(
		[MD_ID]
	) REFERENCES [T_Match_Making_Description] (
		[MD_ID]
	)
) ON [PRIMARY]
GO

 CREATE  CLUSTERED  INDEX [IX_T_FTICR_UMC_Results] ON [T_FTICR_UMC_Results]([MD_ID]) WITH  FILLFACTOR = 90 ON [PRIMARY]
GO


