/****** Object:  StoredProcedure [dbo].[QuantitationProcessWorkStepF] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.QuantitationProcessWorkStepF
/****************************************************	
**  Desc: 
**
**  Return values: 0 if success, otherwise, error code
**
**  Auth:	mem
**	Date:	09/07/2006
**			05/25/2007 mem - Now populating MT_Count_Unique_Observed_Both_MS_and_MSMS
**
****************************************************/
(
	@QuantitationID int,
	@FractionHighestAbuToUse real,				-- Fraction of highest abundance mass tag for given ORF to use when computing ORF abundance (0.0 to 1.0)

	@MinimumMTHighNormalizedScore real,
	@MinimumMTHighDiscriminantScore real,
 	@MinimumMTPeptideProphetProbability real,
	@MinimumPMTQualityScore real,
	
	@MinimumPotentialPMTQualityScore real output,
	@message varchar(512)='' output
)
AS
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

 	Declare	@MinimumPotentialMTHighNormalizedScore real,
 			@MinimumPotentialMTHighDiscriminantScore real,
 			@MinimumPotentialMTHighPeptideProphetProbability real,
			@MinMTHighNormalizedScoreCompare real,
			@MinMTHighDiscriminantScoreCompare real,
			@MinMTHighPeptideProphetCompare real,
			@MinPMTQualityScoreCompare real
 	 	
	-----------------------------------------------------------
	-- Step 12
	--
	-- Compute the Protein Abundances and other stats for each Protein
	-- We do this using several SQL Update and Insert Into statements
	-----------------------------------------------------------
	--
	-- Step 12a
	--
	-- Populate the MaxClassAbundanceThisRef column in #UMCMatchResultsSummary
	-- This uses a straightforward, but multi-level nested Update query using a 
	-- Where clause to cause it to behave like a correlated query
	-- The innermost Select computes the maximum mass tag abundance
	--   for each Ref, creating the derived table MaxAbuByRefTable
	-- Then, in the Update statement, the MaxClassAbundanceThisRef field is updated
	--   to the maximum MT abundance value for the appropriate Ref, which is chosen
	--   using SELECT TOP 1 ... WHERE MaxAbuByRefTable.Ref_ID = #UMCMatchResultsSummary.Ref_ID
	--
	UPDATE #UMCMatchResultsSummary
	SET #UMCMatchResultsSummary.MaxClassAbundanceThisRef =
		(	SELECT TOP 1 MaxAbuByRef
			FROM (	SELECT Ref_ID, MAX(MTAbundanceAvg) AS MaxAbuByRef
					FROM #UMCMatchResultsSummary
					GROUP BY Ref_ID
				 ) AS MaxAbuByRefTable
			WHERE MaxAbuByRefTable.Ref_ID = #UMCMatchResultsSummary.Ref_ID
		) 
	--
	SELECT @myError = @@error, @myRowCount = @@RowCount
	--
	IF @myError <> 0
	Begin
		Set @message = 'Error while updating the MaxClassAbundanceThisRef column in the UMCMatchResultsSummary temporary table'
		Set @myError = 134
		Goto Done
	End


	-- Step 12b
	--
	-- Prior to computing the abundance stats for each Protein, we need to determine
	--   which mass tags will actually be used to compute the Protein abundance
	-- Note that @FractionHighestAbuToUse is a float between 0.0 and 1.0
	--
	UPDATE #UMCMatchResultsSummary
	SET #UMCMatchResultsSummary.Used_For_Abundance_Computation =
			Convert(tinyint, CASE WHEN MTAbundanceAvg >= @FractionHighestAbuToUse * MaxClassAbundanceThisRef
							 THEN 1 
							 ELSE 0 
							 END)


	-- Step 12c
	--
	-- Populate some of the columns in #ProteinAbundanceSummary

	INSERT INTO #ProteinAbundanceSummary
		(Ref_ID, ReplicateCountAvg, 
		 ReplicateCountStDev, ReplicateCountMax,
		 FractionCountAvg, FractionCountMax,
		 TopLevelFractionCountAvg, TopLevelFractionCountMax,
		 ObservedMassTagCount, 
		 ObservedInternalStdCount,
		 Mass_Error_PPM_Avg,
		 Protein_Count_Avg, 
		 Full_Enzyme_Count,
		 Full_Enzyme_No_Missed_Cleavage_Count,
		 Partial_Enzyme_Count,
		 MassTagCountUsedForAbundanceAvg,
		 MassTagMatchingIonCount,
		 MassTagMatchingIonCountInUMCsWithSingleHitCount,
		 FractionScansMatchingSingleMassTag,
		 MT_Count_Unique_Observed_Both_MS_and_MSMS,
		 UMCMultipleMTHitCountAvg,
		 UMCMultipleMTHitCountStDev,
		 UMCMultipleMTHitCountMin,
		 UMCMultipleMTHitCountMax,
		 Abundance_Average,
		 Abundance_Minimum,
		 Abundance_Maximum,
		 Abundance_StDev,
		 Match_Score_Avg,
		 ER_Average,
		 ER_Minimum,
		 ER_Maximum,
		 ER_StDev
		)
	SELECT	Ref_ID,
			AVG(ReplicateCountAvg),
			IsNull(StDev(ReplicateCountAvg),0),
			MAX(ReplicateCountAvg),
			AVG(FractionCountAvg),
			MAX(FractionMax - FractionMin + 1),
			AVG(CONVERT(real, TopLevelFractionCount)),
			MAX(TopLevelFractionMax - TopLevelFractionMin + 1),
			SUM(CASE WHEN InternalStdMatch = 0 THEN 1 ELSE 0 END),				-- ObservedMassTagCount
			SUM(CASE WHEN InternalStdMatch = 1 THEN 1 ELSE 0 END),				-- ObservedInternalStdCount
			AVG(MassErrorPPMAvg),
			AVG(CONVERT(float, Protein_Count)),
			SUM(CASE WHEN Cleavage_State = 2 THEN 1 ELSE 0 END),							-- Full enzyme (fully tryptic) count; null values result in a 0
			SUM(CASE WHEN Fragment_Span = 1 AND Cleavage_State = 2 THEN 1 ELSE 0 END),		-- Full enzyme no missed cleavage count
			SUM(CASE WHEN Cleavage_State = 1 THEN 1 ELSE 0 END),							-- Partial enzyme (partially tryptic) count
			0 AS MassTagCountUsedForAbundanceAvg,
			SUM(UMCIonCountMatchAvg),							-- MassTagMatchingIonCount: Sum of all Matching_Member_Count values for all UMC's for all Mass Tags for this Protein
			SUM(UMCIonCountMatchInUMCsWithSingleHitAvg),		-- MassTagMatchingIonCountInUMCsWithSingleHitCount: Sum of all Match Score values for all UMC's for this Protein wherein the UMC matched a single Mass Tag
			0 AS FractionScansMatchingSingleMassTag,
			SUM(CASE WHEN JobCount_Observed_Both_MS_and_MSMS > 0 THEN 1 ELSE 0 END),		--  MT_Count_Unique_Observed_Both_MS_and_MSMS
			AVG(UMCMultipleMTHitCountAvg),
			IsNull(StDev(UMCMultipleMTHitCountAvg), 0),
			MIN(UMCMultipleMTHitCountMin),
			MAX(UMCMultipleMTHitCountMin),
			0,	-- Abundance_Average
			0,	-- Abundance_Minimum
			0,	-- Abundance_Maximum
			0,	-- Abundance_StDev
			0,	-- Match_Score_Avg
			0,	-- ER_Average
			0,	-- ER_Minimum
			0,	-- ER_Maximum
			0	-- ER_StDev
	FROM #UMCMatchResultsSummary
	GROUP BY Ref_ID 
	ORDER BY Ref_ID
	--
	SELECT @myError = @@error, @myRowCount = @@RowCount
	--
	If @myError <> 0 
	Begin
		Set @message = 'Error while creating the ProteinAbundanceSummary temporary table'
		Set @myError = 135
		Goto Done
	End

	-- Step 12d
	--
	-- Determine the percent of UMCs that matched just one mass tag (i.e. percent that had a unique match)
	-- This calculation is identical to what was done in Step 6, but here we're computing
	--  a single value for each Protein, using the UMCIonCountMatchAvg and UMCIonCountMatchInUMCsWithSingleHitAvg
	-- values for each mass tag

	--
	-- Compute the fraction of scans matching a single mass tag for each mass tag
	--	
	UPDATE #ProteinAbundanceSummary
	SET FractionScansMatchingSingleMassTag = 
		Convert(float, IsNull(MassTagMatchingIonCountInUMCsWithSingleHitCount, 0)) / 
		Convert(float, MassTagMatchingIonCount)
	WHERE MassTagMatchingIonCount > 0

	-- Step 12e
	--
	-- Compute the abundance stats for each Protein
	-- We only use those mass tags whose abundances are at least 
	-- @FractionHighestAbuToUse of the maximum summed MT abundance for the given Protein
	-- Those mass tags have Used_For_Abundance_Computation = 1 in #UMCMatchResultsSummary
	--   and are thus easy to select
	-- We're computing a weighted average ER average and average ER_StDev
	--
	UPDATE	#ProteinAbundanceSummary
	SET		Abundance_Average	= S.Abundance_Average,
			Abundance_StDev		= S.Abundance_StDev,
			Abundance_Minimum	= S.Abundance_Minimum,
			Abundance_Maximum	= S.Abundance_Maximum,
			Match_Score_Avg		= S.Match_Score_Avg,
			ER_Average		= S.ER_Average,
			ER_StDev		= S.ER_StDev,
			ER_Minimum		= S.ER_Minimum,
			ER_Maximum		= S.ER_Maximum,						
			MassTagCountUsedForAbundanceAvg = S.MassTagCountUsedForAbundanceAvg
	FROM (	SELECT	Ref_ID					AS Ref_ID, 
					AVG(MTAbundanceAvg)		AS Abundance_Average, 
					StDev(MTAbundanceAvg)	AS Abundance_StDev, 
--					CASE WHEN @ReplicateCountEstimate = 1
--					THEN StDev(MTAbundanceAvg)	AS Abundance_StDev, 
--						-- Compute the standard deviation of the Average of an Average by finding the
--						-- sum of the squares of the MTAbundanceStDev values, then taking the
--						--  square root of the result
--						-- This doesn't seem to be working, so the above statement must be incorrect
--					ELSE SQRT(SUM(SQUARE(IsNull(MTAbundanceStDev, 0))))
--					END							AS Abundance_StDev, 
					MIN(MTAbundanceAvg)		AS Abundance_Minimum, 
					MAX(MTAbundanceAvg)		AS Abundance_Maximum, 
					
					AVG(Match_Score_Avg)	AS Match_Score_Avg,
					
					CASE WHEN SUM(MTAbundanceLightPlusHeavyAvg) > 0
					THEN SUM(ERAvg * MTAbundanceLightPlusHeavyAvg) / SUM(MTAbundanceLightPlusHeavyAvg)
					ELSE 0
					END AS ER_Average,
					-- Old: AVG(ERAvg)			AS ER_Average

					CASE WHEN SUM(MTAbundanceLightPlusHeavyAvg) > 0
					THEN SQRT(SUM(SQUARE(ER_StDev) * MTAbundanceLightPlusHeavyAvg) / SUM(MTAbundanceLightPlusHeavyAvg))
					ELSE 0
					END AS ER_StDev,			-- ER_StDev; weighted average

					MIN(ERAvg)			AS ER_Minimum, 
					MAX(ERAvg)			AS ER_Maximum, 
					COUNT(MTAbundanceAvg)	AS MassTagCountUsedForAbundanceAvg
			FROM #UMCMatchResultsSummary
			WHERE Used_For_Abundance_Computation = 1
			GROUP BY Ref_ID
		  ) AS S
	WHERE #ProteinAbundanceSummary.Ref_ID = S.Ref_ID
	--
	SELECT @myError = @@error, @myRowCount = @@RowCount
	--
	If @myError <> 0 
	Begin
		Set @message = 'Error while computing the abundances in the ProteinAbundanceSummary temporary table'
		Set @myError = 136
		Goto Done
	End

	-- Step 12f
	--
	-- Populate the Potential Enzyme count columns
	--
	-- First determine the minimum potential MT High Normalized Score, MT High Discriminant Score, 
	--  MT High Peptide Prophet Probability, and PMT Quality Score
	Set @MinimumPotentialMTHighNormalizedScore = @MinimumMTHighNormalizedScore
	Set @MinimumPotentialMTHighDiscriminantScore = @MinimumMTHighDiscriminantScore
	Set @MinimumPotentialMTHighPeptideProphetProbability = @MinimumMTPeptideProphetProbability
	Set @MinimumPotentialPMTQualityScore = @MinimumPMTQualityScore
	
	-- Find the smallest values used for the MDID's for this Quantitation ID

	Set @MinMTHighNormalizedScoreCompare = @MinimumMTHighNormalizedScore
	Set @MinMTHighDiscriminantScoreCompare = @MinimumMTHighDiscriminantScore
	Set @MinMTHighPeptideProphetCompare = @MinimumMTPeptideProphetProbability
	Set @MinPMTQualityScoreCompare = @MinimumPMTQualityScore
	
	SELECT @MinMTHighNormalizedScoreCompare = Min(IsNull(MMD.Minimum_High_Normalized_Score, @MinimumMTHighNormalizedScore)),
		   @MinMTHighDiscriminantScoreCompare = Min(IsNull(MMD.Minimum_High_Discriminant_Score, @MinimumMTHighDiscriminantScore)),
		   @MinMTHighPeptideProphetCompare = Min(IsNull(MMD.Minimum_Peptide_Prophet_Probability, @MinimumMTPeptideProphetProbability)),
		   @MinPMTQualityScoreCompare = Min(IsNull(MMD.Minimum_PMT_Quality_Score, @MinimumPMTQualityScore))
	FROM T_Quantitation_MDIDs AS TMDID INNER JOIN
		 T_Match_Making_Description AS MMD On TMDID.MD_ID = MMD.MD_ID
	WHERE TMDID.Quantitation_ID = @QuantitationID

	If @MinMTHighNormalizedScoreCompare > @MinimumPotentialMTHighNormalizedScore
		Set @MinimumPotentialMTHighNormalizedScore = @MinMTHighNormalizedScoreCompare
	If @MinMTHighDiscriminantScoreCompare > @MinimumPotentialMTHighDiscriminantScore
		Set @MinimumPotentialMTHighDiscriminantScore = @MinMTHighDiscriminantScoreCompare
	If @MinMTHighPeptideProphetCompare > @MinimumPotentialMTHighPeptideProphetProbability
		Set @MinimumPotentialMTHighPeptideProphetProbability = @MinMTHighPeptideProphetCompare
	If @MinPMTQualityScoreCompare > @MinimumPotentialPMTQualityScore
		Set @MinimumPotentialPMTQualityScore = @MinPMTQualityScoreCompare
	
	UPDATE	#ProteinAbundanceSummary
	SET		Potential_Full_Enzyme_Count	= S.Potential_Full_Enzyme_Count,
			Potential_Partial_Enzyme_Count = S.Potential_Partial_Enzyme_Count
	FROM (	SELECT	Ref_ID,
					SUM(CASE WHEN Cleavage_State = 2 THEN 1 ELSE 0 END) AS Potential_Full_Enzyme_Count,		-- Full enzyme (fully tryptic) count; null values result in a 0
					SUM(CASE WHEN Cleavage_State = 1 THEN 1 ELSE 0 END)	AS Potential_Partial_Enzyme_Count	-- Partial enzyme (partially tryptic) count
			FROM	T_Mass_Tag_to_Protein_Map AS MTPM INNER JOIN
					T_Mass_Tags AS MT ON MTPM.Mass_Tag_ID = MT.Mass_Tag_ID
			WHERE	IsNull(MT.High_Normalized_Score,0) >= @MinimumPotentialMTHighNormalizedScore AND 
					IsNull(MT.High_Discriminant_Score,0) >= @MinimumPotentialMTHighDiscriminantScore AND
					IsNull(MT.High_Peptide_Prophet_Probability,0) >= @MinimumPotentialMTHighPeptideProphetProbability AND
					IsNull(MT.PMT_Quality_Score,0) >= @MinimumPotentialPMTQualityScore
			GROUP BY Ref_ID
		 ) AS S
	WHERE #ProteinAbundanceSummary.Ref_ID = S.Ref_ID
	--
	SELECT @myError = @@error, @myRowCount = @@RowCount
	--
	If @myError <> 0 
	Begin
		Set @message = 'Error while computing the partial enzyme count values for #ProteinAbundanceSummary'
		Set @myError = 137
		Goto Done
	End

Done:
	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[QuantitationProcessWorkStepF] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[QuantitationProcessWorkStepF] TO [MTS_DB_Lite]
GO
