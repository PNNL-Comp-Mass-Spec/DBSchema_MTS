/****** Object:  Table [dbo].[T_Quantitation_Results] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Quantitation_Results](
	[QR_ID] [int] IDENTITY(1,1) NOT NULL,
	[Quantitation_ID] [int] NOT NULL,
	[Ref_ID] [int] NOT NULL,
	[MDID_Match_Count] [int] NOT NULL,
	[MassTagCountUniqueObserved] [int] NOT NULL,
	[InternalStdCountUniqueObserved] [int] NOT NULL,
	[MassTagCountUsedForAbundanceAvg] [int] NOT NULL,
	[MassTagMatchingIonCount] [int] NOT NULL,
	[FractionScansMatchingSingleMassTag] [decimal](9, 8) NOT NULL,
	[MT_Count_Unique_Observed_Both_MS_and_MSMS] [int] NOT NULL,
	[Abundance_Average] [float] NOT NULL,
	[Abundance_Minimum] [float] NOT NULL,
	[Abundance_Maximum] [float] NOT NULL,
	[Abundance_StDev] [float] NOT NULL,
	[ER_Average] [float] NOT NULL,
	[ER_Minimum] [float] NOT NULL,
	[ER_Maximum] [float] NOT NULL,
	[ER_StDev] [float] NOT NULL,
	[UMCMultipleMTHitCountAvg] [decimal](9, 5) NOT NULL,
	[UMCMultipleMTHitCountStDev] [float] NOT NULL,
	[UMCMultipleMTHitCountMin] [int] NOT NULL,
	[UMCMultipleMTHitCountMax] [int] NOT NULL,
	[ReplicateCountAvg] [decimal](9, 5) NOT NULL,
	[ReplicateCountStDev] [decimal](9, 5) NOT NULL,
	[ReplicateCountMax] [smallint] NOT NULL,
	[FractionCountAvg] [decimal](9, 5) NOT NULL,
	[FractionCountMax] [smallint] NOT NULL,
	[TopLevelFractionCountAvg] [decimal](9, 5) NOT NULL,
	[TopLevelFractionCountMax] [smallint] NOT NULL,
	[Meets_Minimum_Criteria] [tinyint] NOT NULL,
	[Mass_Error_PPM_Avg] [float] NULL,
	[ORF_Count_Avg] [decimal](9, 5) NULL,
	[Full_Enzyme_Count] [int] NULL,
	[Full_Enzyme_No_Missed_Cleavage_Count] [int] NULL,
	[Partial_Enzyme_Count] [int] NULL,
	[ORF_Coverage_Residue_Count] [int] NULL,
	[ORF_Coverage_Fraction] [decimal](9, 5) NULL,
	[Potential_Full_Enzyme_Count] [int] NULL,
	[Potential_Partial_Enzyme_Count] [int] NULL,
	[Potential_ORF_Coverage_Residue_Count] [int] NULL,
	[Potential_ORF_Coverage_Fraction] [decimal](9, 5) NULL,
	[ORF_Coverage_Fraction_High_Abundance] [decimal](9, 5) NULL,
	[Match_Score_Average] [decimal](9, 5) NOT NULL,
 CONSTRAINT [PK_T_Quantitation_Results] PRIMARY KEY NONCLUSTERED 
(
	[QR_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
GRANT DELETE ON [dbo].[T_Quantitation_Results] TO [DMS_SP_User] AS [dbo]
GO
GRANT INSERT ON [dbo].[T_Quantitation_Results] TO [DMS_SP_User] AS [dbo]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] TO [DMS_SP_User] AS [dbo]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] TO [DMS_SP_User] AS [dbo]
GO
/****** Object:  Index [IX_T_Quantitation_Results] ******/
CREATE CLUSTERED INDEX [IX_T_Quantitation_Results] ON [dbo].[T_Quantitation_Results]
(
	[Quantitation_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_Quantitation_Results] ADD  CONSTRAINT [DF_T_Quantitation_Results_MT_Count_Unique_Observed_Both_MS_and_MSMS]  DEFAULT ((0)) FOR [MT_Count_Unique_Observed_Both_MS_and_MSMS]
GO
ALTER TABLE [dbo].[T_Quantitation_Results]  WITH CHECK ADD  CONSTRAINT [FK_T_Quantitation_Results_T_Proteins] FOREIGN KEY([Ref_ID])
REFERENCES [dbo].[T_Proteins] ([Ref_ID])
GO
ALTER TABLE [dbo].[T_Quantitation_Results] CHECK CONSTRAINT [FK_T_Quantitation_Results_T_Proteins]
GO
ALTER TABLE [dbo].[T_Quantitation_Results]  WITH CHECK ADD  CONSTRAINT [FK_T_Quantitation_Results_T_Quantitation_Description] FOREIGN KEY([Quantitation_ID])
REFERENCES [dbo].[T_Quantitation_Description] ([Quantitation_ID])
GO
ALTER TABLE [dbo].[T_Quantitation_Results] CHECK CONSTRAINT [FK_T_Quantitation_Results_T_Quantitation_Description]
GO
