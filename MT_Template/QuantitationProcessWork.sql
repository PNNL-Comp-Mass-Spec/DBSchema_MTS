/****** Object:  StoredProcedure [dbo].[QuantitationProcessWork] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure QuantitationProcessWork
/****************************************************	
**  Desc: Processes a single Quantitation ID entry 
**		Quantitation results are written to T_Quantitation_Results,
**		T_Quantitation_ResultDetails, and, for replicate
**		quantitation sets, to T_Quantitation_ReplicateResultDetails
**
**  Return values: 0 if success, otherwise, error code
**
**  Parameters: Quantitation_ID to Process
**
**  Auth:	mem
**	Date:	06/03/2003
**			06/23/2003 mem
**			07/04/2003 mem
**			07/06/2003 mem
**			07/07/2003 mem
**			07/08/2003 mem
**			07/22/2003 mem
**			07/29/2003 mem
**			08/26/2003 mem - Changed Trial to Replicate where appropriate
**						   - Updated to roll-up by replicate, then by fraction, then by TopLevelFraction
**			09/14/2003 mem
**			09/17/2003 mem - Added inclusion of Expression_Ratio values in rollups
**			09/20/2003 mem - Added min/max scan number and avg mass error for each peptide in rollups
**			10/02/2003 mem - Now using median across replicates in addition to average across replicates when finding outliers
**			11/09/2003 mem - Added computation and storage of NET_Minimum and NET_Maximum
**			11/12/2003 mem - Added inclusion of Mass_Tag_Mods (from T_FTICR_UMC_ResultDetails)
**			11/18/2003 mem - Added option to filter mass tags by Minimum_High_Normalized_Score; in addition, added rollup of charge state info
**			11/19/2003 mem - Added use of T_FTICR_UMC_ResultDetails.Mass_Tag_Mod_Mass to correct the MassErrorPPMAvg calculation
**			11/26/2003 mem - Added option to filter out peptides not present in a minimum number of replicates
**			12/01/2003 mem - Added option to normalize replicates using linear regression of the peptides in common with the replicates
**			12/02/2003 mem - Added filter to only include the peak matching results having T_FTICR_UMC_ResultDetails.Match_State = 6 
**			12/03/2003 mem - Disabled the normalized replicates using linear regression code since not improving the statistics
**			02/21/2004 mem - Changed PK__UMCMatchResultsByJob and the various indices on the temporary tables to be temporary-type indices by adding the # symbol
**			04/04/2004 mem - Added ability to specify minimum peptide length and minimum PMT Quality Score
**						   - Now computing Mass_Error_PPM_Avg, ORF_Count_Avg, Full_Enzyme_Count, Full_Enzyme_No_Missed_Cleavage_Count, and Partial_Enzyme_Count and storing in T_Quantitation_Results
**						   - Added computation of ORF coverage (at the residue level), storing results in T_Quantitation_Results
**			04/08/2004 mem - Fixed bug with computation of minimum potential MT high normalized score and minimum potential PMT quality score
**			04/09/2004 mem - Added @ORFCoverageComputationLevel option (new field in T_Quantitation_Description); 0 = off, 1 = observed ORF coverage, 2 = observed and potential ORF coverage
**			04/12/2004 mem - Added support for @UMCAbundanceMode option (new field in T_Quantitation_Desccription); 0 = value in table (typically peak area), 1 = peak maximum
**			05/11/2004 mem - Fixed bug with minimum PMT quality score filter
**			06/06/2004 mem - Added ORF_Coverage_Fraction_High_Abundance
**			06/09/2004 mem - Now using CountCapitalLetters to count the number of capital letters in sequence
**			07/06/2004 mem - Moved computation of ER_WeightedAvg to a separate query due to need to check for ER values > 1E+100
**			07/10/2004 mem - Changed ER_WeightedAvg and ER_StDev computations to utilize the sum of the light and heavy UMC abundances rather than UMC member counts; note that heavy UMC abundance is computed from Light Abu and ER
**						   - Added columns Member_Count_Used_For_Abundance, ER_Charge_State_Basis_Count, and Match_Score_Avg
**						   - Added @MinimumMatchScore parameter
**			08/17/2004 mem - Added columns Del_Match_Score_Avg, NET_Error_Obs_Avg, and NET_Error_Pred_Avg
**			09/26/2004 mem - Updated to work with DB Schema Version 2
**			04/04/2005 mem - Added @MinimumMTHighDiscriminantScore parameter
**			04/07/2005 mem - Added @MinimumDelMatchScore parameter
**			05/25/2005 mem - Now summarizing Internal Standard (NET Locker) Matches
**			06/09/2005 mem - Fixed bug related to deleting low scoring matches (Match_Score < @MinimumMatchScore)
**			07/28/2005 mem - Now populating field FeatureCountWithMatchesAvg in T_Quantitation_Description
**			09/22/2005 mem - Moved removal of peptides that aren't present in the minimum number of replicates to occur before filtering out peptide abundance outliers
**						   - Fixed bug that failed to populate @FractionCrossReplicateAvgInRange with the value in T_Quantitation_Description and instead always used 0.8
**			12/15/2005 mem - Switched from using T_GANET_Lockers to MT_Main..T_Internal_Std_Components
**			12/29/2005 mem - Renamed T_FTICR_UMC_NETLockerDetails to T_FTICR_UMC_InternalStdDetails
**			03/23/2006 mem - Replaced all decimal data types with real data types to avoid overflow errors
**			09/06/2006 mem - Added support for Minimum_MT_Peptide_Prophet_Probability
**			09/07/2006 mem - Refactored to place the code for the various steps in separate SPs
**			05/25/2007 mem - Added columns Job and Observed_By_MSMS_in_This_Dataset to #UMCMatchResultsByJob
**			06/05/2007 mem - Switched to Try/Catch error handling
**			06/06/2007 mem - Added [Rank_Match_Score_Avg] to #UMCMatchResultsByJob and #UMCMatchResultsSummary
**			09/13/2010 mem - Changed Charge_State_Min and Charge_State_Max to smallint
**			10/13/2010 mem - Now validating that peak matching results being rolled up all have the same value for Match_Score_Mode
**						   - Added support for Minimum_Uniqueness_Probability and Maximum_FDR_Threshold; these are only used when Match_Score_Mode <> 0
**
****************************************************/
(
	@QuantitationID int					-- Quantitation_ID to process 
)
AS
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	
	Declare	@ReplicateCountEstimate int,
			@MatchScoreModeMin int, 
			@MatchScoreModeMax int
			
	Declare @message varchar(512)
	
	Declare	@RemoveOutlierAbundancesForReplicates tinyint,		-- If 1, use a filter to remove outliers (only possible with replicate data)
			@FractionCrossReplicateAvgInRange real,			-- Fraction plus or minus the average abundance across replicates for filtering out UMC's matching a given mass tag; it is allowable for this value to be greater than 1
			@AddBackExcludedMassTags tinyint,				-- If 1, means to not allow matching AMTs to be completely filtered out using the outlier filter
															-- As an example, if a mass tag was seen in 2 replicates, with an abundance of 10 and 500,
															--  then the average across replicates is 255, now if @FractionCrossReplicateAvgInRange = 0.8,
															--  the cutoff values are 51 and 459 (+-80% of 250).  These cutoff values will exlude both the
															--  Abundance 10 and Abundance 500 values, which will completely exlude the given mass tag
			@FractionHighestAbuToUse real,				-- Fraction of highest abundance mass tag for given ORF to use when computing ORF abundance (0.0 to 1.0)
			@NormalizeAbundances tinyint,				-- 1 to normalize, 0 to not normalize
			@NormalizeReplicateAbu tinyint,				-- 1 to normalize replicate abundances
			@StandardAbundanceMin float,				-- Used with normalization: minimum abundance
			@StandardAbundanceMax float,				-- Used with normalization: maximum abundance
			@StandardAbundanceRange float,
			@UMCAbundanceMode tinyint,					-- 0 to use the value in T_FTICR_UMC_Results (typically peak area); 1 to use the peak maximum
			@ERMode tinyint,							-- 0 to use Expression_Ratio_Recomputed (treat multiple UMCs matching same same mass tag in same job as essentially one large UMC), 1 to use Expression_Ratio_WeightedAvg (weight multiple ER values for same mass tag by UMC member counts)
			@MinimumMTHighNormalizedScore real,			-- 0 to use all matching AMTs, > 0 to filter by XCorr
			@MinimumMTHighDiscriminantScore real,		-- 0 to use all matching AMTs, > 0 to filter by Discriminant Score
			@MinimumMTPeptideProphetProbability real,	-- 0 to use all matching AMTs, > 0 to filter by Peptide_Prophet_Probability
			@MinimumPMTQualityScore real,				-- 0 to use all matching AMTs, > 0 to filter by PMT Quality Score (as currently set in T_Mass_Tags)
			@MinimumPeptideLength tinyint,				-- 0 to use all matching AMTs, > 0 to filter by peptide length
			@MaximumMatchesPerUMCToKeep smallint,		-- 0 to use all matches for each UMC, > 0 to only use the top @MaximumMatchesPerUMCToKeep matches to each UMC (favoring the ones with the closest SLiC score first); matches with identical SLiC scores will all be used
			@MinimumMatchScore real,					-- 0 to use all mass tag matches, > 0 to filter by Match Score (STAC Score or SLiC Score); if Match_Score_Mode = 1 and 
			@MinimumDelMatchScore real,					-- 0 to use all mass tag matches, > 0 to filter by Del Match Score; only used if @MinimumMatchScore is > 0
			@MinimumUniquenessProbability real,			-- 0 to use all matching AMTs, > 0 to filter by Uniqueness_Probability; Ignored if T_Match_Making_Description.Match_Score_Mode = 0 and @MaximumFDRThreshold is > 0 (but less than 1), then this is auto-changed to 0
 			@MaximumFDRThreshold real,					-- 1 to use all matching AMTs, < 1 to filter by FDR_Threshold; Ignored if T_Match_Making_Description.Match_Score_Mode = 0
			@MinimumPeptideReplicateCount tinyint,		-- 0 or 1 to filter out nothing; 2 or higher to filter out peptides not seen in the given number of replicates
			@ORFCoverageComputationLevel tinyint,		-- 0 for no ORF coverage, 1 for observed ORF coverage, 2 for observed and potential ORF coverage; option 2 is very CPU intensive for large databases
			@InternalStdInclusionMode tinyint			-- 0 for no NET lockers, 1 for PMT tags and NET Lockers, 2 for NET lockers only

	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Begin Try

 		-- Note: These defaults get overridden below during the 
 		--	   Select From T_Quantitation_Description call
 		Set @RemoveOutlierAbundancesForReplicates = 1
 		Set @FractionCrossReplicateAvgInRange = 0.8
 		Set @AddBackExcludedMassTags = 0
 		Set @FractionHighestAbuToUse = 0
 		Set @ERMode = 0
 		Set @MinimumMTHighNormalizedScore = 0
 		Set @MinimumMTHighDiscriminantScore = 0
 		Set @MinimumMTPeptideProphetProbability = 0
 		Set @MinimumPMTQualityScore = 0
		Set @MinimumPeptideLength = 4
		Set @MaximumMatchesPerUMCToKeep = 0
 		Set @MinimumMatchScore = 0
 		Set @MinimumDelMatchScore = 0
 		Set @MinimumUniquenessProbability = 0
 		Set @MaximumFDRThreshold = 1
 		Set @MinimumPeptideReplicateCount = 0
 		Set @ORFCoverageComputationLevel = 1
		Set @InternalStdInclusionMode = 1
		
		Declare @PctSmallDataToDiscard tinyint,							-- Percentage, between 0 and 99
				@PctLargeDataToDiscard tinyint,							-- Percentage, between 0 and 99
				@MinimumDataPointsForRegressionNormalization smallint	-- Number, 2 or larger
							
		Set @PctSmallDataToDiscard = 10
		Set @PctLargeDataToDiscard = 5
		Set @MinimumDataPointsForRegressionNormalization = 10		

		Declare @MinimumPotentialPMTQualityScore real

		Declare @QuantitationIDText varchar(19)
		Set @QuantitationIDText = Convert(varchar(19), @QuantitationID)
		
		-----------------------------------------------------------
		-- Step 1
		--
		-- Delete existing results for @QuantitationID in T_Quantitation_Results
		-- Note that deletes will cascade into T_Quantitation_ResultDetails
		-- via the foreign key relationship on QR_ID
		-----------------------------------------------------------
		--
		Set @CurrentLocation = 'Delete existing results for QID ' + @QuantitationIDText
		--
		DELETE FROM	T_Quantitation_Results
		WHERE		Quantitation_ID = @QuantitationID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		If @myError <> 0 
		Begin
			Set @message = 'Error while deleting rows from T_Quantitation_Results and T_Quantitation_ResultDetails with Quantitation_ID = ' + @QuantitationIDText
			Set @myError = 111
			Goto Done
		End
		
		
		-----------------------------------------------------------
		-- Step 2a
		--
		-- Make sure one or more MD_ID values is present in T_Quantitation_MDIDs
		-- In addition, make sure all of the MD_IDs has the same value for Match_Score_Mode in T_Quantitation_Description
		-----------------------------------------------------------
		--
		Set @CurrentLocation = 'Look for MDIDs for ' + @QuantitationIDText
		Set @ReplicateCountEstimate = 0
		Set @MatchScoreModeMin = 0
		Set @MatchScoreModeMax = 0
		--
		SELECT @ReplicateCountEstimate = Count(DISTINCT QMDID.[Replicate]),
		       @MatchScoreModeMin = MIN(MMD.Match_Score_Mode),
		       @MatchScoreModeMax = MIN(MMD.Match_Score_Mode)
		FROM T_Quantitation_MDIDs QMDID
		     INNER JOIN T_Match_Making_Description MMD
		       ON MMD.MD_ID = QMDID.MD_ID
		WHERE Quantitation_ID = @QuantitationID
		--
		SELECT @myError = @@error, @myRowCount = @@RowCount
		--
		If @myError <> 0 
		Begin
			Set @message = 'Error while checking for existing MDIDs in T_Quantitation_MDIDs'
			Set @myError = 112
			Goto Done
		End
		
		If @ReplicateCountEstimate = 0
		Begin
			Set @message = 'Could not find any MDIDs in T_Quantitation_MDIDs matching Quantitation_ID = ' + @QuantitationIDText
			Set @myError = 113
			Goto Done
		End

		If @MatchScoreModeMin <> @MatchScoreModeMax
		Begin
			Set @message = 'Peak matching results for Quantitation_ID ' + @QuantitationIDText + ' use both SLiC scores and STAC Scores; you can only rollup results that have the same match score mode'
			Set @myError = 114
			Goto Done
		End

		UPDATE T_Quantitation_Description
		SET Match_Score_Mode = @MatchScoreModeMin
		WHERE Quantitation_ID = @QuantitationID
		
		
		-----------------------------------------------------------
		-- Step 3
		--
		-- Lookup the values for Outlier filtering, @FractionHighestAbuToUse,
		--  and the Normalization options in table T_Quantitation_Description
		-----------------------------------------------------------
		--
		Set @CurrentLocation = 'Lookup the option values'
		--
		SELECT	@RemoveOutlierAbundancesForReplicates = RemoveOutlierAbundancesForReplicates,
				@FractionCrossReplicateAvgInRange = FractionCrossReplicateAvgInRange,
				@AddBackExcludedMassTags = AddBackExcludedMassTags,
				@FractionHighestAbuToUse = Fraction_Highest_Abu_To_Use,
				@NormalizeAbundances = Normalize_To_Standard_Abundances,
				@StandardAbundanceMin = Standard_Abundance_Min,
				@StandardAbundanceMax = Standard_Abundance_Max,
				@UMCAbundanceMode = UMC_Abundance_Mode,
				@ERMode = Expression_Ratio_Mode,
				@MinimumMTHighNormalizedScore = Minimum_MT_High_Normalized_Score,
				@MinimumMTHighDiscriminantScore = Minimum_MT_High_Discriminant_Score,
 				@MinimumMTPeptideProphetProbability = Minimum_MT_Peptide_Prophet_Probability,
				@MinimumPMTQualityScore = Minimum_PMT_Quality_Score,
				@MinimumPeptideLength = Minimum_Peptide_Length,
				@MaximumMatchesPerUMCToKeep = Maximum_Matches_per_UMC_to_Keep,
				@MinimumMatchScore = Minimum_Match_Score,
				@MinimumDelMatchScore = Minimum_Del_Match_Score,
				@MinimumUniquenessProbability = Minimum_Uniqueness_Probability,
 				@MaximumFDRThreshold = Maximum_FDR_Threshold,
				@MinimumPeptideReplicateCount = Minimum_Peptide_Replicate_Count,
				@ORFCoverageComputationLevel = ORF_Coverage_Computation_Level,
				@PctSmallDataToDiscard = RepNormalization_PctSmallDataToDiscard, 
				@PctLargeDataToDiscard = RepNormalization_PctLargeDataToDiscard,
				@MinimumDataPointsForRegressionNormalization = RepNormalization_MinimumDataPointCount,
				@InternalStdInclusionMode = Internal_Std_Inclusion_Mode
		FROM	T_Quantitation_Description
		WHERE	Quantitation_ID = @QuantitationID
		--
		SELECT @myError = @@error, @myRowCount = @@RowCount
		--
		If @myError <> 0 
		Begin
			Set @message = 'Error while looking up parameters for Quantitation_ID = ' + @QuantitationIDText + ' in table T_Quantitation_Description'
			Set @myError = 115
			Goto Done
		End

		-- Validate @InternalStdInclusionMode
		Set @InternalStdInclusionMode = IsNull(@InternalStdInclusionMode, 1)
		If @InternalStdInclusionMode < 0 Or @InternalStdInclusionMode > 2
			Set @InternalStdInclusionMode = 1

		If @MatchScoreModeMin = 0
		Begin
			-- The Match_Score column contains SLiC Score values
			-- Override the settings for Uniqueness Probability and FDR Threshold (since these don't apply when using SLiC Score values)
			Set @MinimumUniquenessProbability = 0
			Set @MaximumFDRThreshold = 1
		End
		Else
		Begin
			-- The Match_Score column contains STAC Score values
				
			-- If @MaximumFDRThreshold is non-zero (but less than 1), then change @MinimumMatchScore to 0 so that we only filter on FDR
			If @MaximumFDRThreshold > 0 AND @MaximumFDRThreshold < 1
				Set @MinimumMatchScore = 0
			Else
				-- @MaximumFDRThreshold is 0; change it to 1
				Set @MaximumFDRThreshold = 1

		End

		-----------------------------------------------------------
		-- Step 3b
		--
		-- Create the temporary tables required by the various sub-procedures
		-----------------------------------------------------------
		
		Set @CurrentLocation = 'Create the temporary tables'
		
		if exists (select * from dbo.sysobjects where id = object_id(N'[#UMCMatchResultsByJob]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [#UMCMatchResultsByJob]
			
		CREATE TABLE #UMCMatchResultsByJob (
			[UniqueID] int IDENTITY (1, 1) NOT NULL ,
			[Job] int NOT NULL ,
			[TopLevelFraction] smallint NOT NULL ,
			[Fraction] smallint NOT NULL ,
			[Replicate] smallint NOT NULL ,
			[InternalStdMatch] tinyint NOT NULL ,
			[Mass_Tag_ID] int NOT NULL ,
			[Observed_By_MSMS_in_This_Dataset] tinyint NOT NULL ,
			[High_Normalized_Score] real NOT NULL ,
			[High_Discriminant_Score] real NOT NULL ,
			[High_Peptide_Prophet_Probability] real NOT NULL ,
			[PMT_Quality_Score] real NOT NULL ,
			[Mass_Tag_Mods] [varchar](50) NOT NULL ,
			[MTAbundance] float NOT NULL ,
			[MTAbundanceLightPlusHeavy] float NOT NULL ,
			[Member_Count_Used_For_Abu] int NOT NULL ,
			[UMCMatchCount] int NULL ,
			[UMCIonCountTotal] int NULL ,
			[UMCIonCountMatch] int NULL ,
			[UMCIonCountMatchInUMCsWithSingleHit] int NULL ,
			[FractionScansMatchingSingleMT] real NULL ,
			[UMCMultipleMTHitCountAvg] real NULL ,
			[UMCMultipleMTHitCountStDev] float NULL ,
			[UMCMultipleMTHitCountMin] int NULL ,
			[UMCMultipleMTHitCountMax] int NULL ,
			[AverageAbundanceAcrossReps] float NULL ,
			[MedianAbundanceAcrossReps] float NULL ,
			[Rank_Match_Score_Avg] float NULL ,
			[Match_Score_Avg] float NULL ,
			[Del_Match_Score_Avg] float NULL ,
			[Uniqueness_Probability_Avg] float NULL ,
			[FDR_Threshold_Avg] float NULL ,
			[NET_Error_Obs_Avg] float NULL ,
			[NET_Error_Pred_Avg] float null ,
			[ER_WeightedAvg] float NULL ,
			[ER_StDev] float NULL ,
			[ER_Charge_State_Basis_Count_Avg] real NOT NULL ,
			[MTAbundanceLight] float NOT NULL ,
			[MTAbundanceHeavy] float NOT NULL ,
			[ER_Recomputed] float NOT NULL ,
			[ER_ToUse] float NOT NULL ,
			[ScanMinimum] int NOT NULL ,
			[ScanMaximum] int NOT NULL ,
			[NET_Minimum] real NOT NULL ,
			[NET_Maximum] real NOT NULL ,
			[Class_Stats_Charge_Basis_Avg] real NOT NULL ,
			[Charge_State_Min] smallint NOT NULL ,
			[Charge_State_Max] smallint NOT NULL ,
			[MassErrorPPMAvg] float NOT NULL ,
			[UseValue] tinyint NOT NULL 
		) ON [PRIMARY]

		-- This used to be a Unique Primary Key (PK__UMCMatchResultsByJob) but that can lead to name collisions if this
		-- stored procedure is called more than once simultaneously; thus, we've switched to a Unique Clustered Index
		CREATE UNIQUE CLUSTERED INDEX #IX__TempTable__UMCMatchResultsByJob_UniqueID ON #UMCMatchResultsByJob([UniqueID]) ON [PRIMARY]


		if exists (select * from dbo.sysobjects where id = object_id(N'[#UMCMatchResultsSummary]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [#UMCMatchResultsSummary]

		CREATE TABLE #UMCMatchResultsSummary (
			[Ref_ID] int NOT NULL ,
			[InternalStdMatch] tinyint NOT NULL ,
			[Mass_Tag_ID] int NOT NULL ,
			[Mass_Tag_Mods] [varchar](50) NOT NULL ,
			[JobCount_Observed_Both_MS_and_MSMS] int NULL ,
			[Protein_Count] int NOT NULL ,
			[PMT_Quality_Score] real NOT NULL ,
			[Cleavage_State] tinyint NULL ,					-- This needs to be NULL in case a mass tag hasn't yet been processed by NamePeptides
			[Fragment_Span] smallint NULL ,					-- This needs to be NULL in case a mass tag hasn't yet been processed by NamePeptides
			[MTAbundanceAvg] float NULL ,						-- Sum of MT Abundance values across fractions
			[MTAbundanceStDev] float NULL ,					-- Standard deviation for a sum of numbers = Sqrt(Sum(StDevs^2))
			[MTAbundanceLightPlusHeavyAvg] float NULL ,
			[Member_Count_Used_For_Abu_Avg] float NOT NULL ,
			[Rank_Match_Score_Avg] float NULL ,
			[Match_Score_Avg] float NULL ,
			[Del_Match_Score_Avg] float NULL ,
			[Uniqueness_Probability_Avg] float NULL ,
			[FDR_Threshold_Avg] float NULL ,
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
			[Charge_State_Min] smallint NOT NULL ,
			[Charge_State_Max] smallint NOT NULL ,
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
			[FractionCountAvg] real NULL ,
			[FractionMin] smallint NULL ,
			[FractionMax] smallint NULL ,
			[TopLevelFractionCount] smallint NULL ,
			[TopLevelFractionMin] smallint NULL ,
			[TopLevelFractionMax] smallint NULL ,
			[MaxClassAbundanceThisRef] float NULL ,
			[Used_For_Abundance_Computation] tinyint NULL
		) ON [PRIMARY]

		CREATE  CLUSTERED  INDEX #IX__TempTable__UMCMatchResultsSummary_Ref_ID ON #UMCMatchResultsSummary([Ref_ID]) ON [PRIMARY]
		CREATE  INDEX #IX__TempTable__UMCMatchResultsSummary_Mass_Tag_ID ON #UMCMatchResultsSummary([Mass_Tag_ID]) ON [PRIMARY]


		if exists (select * from dbo.sysobjects where id = object_id(N'[#ProteinAbundanceSummary]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [#ProteinAbundanceSummary]

		CREATE TABLE #ProteinAbundanceSummary (
			[Ref_ID] int NOT NULL ,
			[ReplicateCountAvg] real NULL ,
			[ReplicateCountStDev] real NULL ,
			[ReplicateCountMax] smallint NULL ,
			[FractionCountAvg] real NULL ,
			[FractionCountMax] smallint NULL ,
			[TopLevelFractionCountAvg] real NULL ,
			[TopLevelFractionCountMax] smallint NULL ,
			[ObservedMassTagCount] int NULL ,
			[ObservedInternalStdCount] int NULL ,
			[Mass_Error_PPM_Avg] float NULL ,
			[Protein_Count_Avg] real NULL ,
			[Full_Enzyme_Count] int NULL ,
			[Full_Enzyme_No_Missed_Cleavage_Count] int NULL ,
			[Partial_Enzyme_Count] int NULL ,
			[MassTagCountUsedForAbundanceAvg] int NULL ,
			[MassTagMatchingIonCount] int NULL ,
			[MassTagMatchingIonCountInUMCsWithSingleHitCount] int NULL ,
			[FractionScansMatchingSingleMassTag] real NULL ,
			[MT_Count_Unique_Observed_Both_MS_and_MSMS] int NULL ,
			[UMCMultipleMTHitCountAvg] real NULL ,
			[UMCMultipleMTHitCountStDev] float NULL ,
			[UMCMultipleMTHitCountMin] int NULL ,
			[UMCMultipleMTHitCountMax] int NULL ,
			[Abundance_Average] float NULL ,
			[Abundance_Minimum] float NULL ,
			[Abundance_Maximum] float NULL ,
			[Abundance_StDev] float NULL ,
			[Rank_Match_Score_Avg] float NULL ,
			[Match_Score_Avg] float NULL ,
			[ER_Average] float NULL ,
			[ER_Minimum] float NULL ,
			[ER_Maximum] float NULL ,
			[ER_StDev] float NULL ,
			[Protein_Coverage_Residue_Count] int NULL ,
			[Protein_Coverage_Fraction] real NULL ,
			[Protein_Coverage_Fraction_High_Abundance] real NULL ,
			[Potential_Protein_Coverage_Residue_Count] int NULL ,
			[Potential_Protein_Coverage_Fraction] real NULL ,
			[Potential_Full_Enzyme_Count] int NULL ,
			[Potential_Partial_Enzyme_Count] int NULL
		) ON [PRIMARY]

		--
		-- Add an index on the Ref_ID column
		--
		CREATE CLUSTERED INDEX #IX__TempTable__ProteinAbundanceSummary ON #ProteinAbundanceSummary ([Ref_ID])


		-----------------------------------------------------------
		-- Step 4
		--
		-- Determine the number of UMCs that have one or more matches that pass the various filters
		-- This value is reported as an overall quality statistic
		-- This value does not account for any outlier filtering that may occur later on
		-----------------------------------------------------------

		Set @CurrentLocation = 'Call QuantitationProcessWorkStepA for ' + @QuantitationIDText
		--
		exec @myError = QuantitationProcessWorkStepA 
							@QuantitationID, @InternalStdInclusionMode, 
							@MinimumMTHighNormalizedScore, @MinimumMTHighDiscriminantScore,
 							@MinimumMTPeptideProphetProbability, @MinimumPMTQualityScore,
							@MinimumPeptideLength, @MinimumMatchScore, @MinimumDelMatchScore,
							@MinimumUniquenessProbability, @MaximumFDRThreshold,
							@message output
		If @myError <> 0
			Goto Done

		-----------------------------------------------------------
		-- Step 5
		--
		-- In order to speed up the following queries, it is advantageous to copy the 
		-- UMC match results for the corresponding MD_ID's to a temporary table
		--
		-- When creating the table, we combine the data from T_FTICR_UMC_Results
		--  and T_FTICR_UMC_ResultDetails
		--
		-----------------------------------------------------------
		
		Set @CurrentLocation = 'Call QuantitationProcessWorkStepB for ' + @QuantitationIDText
		--
		exec @myError = QuantitationProcessWorkStepB 
							@QuantitationID,
							@InternalStdInclusionMode,
							@UMCAbundanceMode, @ERMode,
							@MinimumMTHighNormalizedScore, @MinimumMTHighDiscriminantScore,
							@MinimumMTPeptideProphetProbability, @MinimumPMTQualityScore,
							@MinimumPeptideLength, @MaximumMatchesPerUMCToKeep,
							@MinimumMatchScore, @MinimumDelMatchScore,
							@MinimumUniquenessProbability, @MaximumFDRThreshold,
							@message output
		If @myError <> 0
			Goto Done
		
		-----------------------------------------------------------
		-- Step 6
		--
		-- Normalize the abundances if requested
		-- We first use StandardAbundanceMax and StandardAbundanceMin to scale all of the data
		-- Then, for each fraction that has replicates, we normalize each of the replicates to the first replicate
		--
		-----------------------------------------------------------

		Set @CurrentLocation = 'Call QuantitationProcessWorkStepC for ' + @QuantitationIDText
		--
		exec @myError = QuantitationProcessWorkStepC
							@QuantitationID,
							@NormalizeAbundances, @NormalizeReplicateAbu,
							@StandardAbundanceMin, @StandardAbundanceMax, @StandardAbundanceRange,
							@PctSmallDataToDiscard,	@PctLargeDataToDiscard,
							@MinimumDataPointsForRegressionNormalization,
							@message output
		If @myError <> 0
			Goto Done


		-----------------------------------------------------------
		-- Step 6.5
		--
		-- Possibly remove peptides that aren't present in the minimum number of replicates
		-- 
		If @MinimumPeptideReplicateCount > 0
		Begin
			DELETE #UMCMatchResultsByJob
			FROM #UMCMatchResultsByJob AS M INNER JOIN
				(SELECT TopLevelFraction, Fraction, InternalStdMatch, Mass_Tag_ID, Mass_Tag_Mods
				FROM #UMCMatchResultsByJob
				GROUP BY TopLevelFraction, Fraction, InternalStdMatch, Mass_Tag_ID, Mass_Tag_Mods
				HAVING Count([Replicate]) < @MinimumPeptideReplicateCount
				) AS N ON	M.TopLevelFraction = N.TopLevelFraction AND
							M.Fraction = N.Fraction AND
							M.InternalStdMatch = N.InternalStdMatch AND
							M.Mass_Tag_ID = N.Mass_Tag_ID AND
							M.Mass_Tag_Mods = N.Mass_Tag_Mods
				
			--
			SELECT @myError = @@error, @myRowCount = @@RowCount
			--
		End


		-----------------------------------------------------------
		-- Step 7
		--
		-- Optionally, filter out the outliers
		-- This can only be done with replicate data
		-----------------------------------------------------------

		Set @CurrentLocation = 'Call QuantitationProcessWorkStepD for ' + @QuantitationIDText
		--
		exec @myError = QuantitationProcessWorkStepD 
							@QuantitationID,
							@RemoveOutlierAbundancesForReplicates,
							@FractionCrossReplicateAvgInRange,
							@AddBackExcludedMassTags,
							@message output

		If @myError <> 0
			Goto Done


		-----------------------------------------------------------
		-- Step 9
		--
		-- Compute the average abundance for each mass tag (aka peptide)
		-----------------------------------------------------------
		
		Set @CurrentLocation = 'Call QuantitationProcessWorkStepE for ' + @QuantitationIDText
		--
		exec @myError = QuantitationProcessWorkStepE
							@QuantitationID, @InternalStdInclusionMode, 
							@message output
		If @myError <> 0
			Goto Done
		
		
		-----------------------------------------------------------
		-- Step 12
		--
		-- Compute the Protein Abundances and other stats for each Protein
		-- We do this using several SQL Update and Insert Into statements
		-----------------------------------------------------------

		Set @CurrentLocation = 'Call QuantitationProcessWorkStepF for ' + @QuantitationIDText
		--
		exec @myError = QuantitationProcessWorkStepF
							@QuantitationID,
							@FractionHighestAbuToUse,				-- Fraction of highest abundance mass tag for given ORF to use when computing ORF abundance (0.0 to 1.0)
							@MinimumMTHighNormalizedScore, @MinimumMTHighDiscriminantScore,
 							@MinimumMTPeptideProphetProbability, @MinimumPMTQualityScore,
 							@MinimumPotentialPMTQualityScore output,
							@message output
		If @myError <> 0
			Goto Done

		-----------------------------------------------------------
		-- Step 13
		--
		-- Compute Protein Coverage
		-----------------------------------------------------------

		If @ORFCoverageComputationLevel > 0
		Begin
			Set @CurrentLocation = 'Call QuantitationProcessWorkStepG for ' + @QuantitationIDText
			--
			exec @myError = QuantitationProcessWorkStepG @MinimumPotentialPMTQualityScore, @message output
			If @myError <> 0
				Goto Done
		End

		-----------------------------------------------------------
		-- Step 14
		--
		-- Append the Protein abundance results to T_Quantitation_Results
		-- and the list of mass tags observed to T_Quantitation_ResultDetails
		-----------------------------------------------------------

		Set @CurrentLocation = 'Call QuantitationProcessWorkStepH for ' + @QuantitationIDText
		--
		exec @myError = QuantitationProcessWorkStepH @QuantitationID, @message output
		If @myError <> 0
			Goto Done

		-- Uncomment the following to display the status message returned by QuantitationProcessWorkStepH
		--
		--Print @message
		--Select @message

	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'QuantitationProcessWork')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, @LogWarningErrorList = '',
								@ErrorNum = @myError output, @message = @message output
		Goto DoneSkipLog
	End Catch

Done:
	-----------------------------------------------------------
	-- Done processing
	-----------------------------------------------------------
		
	If @myError <> 0 
		Begin
			If Len(@message) > 0
				Set @message = ': ' + @message
			
			Set @message = 'Quantitation Processing Work Error ' + convert(varchar(19), @myError) + @message
			Execute PostLogEntry 'Error', @message, 'QuantitationProcessing'
			Print @message
		End
		
DoneSkipLog:			

	Return @myError

GO
GRANT EXECUTE ON [dbo].[QuantitationProcessWork] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[QuantitationProcessWork] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[QuantitationProcessWork] TO [MTS_DB_Lite] AS [dbo]
GO
