/****** Object:  StoredProcedure [dbo].[QuantitationProcessWorkStepD] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.QuantitationProcessWorkStepD
/****************************************************	
**  Desc: 
**
**  Return values: 0 if success, otherwise, error code
**
**  Auth:	mem
**	Date:	09/07/2006
**
****************************************************/
(
	@QuantitationID int,
	@RemoveOutlierAbundancesForReplicates tinyint,
	@FractionCrossReplicateAvgInRange real,
	@AddBackExcludedMassTags tinyint,
	@message varchar(512)='' output
)
AS
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @MTMatchingUMCsCount int,				-- The number of Mass Tags in UMCMatchResultsByJob with UseValue = 1  (after outlier filtering)
			@MTMatchingUMCsCountFilteredOut int,	-- The number of Mass Tags in UMCMatchResultsByJob with UseValue = 0  (after outlier filtering)
			@UniqueMassTagCount int,				-- The number of Mass Tags in UMCMatchResultsByJob with at least one MT in 1 replicate with UseValue = 1
			@UniqueMassTagCountFilteredOut int,		-- The number of Mass Tags in UMCMatchResultsByJob with no MT's in any replicate with UseValue = 1
			@UniqueInternalStdCount int,					-- The number of Internal Std peptides in UMCMatchResultsByJob with at least one MT in 1 replicate with UseValue = 1
			@UniqueInternalStdCountFilteredOut int		-- The number of Internal Std peptides in UMCMatchResultsByJob with no MT's in any replicate with UseValue = 1

	Set @MTMatchingUMCsCount = 0
	Set @MTMatchingUMCsCountFilteredOut = 0
	Set @UniqueMassTagCount = 0
	Set @UniqueMassTagCountFilteredOut = 0
	Set @UniqueInternalStdCount = 0
	Set @UniqueInternalStdCountFilteredOut = 0

	declare @ReplicateCountEstimate int
	set @ReplicateCountEstimate = 0

	-----------------------------------------------------------
	-- Count the maximum number of replicates
	-----------------------------------------------------------
	
	SELECT	@ReplicateCountEstimate = Count (Distinct [Replicate])
	FROM	T_Quantitation_MDIDs
	WHERE	Quantitation_ID = @QuantitationID


	-----------------------------------------------------------
	-- Step 7
	--
	-- Optionally, filter out the outliers
	-- This can only be done with replicate data
	-- We first compute the average abundance for each peptide across replicates, 
	--  storing in #UMCMatchResultsByJob.AverageAbundanceAcrossReps
	-- We also compute the median abundance for each peptide across replicates,
	--  storing in #UMCMatchResultsByJob.MedianAbundanceAcrossReps
	-- Now, we set UseValue = 0 for those those peptides whose abundance is more than
	--  @FractionCrossReplicateAvgInRange away from the cross-replicate average
	-- Finally, we change UseValue back to 1 for those peptides is less than
	--  @FractionCrossReplicateAvgInRange away from the cross-replicate median
	-----------------------------------------------------------

	If @RemoveOutlierAbundancesForReplicates <> 0 AND @ReplicateCountEstimate > 1
	Begin -- <a>
		-- Compute AverageAbundanceAcrossReps in #UMCMatchResultsByJob
		UPDATE #UMCMatchResultsByJob
		SET AverageAbundanceAcrossReps =
				(	SELECT	AVG(MTAbundance)
				FROM	#UMCMatchResultsByJob AS InnerQ
				WHERE	InnerQ.TopLevelFraction = #UMCMatchResultsByJob.TopLevelFraction AND 
						InnerQ.Fraction = #UMCMatchResultsByJob.Fraction AND
						InnerQ.Mass_Tag_ID = #UMCMatchResultsByJob.Mass_Tag_ID)
		--
		SELECT @myError = @@error, @myRowCount = @@RowCount
		--
		IF @myError <> 0
		Begin
			Set @message = 'Error while computing the average abundance across replicates in the #UMCMatchResultsByJob temporary table'
			Set @myError = 129
			Goto Done
		End

		-- Compute MedianAbundanceAcrossReps in #UMCMatchResultsByJob
		-- Computing a median in SQL is not an easy task
		-- Computing a "financial median" wherein the median is the average of the two middle values
		--   for a list with an even number of items is even more difficult
		-- The median-computing code is from "The Guru's Guide to Transact SQL" by Ken Anderson, page 184
		UPDATE #UMCMatchResultsByJob
		SET MedianAbundanceAcrossReps =
				( SELECT IsNull((CASE WHEN COUNT(CASE WHEN I.MTAbundance <= D.MTAbundance 
													THEN 1 
													ELSE NULL 
													END) > (COUNT(*)+1)/2
									THEN 1.0 * D.MTAbundance
									ELSE NULL 
									END)
								+ COUNT(*)%2,
								(D.MTAbundance + MIN((CASE WHEN I.MTAbundance > D.MTAbundance THEN I.MTAbundance ELSE NULL END))) / 2.0
								)

				FROM (	SELECT	MTAbundance
						FROM	#UMCMatchResultsByJob AS InnerQ
						WHERE	InnerQ.TopLevelFraction = #UMCMatchResultsByJob.TopLevelFraction AND 
								InnerQ.Fraction = #UMCMatchResultsByJob.Fraction AND
								InnerQ.Mass_Tag_ID = #UMCMatchResultsByJob.Mass_Tag_ID
						) AS D
						CROSS JOIN
						(	SELECT	MTAbundance
						FROM	#UMCMatchResultsByJob AS InnerQ
						WHERE	InnerQ.TopLevelFraction = #UMCMatchResultsByJob.TopLevelFraction AND 
								InnerQ.Fraction = #UMCMatchResultsByJob.Fraction AND
								InnerQ.Mass_Tag_ID = #UMCMatchResultsByJob.Mass_Tag_ID
						) AS I
				GROUP BY D.MTAbundance
				HAVING (COUNT(CASE WHEN I.MTAbundance <= D.MTAbundance THEN 1 ELSE NULL END) >= (COUNT(*)+1)/2)
					AND (COUNT(CASE WHEN I.MTAbundance >= D.MTAbundance THEN 1 ELSE NULL END) >= COUNT(*)/2 + 1)
				)
		--
		SELECT @myError = @@error, @myRowCount = @@RowCount
		--
		IF @myError <> 0
		Begin
			Set @message = 'Error while computing the average abundance across replicates in the #UMCMatchResultsByJob temporary table'
			Set @myError = 130
			Goto Done
		End

		-- For rows with Abundances in range, set UseValue = 1, otherwise, set UseValue = 0
		-- Test against AverageAbundanceAcrossReps
		UPDATE #UMCMatchResultsByJob
		SET UseValue =  CASE WHEN ABS(AverageAbundanceAcrossReps - MTAbundance) <= AverageAbundanceAcrossReps * @FractionCrossReplicateAvgInRange
						THEN 1
						ELSE 0
						END

		-- For rows with Abundances in range, set UseValue = 1
		-- Test against MedianAbundanceAcrossReps
		UPDATE #UMCMatchResultsByJob
		SET UseValue =  CASE WHEN ABS(MedianAbundanceAcrossReps - MTAbundance) <= MedianAbundanceAcrossReps * @FractionCrossReplicateAvgInRange
						THEN 1
						ELSE UseValue
						END

		If @AddBackExcludedMassTags <> 0
		Begin -- <b>
			-- If any fully excluded mass tags exist (grouping by TopLevelFraction
			--   and by Fraction), then update the UMC's matching those mass tags 
			--   to have UseValue = 1
			
			UPDATE #UMCMatchResultsByJob
			SET UseValue = 1
			WHERE (	UniqueID IN
						(	SELECT OuterQ.UniqueID
						FROM #UMCMatchResultsByJob OuterQ INNER JOIN
							(	SELECT TopLevelFraction, Fraction, Mass_Tag_ID
								FROM #UMCMatchResultsByJob
								GROUP BY TopLevelFraction, Fraction, Mass_Tag_ID
								HAVING (SUM(UseValue) = 0)
							) InnerQ ON 
							InnerQ.TopLevelFraction = OuterQ.TopLevelFraction AND
							InnerQ.Fraction = OuterQ.Fraction AND 
							InnerQ.Mass_Tag_ID = OuterQ.Mass_Tag_ID)
						)
		End -- </b>

		-- Count the number of fully excluded mass tags
		-- If @AddBackExcludedMassTags = 1, then @UniqueMassTagCountFilteredOut will be 0
		SELECT @UniqueMassTagCountFilteredOut = COUNT(Mass_Tag_ID)
		FROM (	SELECT DISTINCT Mass_Tag_ID
				FROM #UMCMatchResultsByJob
				WHERE InternalStdMatch = 0
				GROUP BY TopLevelFraction, Fraction, Mass_Tag_ID
				HAVING SUM(UseValue) = 0
			 ) As MyStats

		-- Count the number of fully excluded internal standard peptides
		SELECT @UniqueInternalStdCountFilteredOut = COUNT(Mass_Tag_ID)
		FROM (	SELECT DISTINCT Mass_Tag_ID
				FROM #UMCMatchResultsByJob
				WHERE InternalStdMatch = 1
				GROUP BY TopLevelFraction, Fraction, Mass_Tag_ID
				HAVING SUM(UseValue) = 0
			 ) As MyStats

		-- Count the number of excluded UMC's
		SELECT @MTMatchingUMCsCountFilteredOut = IsNull(SUM(UniqueIDCount), 0)
		FROM (	SELECT COUNT(UniqueID) AS UniqueIDCount
				FROM #UMCMatchResultsByJob
				WHERE UseValue = 0
				GROUP BY TopLevelFraction, Fraction) As MyStats

	End -- </a>
	
	
	-----------------------------------------------------------
	-- Step 8
	--
	-- Update the overall stats for this QuantitationID in T_Quantitation_Description
	-----------------------------------------------------------
	--
	-- Count the number of UMCMatch values in #UMCMatchResultsByJob with UseValue = 1
	SELECT @MTMatchingUMCsCount = SUM(UniqueIDCount)
	FROM (	SELECT COUNT(UniqueID) AS UniqueIDCount
			FROM #UMCMatchResultsByJob
			WHERE UseValue = 1
			GROUP BY TopLevelFraction, Fraction) As MyStats
	
	-- Count the number of unique mass tags in #UMCMatchResultsByJob, having 1 or more 
	--  UMC's with UseValue = 1
	SELECT	@UniqueMassTagCount = COUNT(Mass_Tag_ID)
	FROM	(	SELECT DISTINCT Mass_Tag_ID
				FROM #UMCMatchResultsByJob
				WHERE InternalStdMatch = 0
				GROUP BY TopLevelFraction, Fraction, Mass_Tag_ID
				HAVING SUM(UseValue) > 0
			 ) MyStats

	-- Count the number of unique internal standard peptides in #UMCMatchResultsByJob, having 1 or more 
	--  UMC's with UseValue = 1
	SELECT	@UniqueInternalStdCount = COUNT(Mass_Tag_ID)
	FROM	(	SELECT DISTINCT Mass_Tag_ID
				FROM #UMCMatchResultsByJob
				WHERE InternalStdMatch = 1
				GROUP BY TopLevelFraction, Fraction, Mass_Tag_ID
				HAVING SUM(UseValue) > 0
			 ) MyStats



	-- Populate the relevant statistics in T_Quantitation_Description
	UPDATE T_Quantitation_Description
	SET	MTMatchingUMCsCount = @MTMatchingUMCsCount,
		MTMatchingUMCsCountFilteredOut = @MTMatchingUMCsCountFilteredOut,
		UniqueMassTagCount = @UniqueMassTagCount,
		UniqueMassTagCountFilteredOut = @UniqueMassTagCountFilteredOut,
		UniqueInternalStdCount = @UniqueInternalStdCount,
		UniqueInternalStdCountFilteredOut = @UniqueInternalStdCountFilteredOut,
		Last_Affected = GetDate()
	WHERE Quantitation_ID = @QuantitationID

Done:
	Return @myError


GO
