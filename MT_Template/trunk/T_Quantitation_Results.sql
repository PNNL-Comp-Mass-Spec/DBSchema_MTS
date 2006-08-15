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
)WITH FILLFACTOR = 90 ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Quantitation_Results] ******/
CREATE CLUSTERED INDEX [IX_T_Quantitation_Results] ON [dbo].[T_Quantitation_Results] 
(
	[Quantitation_ID] ASC
)WITH FILLFACTOR = 90 ON [PRIMARY]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] TO [DMS_SP_User]
GO
GRANT INSERT ON [dbo].[T_Quantitation_Results] TO [DMS_SP_User]
GO
GRANT DELETE ON [dbo].[T_Quantitation_Results] TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([QR_ID]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([QR_ID]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([Quantitation_ID]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([Quantitation_ID]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([Ref_ID]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([Ref_ID]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([MDID_Match_Count]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([MDID_Match_Count]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([MassTagCountUniqueObserved]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([MassTagCountUniqueObserved]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([InternalStdCountUniqueObserved]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([InternalStdCountUniqueObserved]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([MassTagCountUsedForAbundanceAvg]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([MassTagCountUsedForAbundanceAvg]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([MassTagMatchingIonCount]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([MassTagMatchingIonCount]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([FractionScansMatchingSingleMassTag]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([FractionScansMatchingSingleMassTag]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([Abundance_Average]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([Abundance_Average]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([Abundance_Minimum]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([Abundance_Minimum]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([Abundance_Maximum]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([Abundance_Maximum]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([Abundance_StDev]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([Abundance_StDev]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([ER_Average]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([ER_Average]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([ER_Minimum]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([ER_Minimum]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([ER_Maximum]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([ER_Maximum]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([ER_StDev]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([ER_StDev]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([UMCMultipleMTHitCountAvg]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([UMCMultipleMTHitCountAvg]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([UMCMultipleMTHitCountStDev]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([UMCMultipleMTHitCountStDev]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([UMCMultipleMTHitCountMin]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([UMCMultipleMTHitCountMin]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([UMCMultipleMTHitCountMax]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([UMCMultipleMTHitCountMax]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([ReplicateCountAvg]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([ReplicateCountAvg]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([ReplicateCountStDev]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([ReplicateCountStDev]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([ReplicateCountMax]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([ReplicateCountMax]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([FractionCountAvg]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([FractionCountAvg]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([FractionCountMax]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([FractionCountMax]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([TopLevelFractionCountAvg]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([TopLevelFractionCountAvg]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([TopLevelFractionCountMax]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([TopLevelFractionCountMax]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([Meets_Minimum_Criteria]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([Meets_Minimum_Criteria]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([Mass_Error_PPM_Avg]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([Mass_Error_PPM_Avg]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([ORF_Count_Avg]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([ORF_Count_Avg]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([Full_Enzyme_Count]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([Full_Enzyme_Count]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([Full_Enzyme_No_Missed_Cleavage_Count]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([Full_Enzyme_No_Missed_Cleavage_Count]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([Partial_Enzyme_Count]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([Partial_Enzyme_Count]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([ORF_Coverage_Residue_Count]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([ORF_Coverage_Residue_Count]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([ORF_Coverage_Fraction]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([ORF_Coverage_Fraction]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([Potential_Full_Enzyme_Count]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([Potential_Full_Enzyme_Count]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([Potential_Partial_Enzyme_Count]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([Potential_Partial_Enzyme_Count]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([Potential_ORF_Coverage_Residue_Count]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([Potential_ORF_Coverage_Residue_Count]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([Potential_ORF_Coverage_Fraction]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([Potential_ORF_Coverage_Fraction]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([ORF_Coverage_Fraction_High_Abundance]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([ORF_Coverage_Fraction_High_Abundance]) TO [DMS_SP_User]
GO
GRANT SELECT ON [dbo].[T_Quantitation_Results] ([Match_Score_Average]) TO [DMS_SP_User]
GO
GRANT UPDATE ON [dbo].[T_Quantitation_Results] ([Match_Score_Average]) TO [DMS_SP_User]
GO
ALTER TABLE [dbo].[T_Quantitation_Results]  WITH NOCHECK ADD  CONSTRAINT [FK_T_Quantitation_Results_T_Proteins] FOREIGN KEY([Ref_ID])
REFERENCES [T_Proteins] ([Ref_ID])
GO
ALTER TABLE [dbo].[T_Quantitation_Results] CHECK CONSTRAINT [FK_T_Quantitation_Results_T_Proteins]
GO
ALTER TABLE [dbo].[T_Quantitation_Results]  WITH NOCHECK ADD  CONSTRAINT [FK_T_Quantitation_Results_T_Quantitation_Description] FOREIGN KEY([Quantitation_ID])
REFERENCES [T_Quantitation_Description] ([Quantitation_ID])
GO
ALTER TABLE [dbo].[T_Quantitation_Results] CHECK CONSTRAINT [FK_T_Quantitation_Results_T_Quantitation_Description]
GO
