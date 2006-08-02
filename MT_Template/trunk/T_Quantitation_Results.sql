if exists (select * from dbo.sysobjects where id = object_id(N'[T_Quantitation_Results]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Quantitation_Results]
GO

CREATE TABLE [T_Quantitation_Results] (
	[QR_ID] [int] IDENTITY (1, 1) NOT NULL ,
	[Quantitation_ID] [int] NOT NULL ,
	[Ref_ID] [int] NOT NULL ,
	[MDID_Match_Count] [int] NOT NULL ,
	[MassTagCountUniqueObserved] [int] NOT NULL ,
	[InternalStdCountUniqueObserved] [int] NOT NULL ,
	[MassTagCountUsedForAbundanceAvg] [int] NOT NULL ,
	[MassTagMatchingIonCount] [int] NOT NULL ,
	[FractionScansMatchingSingleMassTag] [decimal](9, 8) NOT NULL ,
	[Abundance_Average] [float] NOT NULL ,
	[Abundance_Minimum] [float] NOT NULL ,
	[Abundance_Maximum] [float] NOT NULL ,
	[Abundance_StDev] [float] NOT NULL ,
	[ER_Average] [float] NOT NULL ,
	[ER_Minimum] [float] NOT NULL ,
	[ER_Maximum] [float] NOT NULL ,
	[ER_StDev] [float] NOT NULL ,
	[UMCMultipleMTHitCountAvg] [decimal](9, 5) NOT NULL ,
	[UMCMultipleMTHitCountStDev] [float] NOT NULL ,
	[UMCMultipleMTHitCountMin] [int] NOT NULL ,
	[UMCMultipleMTHitCountMax] [int] NOT NULL ,
	[ReplicateCountAvg] [decimal](9, 5) NOT NULL ,
	[ReplicateCountStDev] [decimal](9, 5) NOT NULL ,
	[ReplicateCountMax] [smallint] NOT NULL ,
	[FractionCountAvg] [decimal](9, 5) NOT NULL ,
	[FractionCountMax] [smallint] NOT NULL ,
	[TopLevelFractionCountAvg] [decimal](9, 5) NOT NULL ,
	[TopLevelFractionCountMax] [smallint] NOT NULL ,
	[Meets_Minimum_Criteria] [tinyint] NOT NULL ,
	[Mass_Error_PPM_Avg] [float] NULL ,
	[ORF_Count_Avg] [decimal](9, 5) NULL ,
	[Full_Enzyme_Count] [int] NULL ,
	[Full_Enzyme_No_Missed_Cleavage_Count] [int] NULL ,
	[Partial_Enzyme_Count] [int] NULL ,
	[ORF_Coverage_Residue_Count] [int] NULL ,
	[ORF_Coverage_Fraction] [decimal](9, 5) NULL ,
	[Potential_Full_Enzyme_Count] [int] NULL ,
	[Potential_Partial_Enzyme_Count] [int] NULL ,
	[Potential_ORF_Coverage_Residue_Count] [int] NULL ,
	[Potential_ORF_Coverage_Fraction] [decimal](9, 5) NULL ,
	[ORF_Coverage_Fraction_High_Abundance] [decimal](9, 5) NULL ,
	[Match_Score_Average] [decimal](9, 5) NOT NULL ,
	CONSTRAINT [PK_T_Quantitation_Results] PRIMARY KEY  NONCLUSTERED 
	(
		[QR_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_Quantitation_Results_T_Proteins] FOREIGN KEY 
	(
		[Ref_ID]
	) REFERENCES [T_Proteins] (
		[Ref_ID]
	),
	CONSTRAINT [FK_T_Quantitation_Results_T_Quantitation_Description] FOREIGN KEY 
	(
		[Quantitation_ID]
	) REFERENCES [T_Quantitation_Description] (
		[Quantitation_ID]
	)
) ON [PRIMARY]
GO

 CREATE  CLUSTERED  INDEX [IX_T_Quantitation_Results] ON [T_Quantitation_Results]([Quantitation_ID]) WITH  FILLFACTOR = 90 ON [PRIMARY]
GO

GRANT  SELECT ,  UPDATE ,  INSERT ,  DELETE  ON [dbo].[T_Quantitation_Results]  TO [DMS_SP_User]
GO


