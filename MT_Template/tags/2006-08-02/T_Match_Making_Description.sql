if exists (select * from dbo.sysobjects where id = object_id(N'[T_Match_Making_Description]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Match_Making_Description]
GO

CREATE TABLE [T_Match_Making_Description] (
	[MD_ID] [int] IDENTITY (1, 1) NOT NULL ,
	[MD_Reference_Job] [int] NOT NULL ,
	[MD_File] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[MD_Type] [int] NOT NULL ,
	[MD_Parameters] [varchar] (2048) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[MD_Date] [datetime] NOT NULL ,
	[MD_State] [tinyint] NOT NULL CONSTRAINT [DF_T_MatchMaking_Description_mmState] DEFAULT (1),
	[MD_Peaks_Count] [int] NULL CONSTRAINT [DF_T_Match_Making_Description_MD_Peaks_Count] DEFAULT (0),
	[MD_Tool_Version] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[MD_Comparison_Mass_Tag_Count] [int] NOT NULL CONSTRAINT [DF_T_Match_Making_Description_MD_Comparison_Mass_Tag_Count] DEFAULT (0),
	[Minimum_High_Normalized_Score] [real] NOT NULL CONSTRAINT [DF_T_Match_Making_Description_Minimum_High_Normalized_Score] DEFAULT (0),
	[Minimum_High_Discriminant_Score] [real] NOT NULL CONSTRAINT [DF_T_Match_Making_Description_Minimum_High_Discriminant_Score] DEFAULT (0),
	[Minimum_PMT_Quality_Score] [real] NOT NULL CONSTRAINT [DF_T_Match_Making_Description_Minimum_PMT_Quality_Score] DEFAULT (0),
	[Experiment_Filter] [varchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_Match_Making_Description_Experiment_Filter] DEFAULT (''),
	[Experiment_Exclusion_Filter] [varchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_Match_Making_Description_Experiment_Exclusion_Filter] DEFAULT (''),
	[Limit_To_PMTs_From_Dataset] [tinyint] NOT NULL CONSTRAINT [DF_T_Match_Making_Description_Limit_To_PMTs_From_Dataset] DEFAULT (0),
	[MD_UMC_TolerancePPM] [numeric](9, 4) NOT NULL CONSTRAINT [DF_T_Match_Making_Description_MD_UMC_TolerancePPM] DEFAULT (0),
	[MD_UMC_Count] [int] NOT NULL CONSTRAINT [DF_T_Match_Making_Description_MD_UMC_Count] DEFAULT (0),
	[MD_NetAdj_TolerancePPM] [numeric](9, 4) NOT NULL CONSTRAINT [DF_T_Match_Making_Description_MD_NetAdj_TolerancePPM] DEFAULT (0),
	[MD_NetAdj_UMCs_HitCount] [int] NOT NULL CONSTRAINT [DF_T_Match_Making_Description_MD_NetAdj_UMCs_HitCount] DEFAULT (0),
	[MD_NetAdj_TopAbuPct] [tinyint] NULL ,
	[MD_NetAdj_IterationCount] [tinyint] NULL ,
	[MD_NetAdj_NET_Min] [numeric](9, 5) NULL ,
	[MD_NetAdj_NET_Max] [numeric](9, 5) NULL ,
	[MD_MMA_TolerancePPM] [numeric](9, 4) NULL ,
	[MD_NET_Tolerance] [numeric](9, 5) NULL ,
	[GANET_Fit] [float] NULL ,
	[GANET_Slope] [float] NULL ,
	[GANET_Intercept] [float] NULL ,
	[Refine_Mass_Cal_PPMShift] [numeric](9, 4) NULL ,
	[Refine_Mass_Cal_PeakHeightCounts] [int] NULL ,
	[Refine_Mass_Cal_PeakWidthPPM] [real] NULL ,
	[Refine_Mass_Cal_PeakCenterPPM] [real] NULL ,
	[Refine_Mass_Tol_Used] [tinyint] NULL ,
	[Refine_NET_Tol_PeakHeightCounts] [int] NULL ,
	[Refine_NET_Tol_PeakWidth] [real] NULL ,
	[Refine_NET_Tol_PeakCenter] [real] NULL ,
	[Refine_NET_Tol_Used] [tinyint] NULL ,
	[Ini_File_Name] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	CONSTRAINT [PK_T_MatchMaking_Description] PRIMARY KEY  CLUSTERED 
	(
		[MD_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_Match_Making_Description_T_FTICR_Analysis_Description] FOREIGN KEY 
	(
		[MD_Reference_Job]
	) REFERENCES [T_FTICR_Analysis_Description] (
		[Job]
	),
	CONSTRAINT [FK_T_Match_Making_Description_T_MMD_State_Name] FOREIGN KEY 
	(
		[MD_State]
	) REFERENCES [T_MMD_State_Name] (
		[MD_State]
	),
	CONSTRAINT [FK_T_Match_Making_Description_T_MMD_Type_Name] FOREIGN KEY 
	(
		[MD_Type]
	) REFERENCES [T_MMD_Type_Name] (
		[MD_Type]
	)
) ON [PRIMARY]
GO


