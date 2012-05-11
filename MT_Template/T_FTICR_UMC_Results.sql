/****** Object:  Table [dbo].[T_FTICR_UMC_Results] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_FTICR_UMC_Results](
	[UMC_Results_ID] [int] IDENTITY(1,1) NOT NULL,
	[MD_ID] [int] NOT NULL,
	[UMC_Ind] [int] NOT NULL,
	[Member_Count] [int] NOT NULL,
	[Member_Count_Used_For_Abu] [int] NULL,
	[UMC_Score] [float] NOT NULL,
	[Scan_First] [int] NOT NULL,
	[Scan_Last] [int] NOT NULL,
	[Scan_Max_Abundance] [int] NOT NULL,
	[Class_Mass] [float] NOT NULL,
	[Monoisotopic_Mass_Min] [float] NULL,
	[Monoisotopic_Mass_Max] [float] NULL,
	[Monoisotopic_Mass_StDev] [float] NULL,
	[Monoisotopic_Mass_MaxAbu] [float] NULL,
	[Class_Abundance] [float] NOT NULL,
	[Abundance_Min] [float] NULL,
	[Abundance_Max] [float] NULL,
	[Class_Stats_Charge_Basis] [smallint] NULL,
	[Charge_State_Min] [smallint] NULL,
	[Charge_State_Max] [smallint] NULL,
	[Charge_State_MaxAbu] [smallint] NULL,
	[Fit_Average] [real] NOT NULL,
	[Fit_Min] [real] NULL,
	[Fit_Max] [real] NULL,
	[Fit_StDev] [real] NULL,
	[ElutionTime] [real] NULL,
	[Expression_Ratio] [float] NULL,
	[FPR_Type_ID] [int] NOT NULL,
	[MassTag_Hit_Count] [int] NOT NULL,
	[Pair_UMC_Ind] [int] NOT NULL,
	[InternalStd_Hit_Count] [int] NOT NULL,
	[Expression_Ratio_StDev] [float] NULL,
	[Expression_Ratio_Charge_State_Basis_Count] [smallint] NULL,
	[Expression_Ratio_Member_Basis_Count] [int] NULL,
	[Drift_Time] [real] NULL,
	[Drift_Time_Aligned] [real] NULL,
	[Member_Count_Saturated] [int] NULL,
 CONSTRAINT [PK_T_FTICR_UMC_Results] PRIMARY KEY NONCLUSTERED 
(
	[UMC_Results_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_FTICR_UMC_Results] ******/
CREATE CLUSTERED INDEX [IX_T_FTICR_UMC_Results] ON [dbo].[T_FTICR_UMC_Results] 
(
	[MD_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_FTICR_UMC_Results]  WITH CHECK ADD  CONSTRAINT [FK_T_FTICR_UMC_Results_T_FPR_Type_Name] FOREIGN KEY([FPR_Type_ID])
REFERENCES [T_FPR_Type_Name] ([FPR_Type_ID])
GO
ALTER TABLE [dbo].[T_FTICR_UMC_Results] CHECK CONSTRAINT [FK_T_FTICR_UMC_Results_T_FPR_Type_Name]
GO
ALTER TABLE [dbo].[T_FTICR_UMC_Results]  WITH CHECK ADD  CONSTRAINT [FK_T_FTICR_UMC_Results_T_Match_Making_Description] FOREIGN KEY([MD_ID])
REFERENCES [T_Match_Making_Description] ([MD_ID])
GO
ALTER TABLE [dbo].[T_FTICR_UMC_Results] CHECK CONSTRAINT [FK_T_FTICR_UMC_Results_T_Match_Making_Description]
GO
ALTER TABLE [dbo].[T_FTICR_UMC_Results] ADD  CONSTRAINT [DF_T_FTICR_UMC_Results_Member_Count]  DEFAULT ((0)) FOR [Member_Count]
GO
ALTER TABLE [dbo].[T_FTICR_UMC_Results] ADD  CONSTRAINT [DF_T_FTICR_UMC_Results_UMC_Score]  DEFAULT ((0)) FOR [UMC_Score]
GO
ALTER TABLE [dbo].[T_FTICR_UMC_Results] ADD  CONSTRAINT [DF_T_FTICR_UMC_Results_Pair_UMC_Ind]  DEFAULT ((-1)) FOR [Pair_UMC_Ind]
GO
ALTER TABLE [dbo].[T_FTICR_UMC_Results] ADD  CONSTRAINT [DF_T_FTICR_UMC_Results_GANET_Locker_Count]  DEFAULT ((0)) FOR [InternalStd_Hit_Count]
GO
