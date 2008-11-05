/****** Object:  StoredProcedure [dbo].[QuantitationProcessWorkStepH] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.QuantitationProcessWorkStepH
/****************************************************	
**  Desc: 
**
**  Return values: 0 if success, otherwise, error code
**
**  Auth:	mem
**	Date:	09/07/2006
**			05/25/2007 mem - Now populating MT_Count_Unique_Observed_Both_MS_and_MSMS and JobCount_Observed_Both_MS_and_MSMS
**			06/06/2007 mem - Now populating MT_Rank_Match_Score_Avg
**
****************************************************/
(
	@QuantitationID int,
	@message varchar(512)='' output
)
AS
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	-----------------------------------------------------------
	-- Step 14
	--
	-- Append the Protein abundance results to T_Quantitation_Results
	-----------------------------------------------------------
	INSERT INTO T_Quantitation_Results 
		(Quantitation_ID, 
		 Ref_ID, 
		 MDID_Match_Count,
		 MassTagCountUniqueObserved, 
		 InternalStdCountUniqueObserved,
		 MassTagCountUsedForAbundanceAvg,
		 MassTagMatchingIonCount, FractionScansMatchingSingleMassTag,
		 MT_Count_Unique_Observed_Both_MS_and_MSMS,
		 Abundance_Average, Abundance_Minimum, Abundance_Maximum, Abundance_StDev, 
		 Match_Score_Average,
		 ER_Average, ER_Minimum, ER_Maximum, ER_StDev, 
		 Meets_Minimum_Criteria,
		 ReplicateCountAvg, ReplicateCountStDev, ReplicateCountMax,
		 FractionCountAvg, FractionCountMax,
		 TopLevelFractionCountAvg, TopLevelFractionCountMax,
		 UMCMultipleMTHitCountAvg, UMCMultipleMTHitCountStDev,
		 UMCMultipleMTHitCountMin, UMCMultipleMTHitCountMax,
		 Mass_Error_PPM_Avg, ORF_Count_Avg, 
		 Full_Enzyme_Count, Full_Enzyme_No_Missed_Cleavage_Count, Partial_Enzyme_Count,
		 ORF_Coverage_Residue_Count, ORF_Coverage_Fraction, ORF_Coverage_Fraction_High_Abundance,
		 Potential_ORF_Coverage_Residue_Count, Potential_ORF_Coverage_Fraction,
		 Potential_Full_Enzyme_Count, Potential_Partial_Enzyme_Count
		 )
	SELECT	@QuantitationID, 
			Ref_ID,
			CASE WHEN FractionCountMax > ReplicateCountMax
			THEN FractionCountMax
			ELSE ReplicateCountMax
			END,												-- MDID_Match_Count = Larger of FractionCountMax and ReplicateCountMax
			ObservedMassTagCount, 
			ObservedInternalStdCount,
			MassTagCountUsedForAbundanceAvg,
			MassTagMatchingIonCount, FractionScansMatchingSingleMassTag,
			MT_Count_Unique_Observed_Both_MS_and_MSMS,
			Abundance_Average, Abundance_Minimum, Abundance_Maximum, IsNull(Abundance_StDev, 0),
			Match_Score_Avg,
			ER_Average, ER_Minimum, ER_Maximum, IsNull(ER_StDev, 0),
			0,																-- Meets_Minimum_Criteria: Set to 0 for now
			ReplicateCountAvg, ReplicateCountStDev, ReplicateCountMax,
			FractionCountAvg, FractionCountMax,
			TopLevelFractionCountAvg, TopLevelFractionCountMax,
			UMCMultipleMTHitCountAvg, UMCMultipleMTHitCountStDev,
			UMCMultipleMTHitCountMin, UMCMultipleMTHitCountMax,
			Mass_Error_PPM_Avg, Protein_Count_Avg, 
			Full_Enzyme_Count, Full_Enzyme_No_Missed_Cleavage_Count, Partial_Enzyme_Count,
			Protein_Coverage_Residue_Count, Protein_Coverage_Fraction, Protein_Coverage_Fraction_High_Abundance,
			Potential_Protein_Coverage_Residue_Count, Potential_Protein_Coverage_Fraction,
			Potential_Full_Enzyme_Count, Potential_Partial_Enzyme_Count
	FROM	#ProteinAbundanceSummary
	ORDER BY Ref_ID
	--	
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	If @myError <> 0 

	Begin
		Set @message = 'Error while appending results for Quantitation_ID = ' + convert(varchar(19), @QuantitationID) + ' to T_Quantitation_Results'
		Set @myError = 144
		Goto Done
	End


	-----------------------------------------------------------
	-- Step 15
	--
	-- Update the Meets_Minimum_Criteria field in T_Quantitation_Results
	--
	-----------------------------------------------------------
	Exec @myError = QuantitationProcessCheckMinimumCriteria @QuantitationID
	If @myError <> 0
	Begin
		Set @message = 'Error while setting Meets_Minimum_Criteria for Quantitation_ID = ' + convert(varchar(19), @QuantitationID) + ' (call from QuantitationProcessWork to QuantitationProcessCheckMinimumCriteria failed)'
		Set @myError = 145
		Goto Done
	End


	-----------------------------------------------------------
	-- Step 16
	--
	-- Append the list of mass tags observed for each Protein, along
	--   with whether or not the mass tag was used in the
	--   Abundance calculation to T_Quantitation_ResultDetails
	-----------------------------------------------------------
	INSERT INTO T_Quantitation_ResultDetails
		(QR_ID, 
		 Mass_Tag_ID, 
		 Mass_Tag_Mods,
		 MT_Abundance,
		 MT_Abundance_StDev,
		 Member_Count_Used_For_Abundance,
		 ER,
		 ER_StDev,
		 ER_Charge_State_Basis_Count,
		 Scan_Minimum, 
		 Scan_Maximum,
		 NET_Minimum,
		 NET_Maximum,
		 Class_Stats_Charge_Basis_Avg,
		 Charge_State_Min,
		 Charge_State_Max,
		 Mass_Error_PPM_Avg,
		 MT_Rank_Match_Score_Avg,
		 MT_Match_Score_Avg,
		 MT_Del_Match_Score_Avg,
		 NET_Error_Obs_Avg,
		 NET_Error_Pred_Avg,
		 UMC_MatchCount_Avg,
		 UMC_MatchCount_StDev,
		 SingleMT_MassTagMatchingIonCount, 
		 SingleMT_FractionScansMatchingSingleMT, 
	     UMC_MassTagHitCount_Avg, UMC_MassTagHitCount_Min, UMC_MassTagHitCount_Max,
		 Used_For_Abundance_Computation,
		 ReplicateCountAvg, ReplicateCountMin, ReplicateCountMax,
		 FractionCountAvg, FractionMin, FractionMax,
		 TopLevelFractionCount, TopLevelFractionMin, TopLevelFractionMax,
		 ORF_Count, PMT_Quality_Score,
		 JobCount_Observed_Both_MS_and_MSMS,
		 Internal_Standard_Match)
	SELECT	T_Quantitation_Results.QR_ID, 
			D.Mass_Tag_ID, 
			D.Mass_Tag_Mods,
			D.MTAbundanceAvg,
			D.MTAbundanceStDev,
			D.Member_Count_Used_For_Abu_Avg,
			D.ERAvg,
			D.ER_StDev,
			D.ER_Charge_State_Basis_Count_Avg,
			D.ScanMinimum, 
			D.ScanMaximum,
			D.NET_Minimum,
			D.NET_Maximum,
			D.Class_Stats_Charge_Basis_Avg,
			D.Charge_State_Min,
			D.Charge_State_Max,
			D.MassErrorPPMAvg,
			D.Rank_Match_Score_Avg,
			D.Match_Score_Avg,
			D.Del_Match_Score_Avg,
			D.NET_Error_Obs_Avg,
			D.NET_Error_Pred_Avg,
			D.UMCMatchCountAvg, 
			D.UMCMatchCountStDev,
			D.UMCIonCountMatchAvg,						-- SingleMT_MassTagMatchingIonCount
			D.FractionScansMatchingSingleMTAvg,
			D.UMCMultipleMTHitCountAvg,	D.UMCMultipleMTHitCountMin, D.UMCMultipleMTHitCountMax,
			D.Used_For_Abundance_Computation,
			D.ReplicateCountAvg, D.ReplicateCountMin, D.ReplicateCountMax,
			D.FractionCountAvg, D.FractionMin, D.FractionMax,
			D.TopLevelFractionCount, D.TopLevelFractionMin,	D.TopLevelFractionMax,
			D.Protein_Count, D.PMT_Quality_Score,
			D.JobCount_Observed_Both_MS_and_MSMS,
			D.InternalStdMatch
	FROM	#UMCMatchResultsSummary AS D 
			LEFT OUTER JOIN T_Quantitation_Results ON 
			D.Ref_ID = T_Quantitation_Results.Ref_ID
	WHERE	T_Quantitation_Results.Quantitation_ID = @QuantitationID
	ORDER BY T_Quantitation_Results.QR_ID, D.Mass_Tag_ID
	--	
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	If @myError <> 0 
	Begin
		Set @message = 'Error while appending results for Quantitation_ID = ' + convert(varchar(19), @QuantitationID) + ' to T_Quantitation_ResultDetails'
		Set @myError = 146
		Goto Done
	End

	-- Construct a status message
	--
	Set @message = 'Processed ' + convert(varchar(19), @myRowCount) + ' peptides for QuantitationID ' + convert(varchar(19), @QuantitationID)

Done:
	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[QuantitationProcessWorkStepH] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[QuantitationProcessWorkStepH] TO [MTS_DB_Lite]
GO
