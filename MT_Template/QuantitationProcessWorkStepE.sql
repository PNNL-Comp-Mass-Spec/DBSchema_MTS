/****** Object:  StoredProcedure [dbo].[QuantitationProcessWorkStepE] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.QuantitationProcessWorkStepE
/****************************************************	
**  Desc: 
**
**  Return values: 0 if success, otherwise, error code
**
**  Auth:	mem
**	Date:	09/07/2006
**			05/25/2007 mem - Now populating column JobCount_Observed_Both_MS_and_MSMS
**			06/06/2007 mem - Now populating column Rank_Match_Score_Avg
**
****************************************************/
(
	@QuantitationID int,
	@InternalStdInclusionMode tinyint,			-- 0 for no NET lockers, 1 for PMT tags and NET Lockers, 2 for NET lockers only
	@message varchar(512)='' output
)
AS
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0


	-----------------------------------------------------------
	-- Step 9
	--
	-- Compute the average abundance for each mass tag (aka peptide)
	-- Additionally, compute the average expression ratio (ER) for each mass tag
	-- At this point, results across replicates are averaged to give a single list 
	--   of peptides and abundances (and ER's), with no peptide duplicates, for each
	--   fraction and each TopLevelFraction.  If there was only one replicate, all of 
	--   the averages produced by the Group By clause of the Insert Into query will be
	--   the original value rather than a true average
	--	For multiple replicates, we obtain an average abundance (or ER) for each peptide, 
	--	 computed by averaging the abundances (and ER's) seen in each replicate for each peptide
	--	If a peptide is only seen in 1 replicate, then the average is simply the
	--	 observed abundance.  In this case, the standard deviation of the
	--	 "averaged" abundance is Null (since no averaging really occurred).  If a
	--	 peptide is present in multiple replicates, then we can compute a standard
	--	 deviation of the averaged abundance.

	--	For ER values, we will also average across replicates.  However, we will use a weighted
	--  average, weighting by MTAbundanceLightPlusHeavy.  If a peptide is only seen in 1 replicate, 
	--  then the average is simply the ER.  Note that we now have StDev values for ER values,
	--  so the appropriate solution is to use SUM(Expression_Ratio * MTAbundanceLightPlusHeavy) / SUM(MTAbundanceLightPlusHeavy)

	-- If all of the ER_StDev values for the data to be combined are 0, then we can compute a standard StDev of the ER values

	-- When selecting the results to average, we only choose those rows with UseValue = 1
	--  since individual UMC's could have been filtered out above during outlier filtering
	-----------------------------------------------------------
	--
	-- Step 9a
	--
	-- Pre-define the #UMCMatchResultsByFraction table before populating it
	-- This is done to assure the correct data type is used
	-- We can define an index on Mass_Tag_ID
	--
	if exists (select * from dbo.sysobjects where id = object_id(N'[#UMCMatchResultsByFraction]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	drop table [#UMCMatchResultsByFraction]
		
	CREATE TABLE #UMCMatchResultsByFraction (
		[TopLevelFraction] smallint NOT NULL ,
		[Fraction] smallint NOT NULL ,
		[InternalStdMatch] tinyint NOT NULL ,
		[Mass_Tag_ID] int NOT NULL ,
		[Mass_Tag_Mods] [varchar](50) NOT NULL ,
		[JobCount_Observed_Both_MS_and_MSMS] int NULL ,
		[MTAbundanceAvg] float NULL ,
		[MTAbundanceStDev] float NULL ,
		[MTAbundanceLightPlusHeavyAvg] float NULL ,
		[Member_Count_Used_For_Abu_Avg] real NULL ,
		[Rank_Match_Score_Avg] float NULL ,
		[Match_Score_Avg] float NULL ,
		[Del_Match_Score_Avg] float NULL ,
		[NET_Error_Obs_Avg] float NULL ,
		[NET_Error_Pred_Avg] float null ,
		[ERAvg] float NULL ,
		[ER_StDev] float NULL ,
		[ER_Charge_State_Basis_Count_Avg] float NULL ,
		[ScanMinimum] int NOT NULL ,
		[ScanMaximum] int NOT NULL ,
		[NET_Minimum] real NOT NULL ,
		[NET_Maximum] real NOT NULL ,
		[Class_Stats_Charge_Basis_Avg] real NOT NULL ,
		[Charge_State_Min] tinyint NOT NULL ,
		[Charge_State_Max] tinyint NOT NULL ,
		[MassErrorPPMAvg] float NOT NULL ,
		[UMCMatchCountAvg] real NULL ,
		[UMCIonCountTotalAvg] real NULL ,
		[UMCIonCountMatchAvg] real NULL ,
		[UMCIonCountMatchInUMCsWithSingleHitAvg] real NULL ,
		[FractionScansMatchingSingleMTAvg] real NULL ,
		[FractionScansMatchingSingleMTStDev] real NULL ,
		[UMCMultipleMTHitCountAvg] real NULL ,
		[UMCMultipleMTHitCountStDev] float NULL ,
		[UMCMultipleMTHitCountMin] int NULL ,
		[UMCMultipleMTHitCountMax] int NULL ,
		[ReplicateCount] smallint NOT NULL ,
	)

	CREATE INDEX #IX__TempTable__UMCMatchResultsByFraction ON #UMCMatchResultsByFraction([Mass_Tag_ID]) ON [PRIMARY]
	
	-- Step 9b
	--
	-- Populate the table
	-- Note: The STDEV(FractionScansMatchingSingleMT) code in the following statement will generate a
	--  "Warning: Null value is eliminated by an aggregate or other SET operation" warning; that is both expected and acceptable
	INSERT INTO #UMCMatchResultsByFraction
		(TopLevelFraction, Fraction,
		InternalStdMatch,
		Mass_Tag_ID,
		Mass_Tag_Mods,
		JobCount_Observed_Both_MS_and_MSMS,
		MTAbundanceAvg, MTAbundanceStDev,
		MTAbundanceLightPlusHeavyAvg,
		Member_Count_Used_For_Abu_Avg,
		Rank_Match_Score_Avg,
		Match_Score_Avg,
		Del_Match_Score_Avg,
		NET_Error_Obs_Avg,
		NET_Error_Pred_Avg,
		ERAvg, ER_StDev,
		ER_Charge_State_Basis_Count_Avg,
		ScanMinimum, ScanMaximum, 
		NET_Minimum, NET_Maximum,
		Class_Stats_Charge_Basis_Avg,
		Charge_State_Min, Charge_State_Max,
		MassErrorPPMAvg,
		UMCMatchCountAvg, UMCIonCountTotalAvg, 
		UMCIonCountMatchAvg, UMCIonCountMatchInUMCsWithSingleHitAvg,
		FractionScansMatchingSingleMTAvg, FractionScansMatchingSingleMTStDev,
		UMCMultipleMTHitCountAvg, UMCMultipleMTHitCountStDev,
		UMCMultipleMTHitCountMin, UMCMultipleMTHitCountMax,
		ReplicateCount)
	SELECT	TopLevelFraction, Fraction,
			InternalStdMatch,
			Mass_Tag_ID, 
			Mass_Tag_Mods,
			SUM(Observed_By_MSMS_in_This_Dataset),				-- JobCount_Observed_Both_MS_and_MSMS
			AVG(MTAbundance),									-- MTAbundanceAvg
			-- If only a single trial, then cannot have a MTAbundance StDev value
			-- Use IsNull() to convert the resultant Null StDev values to 0
			IsNull(STDEV(MTAbundance), 0),						-- MTAbundanceStDev

			AVG(MTAbundanceLightPlusHeavy),						-- MTAbundanceLightPlusHeavyAvg
			AVG(CONVERT(real, Member_Count_Used_For_Abu)),		-- Member_Count_Used_For_Abu_Avg; Avg, since we're averaging MTAbundance
			AVG(Rank_Match_Score_Avg),
			AVG(Match_Score_Avg),
			AVG(Del_Match_Score_Avg),
			AVG(NET_Error_Obs_Avg),
			AVG(NET_Error_Pred_Avg),
			
			CASE WHEN SUM(MTAbundanceLightPlusHeavy) > 0
			THEN SUM(ER_ToUse * MTAbundanceLightPlusHeavy) / SUM(MTAbundanceLightPlusHeavy)
			ELSE 0
			END,				-- ERAvg; weighted average
			-- Old: AVG(),		-- ERAvg

			CASE WHEN SUM(MTAbundanceLightPlusHeavy) > 0
			THEN SQRT(SUM(SQUARE(ER_StDev) * MTAbundanceLightPlusHeavy) / SUM(MTAbundanceLightPlusHeavy))
			ELSE 0
			END,				-- ER_StDev; weighted average
			-- Old: SQRT(SUM(SQUARE(IsNull(ER_StDev, 0)))),						-- ER_StDev; Old: IsNull(STDEV(ER_ToUse), 0),

			AVG(ER_Charge_State_Basis_Count_Avg),				-- ER_Charge_State_Basis_Count_Avg
			
			Min(ScanMinimum), Max(ScanMaximum),
			Min(NET_Minimum), Max(Net_Maximum),
			AVG(Class_Stats_Charge_Basis_Avg),
			Min(Charge_State_Min), Max(Charge_State_Max),
			AVG(MassErrorPPMAvg),
			AVG(CONVERT(real, UMCMatchCount)),					-- UMCMatchCountAvg
			AVG(CONVERT(real, UMCIonCountTotal)),				-- UMCIonCountTotalAvg
			AVG(CONVERT(real, UMCIonCountMatch)),				-- UMCIonCountMatchAvg
			AVG(CONVERT(real, UMCIonCountMatchInUMCsWithSingleHit)),	-- UMCIonCountMatchInUMCsWithSingleHitAvg
			AVG(FractionScansMatchingSingleMT),					-- FractionScansMatchingSingleMTAvg
			IsNull(STDEV(FractionScansMatchingSingleMT), 0),	-- FractionScansMatchingSingleMTStDev
			AVG(UMCMultipleMTHitCountAvg),						-- UMCMultipleMTHitCountAvg
			IsNull(AVG(UMCMultipleMTHitCountStDev), 0),			-- UMCMultipleMTHitCountStDev
			MIN(UMCMultipleMTHitCountMin),						-- UMCMultipleMTHitCountMin
			MAX(UMCMultipleMTHitCountMin),						-- UMCMultipleMTHitCountMax
			Count([Replicate])									-- ReplicateCount
	FROM #UMCMatchResultsByJob
	WHERE UseValue = 1
	GROUP BY TopLevelFraction, Fraction, InternalStdMatch, Mass_Tag_ID, Mass_Tag_Mods
	ORDER BY TopLevelFraction, Fraction, InternalStdMatch, Mass_Tag_ID, Mass_Tag_Mods
	--
	SELECT @myError = @@error, @myRowCount = @@RowCount
	--
	Select @myRowCount = Count(*) from #UMCMatchResultsByFraction
	

	-----------------------------------------------------------
	-- Step 10
	--
	-- We can now sum peptide abundances across fractions
	-- For expression ratio values, we'll simply average across fractions;
	--  this isn't ideal, but it's unlikely people will have fractionated ER-based samples
	-- Results for the various fractions are combined
	--  into one "virtual" fraction for each TopLevelFraction
	--		This is done because a given peptide could be present in multiple
	--		 fractions; we want to sum the abundances of the UMC's matching the
	--		 given peptide across all fractions
	-----------------------------------------------------------
	--
	-- Step 10a
	--
	-- Pre-define the #UMCMatchResultsByTopLevelFraction table before populating it
	-- This is done to assure the correct data type is used
	-- We can also pre-define one index
	--
	if exists (select * from dbo.sysobjects where id = object_id(N'[#UMCMatchResultsByTopLevelFraction]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	drop table [#UMCMatchResultsByTopLevelFraction]

	CREATE TABLE #UMCMatchResultsByTopLevelFraction (
		[TopLevelFraction] smallint NOT NULL ,
		[InternalStdMatch] tinyint NOT NULL ,
		[Mass_Tag_ID] int NOT NULL ,
		[Mass_Tag_Mods] [varchar](50) NOT NULL ,
		[JobCount_Observed_Both_MS_and_MSMS] int NULL ,
		[MTAbundanceAvg] float NULL ,					-- Sum of MT Abundance values across fractions
		[MTAbundanceStDev] float NULL ,					-- Standard deviation for a sum of numbers = Sqrt(Sum(StDevs^2))
		[MTAbundanceLightPlusHeavyAvg] float NULL ,
		[Member_Count_Used_For_Abu_Avg] float NULL ,
		[Rank_Match_Score_Avg] float NULL ,
		[Match_Score_Avg] float NULL ,
		[Del_Match_Score_Avg] float NULL ,
		[NET_Error_Obs_Avg] float NULL ,
		[NET_Error_Pred_Avg] float null ,
		[ERAvg] float NULL ,
		[ER_StDev] float NULL ,
		[ER_Charge_State_Basis_Count_Avg] float NULL ,
		[ScanMinimum] int NOT NULL ,
		[ScanMaximum] int NOT NULL ,
		[NET_Minimum] real NOT NULL ,
		[NET_Maximum] real NOT NULL ,
		[Class_Stats_Charge_Basis_Avg] real NOT NULL ,
		[Charge_State_Min] tinyint NOT NULL ,
		[Charge_State_Max] tinyint NOT NULL ,
		[MassErrorPPMAvg] float NOT NULL ,
		[UMCMatchCountAvg] real NULL ,
		[UMCMatchCountStDev] real NULL ,
		[UMCIonCountTotalAvg] real NULL ,
		[UMCIonCountMatchAvg] real NULL ,
		[UMCIonCountMatchInUMCsWithSingleHitAvg] real NULL ,
		[FractionScansMatchingSingleMTAvg] real NULL ,
		[FractionScansMatchingSingleMTStDev] real NULL ,
		[UMCMultipleMTHitCountAvg] real NULL ,
		[UMCMultipleMTHitCountStDev] float NULL ,
		[UMCMultipleMTHitCountMin] int NULL ,
		[UMCMultipleMTHitCountMax] int NULL ,
		[ReplicateCountAvg] real NULL ,
		[ReplicateCountMin] smallint NULL ,
		[ReplicateCountMax] smallint NULL ,
		[FractionCount] smallint NULL ,
		[FractionMin] smallint NULL ,
		[FractionMax] smallint NULL
	) ON [PRIMARY]

	 CREATE  INDEX #IX__TempTable__UMCMatchResultsByTopLevelFraction_Mass_Tag_ID ON #UMCMatchResultsByTopLevelFraction([Mass_Tag_ID]) ON [PRIMARY]

	-- Step 10b
	--
	-- Sum peptide abundances across fractions
	INSERT INTO #UMCMatchResultsByTopLevelFraction
		(TopLevelFraction, InternalStdMatch, 
		 Mass_Tag_ID,
		 Mass_Tag_Mods,
		 JobCount_Observed_Both_MS_and_MSMS,
		 MTAbundanceAvg, MTAbundanceStDev,
		 MTAbundanceLightPlusHeavyAvg,
		 Member_Count_Used_For_Abu_Avg,
		 Rank_Match_Score_Avg,
		 Match_Score_Avg,
		 Del_Match_Score_Avg,
		 NET_Error_Obs_Avg,
		 NET_Error_Pred_Avg,
		 ERAvg, ER_StDev,
		 ER_Charge_State_Basis_Count_Avg,
		 ScanMinimum, ScanMaximum, 
		 NET_Minimum, NET_Maximum,
		 Class_Stats_Charge_Basis_Avg,
		 Charge_State_Min, Charge_State_Max,
		 MassErrorPPMAvg,
		 UMCMatchCountAvg, UMCMatchCountStDev,
		 UMCIonCountTotalAvg, UMCIonCountMatchAvg, 
		 UMCIonCountMatchInUMCsWithSingleHitAvg,
		 FractionScansMatchingSingleMTAvg, FractionScansMatchingSingleMTStDev,
		 UMCMultipleMTHitCountAvg, UMCMultipleMTHitCountStDev,
		 UMCMultipleMTHitCountMin, UMCMultipleMTHitCountMax,
		 ReplicateCountAvg, ReplicateCountMin, ReplicateCountMax,
		 FractionCount, FractionMin, FractionMax)
	SELECT	TopLevelFraction, InternalStdMatch, 
			Mass_Tag_ID, 
			Mass_Tag_Mods,
			SUM(JobCount_Observed_Both_MS_and_MSMS),
			SUM(MTAbundanceAvg),											-- MTAbundanceAvg = Sum of MTAbundanceAvg values across fractions
			-- Compute the standard deviation of the Sum of several numbers by finding the
			--  sum of the squares of the MTAbundanceStDev values, then taking the
			--  square root of the result
			SQRT(SUM(SQUARE(IsNull(MTAbundanceStDev, 0)))),					-- MTAbundanceStDev
			
			SUM(MTAbundanceLightPlusHeavyAvg),
			SUM(Member_Count_Used_For_Abu_Avg),								-- Sum, since we're summing MTAbundanceAvg
			AVG(Rank_Match_Score_Avg),
			AVG(Match_Score_Avg),
			AVG(Del_Match_Score_Avg),
			AVG(NET_Error_Obs_Avg),
			AVG(NET_Error_Pred_Avg),

			CASE WHEN SUM(MTAbundanceLightPlusHeavyAvg) > 0
			THEN SUM(ERAvg * MTAbundanceLightPlusHeavyAvg) / SUM(MTAbundanceLightPlusHeavyAvg)
			ELSE 0
			END,				-- ERAvg; weighted average
			-- Old: AVG(),		-- ERAvg

			CASE WHEN SUM(MTAbundanceLightPlusHeavyAvg) > 0
			THEN SQRT(SUM(SQUARE(ER_StDev) * MTAbundanceLightPlusHeavyAvg) / SUM(MTAbundanceLightPlusHeavyAvg))
			ELSE 0
			END,				-- ER_StDev; weighted average
			-- Old: SQRT(SUM(SQUARE(IsNull(ER_StDev, 0)))),		-- ER_StDev

			AVG(ER_Charge_State_Basis_Count_Avg),				-- ER_Charge_State_Basis_Count_Avg
			
			Min(ScanMinimum), Max(ScanMaximum),
			Min(NET_Minimum), Max(NET_Maximum),
			Avg(Class_Stats_Charge_Basis_Avg),
			Min(Charge_State_Min), Max(Charge_State_Max),
			AVG(MassErrorPPMAvg),
			AVG(UMCMatchCountAvg),											-- UMCMatchCountAvg
			IsNull(StDev(UMCMatchCountAvg), 0),								-- UMCMatchCountStDev
			AVG(UMCIonCountTotalAvg), AVG(UMCIonCountMatchAvg), 
			AVG(UMCIonCountMatchInUMCsWithSingleHitAvg),
			AVG(FractionScansMatchingSingleMTAvg), AVG(FractionScansMatchingSingleMTStDev),
			AVG(UMCMultipleMTHitCountAvg), AVG(UMCMultipleMTHitCountStDev),
			MIN(UMCMultipleMTHitCountMin), MAX(UMCMultipleMTHitCountMax),
			AVG(CONVERT(real, ReplicateCount)), MIN(ReplicateCount), MAX(ReplicateCount),
			COUNT(Fraction), MIN(Fraction), MAX(Fraction)
	FROM  #UMCMatchResultsByFraction
	GROUP BY TopLevelFraction, InternalStdMatch, Mass_Tag_ID, Mass_Tag_Mods
	ORDER BY TopLevelFraction, InternalStdMatch, Mass_Tag_ID, Mass_Tag_Mods
	--
	SELECT @myError = @@error, @myRowCount = @@RowCount
	--
	--
	IF @myError <> 0
	Begin
		Set @message = 'Error while populating the UMCMatchResultsSummary temporary table'
		Set @myError = 131
		Goto Done
	End


	-----------------------------------------------------------
	-- Step 11
	--
	-- We can now sum peptide abundances across Top Level Fractions
	-- For expression ratio values, we'll simply average across fractions;
	--  this isn't ideal, but it's unlikely people will have fractionated ER-based samples
	-- Results for the various Top Level Fractions are combined
	-- into one "virtual" master fraction
	--
	-- We can also link in Ref_ID at this time
	-----------------------------------------------------------

	-- Step 11b
	--
	-- Sum peptide abundances across top level fractions
	INSERT INTO #UMCMatchResultsSummary
		(Ref_ID, InternalStdMatch, 
		 Mass_Tag_ID, 
		 Mass_Tag_Mods, 
		 JobCount_Observed_Both_MS_and_MSMS, 
		 Protein_Count, PMT_Quality_Score,
		 Cleavage_State, Fragment_Span,
		 MTAbundanceAvg, MTAbundanceStDev,
		 MTAbundanceLightPlusHeavyAvg,
		 Member_Count_Used_For_Abu_Avg,
		 Rank_Match_Score_Avg,
		 Match_Score_Avg,
		 Del_Match_Score_Avg,
		 NET_Error_Obs_Avg,
		 NET_Error_Pred_Avg,
		 ERAvg, ER_StDev,
		 ER_Charge_State_Basis_Count_Avg,
		 ScanMinimum, ScanMaximum,
		 NET_Minimum, NET_Maximum,
		 Class_Stats_Charge_Basis_Avg,
		 Charge_State_Min, Charge_State_Max,
		 MassErrorPPMAvg,
		 UMCMatchCountAvg, UMCMatchCountStDev,
		 UMCIonCountTotalAvg, UMCIonCountMatchAvg, 
		 UMCIonCountMatchInUMCsWithSingleHitAvg,
		 FractionScansMatchingSingleMTAvg, FractionScansMatchingSingleMTStDev,
		 UMCMultipleMTHitCountAvg, UMCMultipleMTHitCountStDev,
		 UMCMultipleMTHitCountMin, UMCMultipleMTHitCountMax,
		 ReplicateCountAvg, ReplicateCountMin, ReplicateCountMax,
		 FractionCountAvg, FractionMin, FractionMax,
		 TopLevelFractionCount, TopLevelFractionMin, TopLevelFractionMax,
		 MaxClassAbundanceThisRef)
	SELECT	MTPM.Ref_ID, UMR.InternalStdMatch, 
			UMR.Mass_Tag_ID, 
			UMR.Mass_Tag_Mods,
			SUM(JobCount_Observed_Both_MS_and_MSMS),
			IsNull(MT.Multiple_Proteins,0) + 1, IsNull(MT.PMT_Quality_Score,0),
			MTPM.Cleavage_State, MTPM.Fragment_Span,							-- Note that these values could be NULL
			SUM(MTAbundanceAvg),											-- MTAbundanceAvg = Sum of MTAbundanceAvg values across fractions
			-- Compute the standard deviation of the Sum of several numbers by finding the
			--  sum of the squares of the MTAbundanceStDev values, then taking the
			--  square root of the result
			SQRT(SUM(SQUARE(IsNull(MTAbundanceStDev, 0)))),					-- MTAbundanceStDev

			SUM(MTAbundanceLightPlusHeavyAvg),
			SUM(Member_Count_Used_For_Abu_Avg),
			AVG(Rank_Match_Score_Avg),
			AVG(Match_Score_Avg),
			AVG(Del_Match_Score_Avg),
			AVG(NET_Error_Obs_Avg),
			AVG(NET_Error_Pred_Avg),
			
			CASE WHEN SUM(MTAbundanceLightPlusHeavyAvg) > 0
			THEN SUM(ERAvg * MTAbundanceLightPlusHeavyAvg) / SUM(MTAbundanceLightPlusHeavyAvg)
			ELSE 0
			END,				-- ERAvg; weighted average
			-- Old: AVG(),		-- ERAvg

			CASE WHEN SUM(MTAbundanceLightPlusHeavyAvg) > 0
			THEN SQRT(SUM(SQUARE(ER_StDev) * MTAbundanceLightPlusHeavyAvg) / SUM(MTAbundanceLightPlusHeavyAvg))
			ELSE 0
			END,				-- ER_StDev; weighted average
			-- Old: SQRT(SUM(SQUARE(IsNull(ER_StDev, 0)))),		-- ER_StDev

			AVG(ER_Charge_State_Basis_Count_Avg),				-- ER_Charge_State_Basis_Count_Avg
				
			Min(ScanMinimum), Max(ScanMaximum),
			Min(NET_Minimum), Max(NET_Maximum),
			Avg(Class_Stats_Charge_Basis_Avg),
			Min(Charge_State_Min), Max(Charge_State_Max),
			AVG(MassErrorPPMAvg),
			AVG(UMCMatchCountAvg), AVG(UMCMatchCountStDev),
			AVG(UMCIonCountTotalAvg), AVG(UMCIonCountMatchAvg), 
			AVG(UMCIonCountMatchInUMCsWithSingleHitAvg),
			AVG(FractionScansMatchingSingleMTAvg), AVG(FractionScansMatchingSingleMTStDev),
			AVG(UMCMultipleMTHitCountAvg), AVG(UMCMultipleMTHitCountStDev),
			MIN(UMCMultipleMTHitCountMin), MAX(UMCMultipleMTHitCountMax),
			AVG(ReplicateCountAvg), MIN(ReplicateCountMin), MAX(ReplicateCountMax),
			AVG(CONVERT(real, FractionCount)),	MIN(FractionMin), MAX(FractionMax),
			COUNT(TopLevelFraction), MIN(TopLevelFraction), MAX(TopLevelFraction),
			CONVERT(float, 0)
	FROM	#UMCMatchResultsByTopLevelFraction AS UMR INNER JOIN
			T_Mass_Tag_to_Protein_Map AS MTPM ON
			UMR.Mass_Tag_ID = MTPM.Mass_Tag_ID INNER JOIN
			T_Mass_Tags AS MT ON UMR.Mass_Tag_ID = MT.Mass_Tag_ID
	GROUP BY MTPM.Ref_ID, UMR.InternalStdMatch, UMR.Mass_Tag_ID, UMR.Mass_Tag_Mods, IsNull(MT.Multiple_Proteins,0) + 1, IsNull(MT.PMT_Quality_Score,0), MTPM.Cleavage_State, MTPM.Fragment_Span
	ORDER BY MTPM.Ref_ID, UMR.InternalStdMatch, UMR.Mass_Tag_ID, UMR.Mass_Tag_Mods
	--
	SELECT @myError = @@error, @myRowCount = @@RowCount
	--
	IF @myError <> 0
	Begin
		Set @message = 'Error while populating the UMCMatchResultsSummary temporary table'
		Set @myError = 132
		Goto Done
	End
	--
	If @myRowCount = 0
	Begin
		-- Generate an error message stating that no results were found
		exec QuantitationProcessWorkMsgNoResults @QuantitationID, @InternalStdInclusionMode, @message output
		set @myError = 133
		goto Done
	End

	-- Make sure Protein_Count is not under-estimated in #UMCMatchResultsSummary
	-- The Protein_Count value was originally obtained from T_Mass_Tags.Multiple_Proteins
	-- If there are more entries in T_Mass_Tag_to_Protein_Map than Multiple_Proteins+1, then
	-- Protein_Count in #UMCMatchResultsSummary will be updated to the number of 
	-- entries in T_Mass_Tag_to_Protein_Map for the given mass tag
	UPDATE #UMCMatchResultsSummary
	SET Protein_Count = SubQ.Protein_Count_For_MT
	FROM #UMCMatchResultsSummary INNER JOIN (
			SELECT Mass_Tag_ID, Count(Ref_ID) AS Protein_Count_For_MT
			FROM #UMCMatchResultsSummary
			GROUP BY Mass_Tag_ID
		 ) AS SubQ ON #UMCMatchResultsSummary.Mass_Tag_ID = SubQ.Mass_Tag_ID
	WHERE SubQ.Protein_Count_For_MT > Protein_Count
	--
	SELECT @myError = @@error, @myRowCount = @@RowCount

Done:
	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[QuantitationProcessWorkStepE] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[QuantitationProcessWorkStepE] TO [MTS_DB_Lite] AS [dbo]
GO
