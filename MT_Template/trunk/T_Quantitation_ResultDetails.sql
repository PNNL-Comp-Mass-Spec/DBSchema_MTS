/****** Object:  Table [dbo].[T_Quantitation_ResultDetails] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Quantitation_ResultDetails](
	[QRD_ID] [int] IDENTITY(1,1) NOT NULL,
	[QR_ID] [int] NOT NULL,
	[Internal_Standard_Match] [tinyint] NOT NULL CONSTRAINT [DF_T_Quantitation_ResultDetails_Internal_Standard_Match]  DEFAULT (0),
	[Mass_Tag_ID] [int] NOT NULL,
	[Mass_Tag_Mods] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_Quantitation_ResultDetails_Mass_Tag_Mods]  DEFAULT (''),
	[MT_Abundance] [float] NOT NULL,
	[MT_Abundance_StDev] [float] NOT NULL,
	[Member_Count_Used_For_Abundance] [decimal](9, 5) NOT NULL,
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
	[MT_Match_Score_Avg] [float] NOT NULL,
	[MT_Del_Match_Score_Avg] [decimal](9, 5) NULL,
	[NET_Error_Obs_Avg] [decimal](9, 5) NULL,
	[NET_Error_Pred_Avg] [decimal](9, 5) NULL,
	[UMC_MatchCount_Avg] [decimal](9, 5) NOT NULL,
	[UMC_MatchCount_StDev] [decimal](9, 5) NOT NULL,
	[SingleMT_MassTagMatchingIonCount] [decimal](9, 5) NOT NULL,
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
 CONSTRAINT [PK_T_Quantitation_ResultDetails] PRIMARY KEY NONCLUSTERED 
(
	[QRD_ID] ASC
)WITH FILLFACTOR = 90 ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Quantitation_ResultDetails] ******/
CREATE CLUSTERED INDEX [IX_T_Quantitation_ResultDetails] ON [dbo].[T_Quantitation_ResultDetails] 
(
	[QR_ID] ASC
)WITH FILLFACTOR = 90 ON [PRIMARY]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] TO [DMS_SP_User]
GO
GRANT INSERT ON [dbo].[T_Quantitation_ResultDetails] TO [DMS_SP_User]
GO
GRANT DELETE ON [dbo].[T_Quantitation_ResultDetails] TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([QRD_ID]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([QRD_ID]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([QR_ID]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([QR_ID]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([Internal_Standard_Match]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([Internal_Standard_Match]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([Mass_Tag_ID]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([Mass_Tag_ID]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([Mass_Tag_Mods]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([Mass_Tag_Mods]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([MT_Abundance]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([MT_Abundance]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([MT_Abundance_StDev]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([MT_Abundance_StDev]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([Member_Count_Used_For_Abundance]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([Member_Count_Used_For_Abundance]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([ER]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([ER]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([ER_StDev]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([ER_StDev]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([ER_Charge_State_Basis_Count]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([ER_Charge_State_Basis_Count]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([Scan_Minimum]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([Scan_Minimum]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([Scan_Maximum]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([Scan_Maximum]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([NET_Minimum]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([NET_Minimum]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([NET_Maximum]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([NET_Maximum]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([Class_Stats_Charge_Basis_Avg]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([Class_Stats_Charge_Basis_Avg]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([Charge_State_Min]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([Charge_State_Min]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([Charge_State_Max]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([Charge_State_Max]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([Mass_Error_PPM_Avg]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([Mass_Error_PPM_Avg]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([MT_Match_Score_Avg]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([MT_Match_Score_Avg]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([MT_Del_Match_Score_Avg]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([MT_Del_Match_Score_Avg]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([NET_Error_Obs_Avg]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([NET_Error_Obs_Avg]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([NET_Error_Pred_Avg]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([NET_Error_Pred_Avg]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([UMC_MatchCount_Avg]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([UMC_MatchCount_Avg]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([UMC_MatchCount_StDev]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([UMC_MatchCount_StDev]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([SingleMT_MassTagMatchingIonCount]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([SingleMT_MassTagMatchingIonCount]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([SingleMT_FractionScansMatchingSingleMT]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([SingleMT_FractionScansMatchingSingleMT]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([UMC_MassTagHitCount_Avg]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([UMC_MassTagHitCount_Avg]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([UMC_MassTagHitCount_Min]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([UMC_MassTagHitCount_Min]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([UMC_MassTagHitCount_Max]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([UMC_MassTagHitCount_Max]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([Used_For_Abundance_Computation]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([Used_For_Abundance_Computation]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([ReplicateCountAvg]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([ReplicateCountAvg]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([ReplicateCountMin]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([ReplicateCountMin]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([ReplicateCountMax]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([ReplicateCountMax]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([FractionCountAvg]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([FractionCountAvg]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([FractionMin]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([FractionMin]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([FractionMax]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([FractionMax]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([TopLevelFractionCount]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([TopLevelFractionCount]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([TopLevelFractionMin]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([TopLevelFractionMin]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([TopLevelFractionMax]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([TopLevelFractionMax]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([ORF_Count]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([ORF_Count]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_ResultDetails] ([PMT_Quality_Score]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_ResultDetails] ([PMT_Quality_Score]) TO [DMS_SP_User]
GO
ALTER TABLE [dbo].[T_Quantitation_ResultDetails]  WITH NOCHECK ADD  CONSTRAINT [FK_T_Quantitation_ResultDetails_T_Mass_Tags] FOREIGN KEY([Mass_Tag_ID])
REFERENCES [T_Mass_Tags] ([Mass_Tag_ID])
GO
ALTER TABLE [dbo].[T_Quantitation_ResultDetails] CHECK CONSTRAINT [FK_T_Quantitation_ResultDetails_T_Mass_Tags]
GO
ALTER TABLE [dbo].[T_Quantitation_ResultDetails]  WITH NOCHECK ADD  CONSTRAINT [FK_T_Quantitation_ResultDetails_T_Quantitation_Results] FOREIGN KEY([QR_ID])
REFERENCES [T_Quantitation_Results] ([QR_ID])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[T_Quantitation_ResultDetails] CHECK CONSTRAINT [FK_T_Quantitation_ResultDetails_T_Quantitation_Results]
GO
