/****** Object:  Table [dbo].[T_Quantitation_ResultDetails] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Quantitation_ResultDetails](
	[QRD_ID] [int] IDENTITY(1,1) NOT NULL,
	[QR_ID] [int] NOT NULL,
	[Internal_Standard_Match] [tinyint] NOT NULL,
	[Mass_Tag_ID] [int] NOT NULL,
	[Mass_Tag_Mods] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[MT_Abundance] [float] NOT NULL,
	[MT_Abundance_StDev] [float] NOT NULL,
	[Member_Count_Used_For_Abundance] [real] NOT NULL,
	[ER] [float] NOT NULL,
	[ER_StDev] [float] NOT NULL,
	[ER_Charge_State_Basis_Count] [decimal](9, 5) NOT NULL,
	[Scan_Minimum] [int] NOT NULL,
	[Scan_Maximum] [int] NOT NULL,
	[NET_Minimum] [decimal](9, 6) NOT NULL,
	[NET_Maximum] [decimal](9, 6) NOT NULL,
	[Class_Stats_Charge_Basis_Avg] [decimal](9, 5) NOT NULL,
	[Charge_State_Min] [tinyint] NOT NULL,
	[Charge_State_Max] [tinyint] NOT NULL,
	[Mass_Error_PPM_Avg] [float] NOT NULL,
	[MT_Rank_Match_Score_Avg] [real] NULL,
	[MT_Match_Score_Avg] [float] NOT NULL,
	[MT_Del_Match_Score_Avg] [decimal](9, 5) NULL,
	[NET_Error_Obs_Avg] [decimal](9, 5) NULL,
	[NET_Error_Pred_Avg] [decimal](9, 5) NULL,
	[UMC_MatchCount_Avg] [decimal](9, 5) NOT NULL,
	[UMC_MatchCount_StDev] [decimal](9, 5) NOT NULL,
	[SingleMT_MassTagMatchingIonCount] [real] NOT NULL,
	[SingleMT_FractionScansMatchingSingleMT] [decimal](9, 8) NOT NULL,
	[UMC_MassTagHitCount_Avg] [decimal](9, 5) NOT NULL,
	[UMC_MassTagHitCount_Min] [int] NOT NULL,
	[UMC_MassTagHitCount_Max] [int] NOT NULL,
	[Used_For_Abundance_Computation] [tinyint] NOT NULL,
	[ReplicateCountAvg] [decimal](9, 5) NOT NULL,
	[ReplicateCountMin] [smallint] NOT NULL,
	[ReplicateCountMax] [smallint] NOT NULL,
	[FractionCountAvg] [decimal](9, 5) NOT NULL,
	[FractionMin] [smallint] NOT NULL,
	[FractionMax] [smallint] NOT NULL,
	[TopLevelFractionCount] [smallint] NOT NULL,
	[TopLevelFractionMin] [smallint] NOT NULL,
	[TopLevelFractionMax] [smallint] NOT NULL,
	[ORF_Count] [smallint] NOT NULL,
	[PMT_Quality_Score] [decimal](9, 5) NOT NULL,
	[JobCount_Observed_Both_MS_and_MSMS] [smallint] NOT NULL,
	[MT_Uniqueness_Probability_Avg] [real] NULL,
	[MT_FDR_Threshold_Avg] [real] NULL,
 CONSTRAINT [PK_T_Quantitation_ResultDetails] PRIMARY KEY NONCLUSTERED 
(
	[QRD_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
GRANT DELETE ON [dbo].[T_Quantitation_ResultDetails] TO [DMS_SP_User] AS [dbo]
GO
GRANT INSERT ON [dbo].[T_Quantitation_ResultDetails] TO [DMS_SP_User] AS [dbo]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] TO [DMS_SP_User] AS [dbo]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] TO [DMS_SP_User] AS [dbo]
GO
/****** Object:  Index [IX_T_Quantitation_ResultDetails] ******/
CREATE CLUSTERED INDEX [IX_T_Quantitation_ResultDetails] ON [dbo].[T_Quantitation_ResultDetails]
(
	[QR_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_Quantitation_ResultDetails] ADD  CONSTRAINT [DF_T_Quantitation_ResultDetails_Internal_Standard_Match]  DEFAULT ((0)) FOR [Internal_Standard_Match]
GO
ALTER TABLE [dbo].[T_Quantitation_ResultDetails] ADD  CONSTRAINT [DF_T_Quantitation_ResultDetails_Mass_Tag_Mods]  DEFAULT ('') FOR [Mass_Tag_Mods]
GO
ALTER TABLE [dbo].[T_Quantitation_ResultDetails] ADD  CONSTRAINT [DF_T_Quantitation_ResultDetails_Observed_Both_MS_and_MSMS]  DEFAULT ((0)) FOR [JobCount_Observed_Both_MS_and_MSMS]
GO
ALTER TABLE [dbo].[T_Quantitation_ResultDetails]  WITH CHECK ADD  CONSTRAINT [FK_T_Quantitation_ResultDetails_T_Mass_Tags] FOREIGN KEY([Mass_Tag_ID])
REFERENCES [dbo].[T_Mass_Tags] ([Mass_Tag_ID])
GO
ALTER TABLE [dbo].[T_Quantitation_ResultDetails] CHECK CONSTRAINT [FK_T_Quantitation_ResultDetails_T_Mass_Tags]
GO
ALTER TABLE [dbo].[T_Quantitation_ResultDetails]  WITH CHECK ADD  CONSTRAINT [FK_T_Quantitation_ResultDetails_T_Quantitation_Results] FOREIGN KEY([QR_ID])
REFERENCES [dbo].[T_Quantitation_Results] ([QR_ID])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[T_Quantitation_ResultDetails] CHECK CONSTRAINT [FK_T_Quantitation_ResultDetails_T_Quantitation_Results]
GO
