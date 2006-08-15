/****** Object:  StoredProcedure [dbo].[QuantitationProcessWork] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.QuantitationProcessWork
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
**
****************************************************/
(
	@QuantitationID int								-- Quantitation_ID to process 
)
AS
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	
	Declare	@ResultsCount int,
			@ReplicateCountEstimate int,
			@FeatureCountWithMatchesAvg int,		-- The number of UMCs in UMCMatchResultsByJob with UseValue = 1
			@MTMatchingUMCsCount int,				-- The number of Mass Tags in UMCMatchResultsByJob with UseValue = 1  (after outlier filtering)
			@MTMatchingUMCsCountFilteredOut int,	-- The number of Mass Tags in UMCMatchResultsByJob with UseValue = 0  (after outlier filtering)
			@UniqueMassTagCount int,				-- The number of Mass Tags in UMCMatchResultsByJob with at least one MT in 1 replicate with UseValue = 1
			@UniqueMassTagCountFilteredOut int,		-- The number of Mass Tags in UMCMatchResultsByJob with no MT's in any replicate with UseValue = 1
			@UniqueInternalStdCount int,					-- The number of Internal Std peptides in UMCMatchResultsByJob with at least one MT in 1 replicate with UseValue = 1
			@UniqueInternalStdCountFilteredOut int		-- The number of Internal Std peptides in UMCMatchResultsByJob with no MT's in any replicate with UseValue = 1

	set @ResultsCount = 0
	Set @ReplicateCountEstimate = 0
	Set @MTMatchingUMCsCount = 0
	Set @MTMatchingUMCsCountFilteredOut = 0
	Set @UniqueMassTagCount = 0
	Set @UniqueMassTagCountFilteredOut = 0
	Set @UniqueInternalStdCount = 0
	Set @UniqueInternalStdCountFilteredOut = 0
	
	Declare @message varchar(512)
	Declare @MessageNoResults varchar(512)
	
	Declare @RemoveOutlierAbundancesForReplicates tinyint,		-- If 1, use a filter to remove outliers (only possible with replicate data)
			@FractionCrossReplicateAvgInRange real,			-- Fraction plus or minus the average abundance across replicates for filtering out UMC's matching a given mass tag; it is allowable for this value to be greater than 1
			@AddBackExcludedMassTags tinyint,				-- If 1, means to not allow mass tags to be completely filtered out using the outlier filter
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
			@MinimumMTHighNormalizedScore real,			-- 0 to use all mass tags, > 0 to filter by XCorr
			@MinimumMTHighDiscriminantScore real,		-- 0 to use all mass tags, > 0 to filter by Discriminant Score
			@MinimumPMTQualityScore real,				-- 0 to use all mass tags, > 0 to filter by PMT Quality Score (as currently set in T_Mass_Tags)
			@MinimumPeptideLength tinyint,				-- 0 to use all mass tags, > 0 to filter by peptide length
			@MinimumMatchScore real,					-- 0 to use all mass tag matches, > 0 to filter by Match Score (aka SLiC Score, which indicates the uniqueness of a given mass tag matching a given UMC)
			@MinimumDelMatchScore real,					-- 0 to use all mass tag matches, > 0 to filter by Del Match Score (aka Del SLiC Score); only used if @MinimumMatchScore is > 0
			@MinimumPeptideReplicateCount tinyint,		-- 0 or 1 to filter out nothing; 2 or higher to filter out peptides not seen in the given number of replicates
			@ORFCoverageComputationLevel tinyint,		-- 0 for no ORF coverage, 1 for observed ORF coverage, 2 for observed and potential ORF coverage; option 2 is very CPU intensive for large databases
			@InternalStdInclusionMode tinyint				-- 0 for no NET lockers, 1 for PMT tags and NET Lockers, 2 for NET lockers only
 	
 	-- Note: These defaults get overridden below during the 
 	--	   Select From T_Quantitation_Description call
 	Set @RemoveOutlierAbundancesForReplicates = 1
 	Set @FractionCrossReplicateAvgInRange = 0.8
 	Set @AddBackExcludedMassTags = 0
 	Set @ERMode = 0
 	Set @MinimumMTHighNormalizedScore = 0
 	Set @MinimumMTHighDiscriminantScore = 0
 	Set @MinimumPMTQualityScore = 0
	Set @MinimumPeptideLength = 4
 	Set @MinimumMatchScore = 0
 	Set @MinimumDelMatchScore = 0
 	Set @MinimumPeptideReplicateCount = 0
 	Set @ORFCoverageComputationLevel = 1
	Set @InternalStdInclusionMode = 1
	
	-- Variables for regression-based normalization
	Declare @TopLevelFractionWork smallint,
			@FractionWork smallint,
			@RegressionSourceID int,
			@ReplicateValue smallint

	Declare @StatSumXY float,
			@StatSumX float, 
			@StatSumY float, 
			@StatSumXX float, 
			@StatDataCount int,
			@StatDenominator float,
			@StatM float,
			@StatB float,
			@StatSql varchar(1024),
			@StatMathSummary varchar(1024),
			@StatsAreValid tinyint

	Declare @PctSmallDataToDiscard tinyint,
			@PctLargeDataToDiscard tinyint,
			@NumSmallDataToDiscard smallint,
			@NumLargeDataToDiscard smallint,
			@MinimumDataPointsForRegressionNormalization smallint,
			@StatMinimumM float,
			@StatMaximumM float,
			@StatMinimumB float,
			@StatMaximumB float
			
	Set @PctSmallDataToDiscard = 10								-- Percentage, between 0 and 99
	Set @PctLargeDataToDiscard = 5								-- Percentage, between 0 and 99
	Set @MinimumDataPointsForRegressionNormalization = 10		-- Number, 2 or larger
	Set @StatMathSummary = ''
	Set @StatsAreValid = 0
	
	Set @StatMinimumM = 0.01									-- Minimum slope value
	Set @StatMaximumM = 100										-- Maximum slope value
	Set @StatMinimumB = -100									-- Minimum y-intercept value
	Set @StatMaximumB = 100										-- Maximum y-intercept value
 	
 	-- Variables for peptide and ORF Coverage computation
 	Declare @LastRefID int,
 			@ProteinCoverageResidueCount int,
 			@ProteinCoverageResidueCountHighAbu int,
 			@PotentialProteinCoverageResidueCount int,
 			@PotentialProteinCoverageFraction float,
 			@ProteinSequenceLength int,
 			@ProteinProcessingDone tinyint,
 			@RegExSPExists int,
 			@Protein_Sequence varchar(8000),
 			@Protein_Sequence_HighAbu varchar(8000),
 			@Protein_Sequence_Full varchar(8000)

 	Declare	@MinimumPotentialMTHighNormalizedScore real,
 			@MinimumPotentialMTHighDiscriminantScore real,
 			@MinimumPotentialPMTQualityScore real,
			@MinMTHighNormalizedScoreCompare real,
			@MinMTHighDiscriminantScoreCompare real,
			@MinPMTQualityScoreCompare real
 	 	
	-----------------------------------------------------------
	-- Step 1
	--
	-- Delete existing results for @QuantitationID in T_Quantitation_Results
	-- Note that deletes will cascade into T_Quantitation_ResultDetails
	-- via the foreign key relationship on QR_ID
	-----------------------------------------------------------
	--
	DELETE FROM	T_Quantitation_Results
	WHERE		Quantitation_ID = @QuantitationID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	If @myError <> 0 
	Begin
		Set @message = 'Error while deleting rows from T_Quantitation_Results and T_Quantitation_ResultDetails with Quantitation_ID = ' + convert(varchar(19), @QuantitationID)
		Set @myError = 111
		Goto Done
	End
	
	
	-----------------------------------------------------------
	-- Step 2
	--
	-- Make sure one or more MD_ID values is present in T_Quantitation_MDIDs
	-----------------------------------------------------------
	--
	SELECT	@ReplicateCountEstimate = Count (Distinct [Replicate])
	FROM	T_Quantitation_MDIDs
	WHERE	Quantitation_ID = @QuantitationID
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
		Set @message = 'Could not find any MDIDs in T_Quantitation_MDIDs matching Quantitation_ID = ' + convert(varchar(19), @QuantitationID)
		Set @myError = 113
		Goto Done
	End


	-----------------------------------------------------------
	-- Step 3
	--
	-- Lookup the values for Outlier filtering, @FractionHighestAbuToUse,
	--  and the Normalization options in table T_Quantitation_Description
	-----------------------------------------------------------
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
			@MinimumPMTQualityScore = Minimum_PMT_Quality_Score,
			@MinimumPeptideLength = Minimum_Peptide_Length,
			@MinimumMatchScore = Minimum_Match_Score,
			@MinimumDelMatchScore = Minimum_Del_Match_Score,
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
		Set @message = 'Error while looking up parameters for Quantitation_ID = ' + convert(varchar(19), @QuantitationID) + ' in table T_Quantitation_Description'
		Set @myError = 114
		Goto Done
	End

	-- Validate @InternalStdInclusionMode
	Set @InternalStdInclusionMode = IsNull(@InternalStdInclusionMode, 1)
	If @InternalStdInclusionMode < 0 Or @InternalStdInclusionMode > 2
		Set @InternalStdInclusionMode = 1



	-----------------------------------------------------------
	-- Step 4
	--
	-- Determine the number of UMCs that have one or more matches that pass the various filters
	-- This value is reported as an overall quality statistic
	-- This value does not account for any outlier filtering that may occur later on in this procedure
	-----------------------------------------------------------

	if exists (select * from dbo.sysobjects where id = object_id(N'[#MatchingUMCIndices]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	drop table [#MatchingUMCIndices]

	CREATE TABLE #MatchingUMCIndices (
		[MD_ID] int NOT NULL ,
		[UMC_Ind] int NOT NULL
	) ON [PRIMARY]

	If @InternalStdInclusionMode = 0 OR @InternalStdInclusionMode = 1
	Begin
		INSERT INTO #MatchingUMCIndices (MD_ID, UMC_Ind)
		SELECT DISTINCT TMDID.MD_ID, R.UMC_Ind
		FROM T_Quantitation_MDIDs TMDID INNER JOIN
			 T_FTICR_UMC_Results R ON TMDID.MD_ID = R.MD_ID INNER JOIN
			 T_FTICR_UMC_ResultDetails RD ON R.UMC_Results_ID = RD.UMC_Results_ID INNER JOIN
			 T_Mass_Tags MT ON RD.Mass_Tag_ID = MT.Mass_Tag_ID LEFT OUTER JOIN
			 T_Mass_Tags_NET MTN ON RD.Mass_Tag_ID = MTN.Mass_Tag_ID
		WHERE	TMDID.Quantitation_ID = @QuantitationID AND 
				RD.Match_State = 6 AND
				ISNULL(MT.High_Normalized_Score, 0) >= @MinimumMTHighNormalizedScore AND 
				ISNULL(MT.High_Discriminant_Score, 0) >= @MinimumMTHighDiscriminantScore AND 
				ISNULL(MT.PMT_Quality_Score, 0) >= @MinimumPMTQualityScore AND 
				ISNULL(RD.Match_Score, -1) >= @MinimumMatchScore AND 
				ISNULL(RD.Del_Match_Score, 0) >= @MinimumDelMatchScore AND
				LEN(MT.Peptide) >= @MinimumPeptideLength
		--
		SELECT @myError = @@error, @myRowCount = @@RowCount
		--
		If @myError <> 0 
		Begin
			Set @message = 'Error while populating the #MatchingUMCIndices temporary table from T_FTICR_UMC_ResultDetails'
			Set @myError = 115
			Goto Done
		End
	End
	    

	If @InternalStdInclusionMode = 1 OR @InternalStdInclusionMode = 2
	Begin
		INSERT INTO #MatchingUMCIndices (MD_ID, UMC_Ind)
		SELECT DISTINCT TMDID.MD_ID, R.UMC_Ind
		FROM T_Quantitation_MDIDs TMDID INNER JOIN
			 T_FTICR_UMC_Results R ON TMDID.MD_ID = R.MD_ID INNER JOIN
			 T_FTICR_UMC_InternalStdDetails ISD ON R.UMC_Results_ID = ISD.UMC_Results_ID INNER JOIN
			 T_Mass_Tags MT ON ISD.Seq_ID = MT.Mass_Tag_ID
		WHERE	TMDID.Quantitation_ID = @QuantitationID AND 
				ISD.Match_State = 6 AND
				ISNULL(ISD.Match_Score, -1) >= @MinimumMatchScore AND 
				ISNULL(ISD.Del_Match_Score, 0) >= @MinimumDelMatchScore AND
				LEN(MT.Peptide) >= @MinimumPeptideLength
		--
		SELECT @myError = @@error, @myRowCount = @@RowCount
		--
		If @myError <> 0 
		Begin
			Set @message =  'Error while populating the #MatchingUMCIndices temporary table from T_FTICR_UMC_InternalStdDetails'
			Set @myError = 116
			Goto Done
		End
   	End
	
	Set @FeatureCountWithMatchesAvg = 0
	SELECT @FeatureCountWithMatchesAvg = Avg(DistinctUMCCount)
	FROM (	SELECT MD_ID, COUNT(DISTINCT UMC_Ind) AS DistinctUMCCount
			FROM #MatchingUMCIndices
			GROUP BY MD_ID
		 ) LookupQ
	--
	SELECT @myError = @@error, @myRowCount = @@RowCount
	--
	If @myError <> 0 
	Begin
		Set @message = 'Error while computing the average Feature Count with Matches value'
		Set @myError = 117
		Goto Done
	End

	If @myRowCount = 0
		Set @FeatureCountWithMatchesAvg = 0

	-----------------------------------------------------------
	-- Step 5
	--
	-- In order to speed up the following queries, it is advantageous to copy the 
	-- UMC match results for the corresponding MD_ID's to a temporary table
	--
	-- When creating the table, we combine the data from T_FTICR_UMC_Results
	--  and T_FTICR_UMC_ResultDetails
	--
	-- When populating this table, we sum the abundances for multiple UMC's in the
	--  same job that matched the same peptide; first, though, we'll copy the
	-- raw data into #UMCMatchResultsSoure.  We need to this first because the 
	-- MTAbundance column can contain data from either Class_Abundance or Abundance_Max
	-- and we also want to compute MTAbundanceLightPlusHeavy
	--
	-----------------------------------------------------------
	--
	-- Step 5a
	--
	-- Define the fields for the temporary table that will hold the source data for the #UMCMatchResultsByJob table

	if exists (select * from dbo.sysobjects where id = object_id(N'[#UMCMatchResultsSource]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	drop table [#UMCMatchResultsSource]

	CREATE TABLE #UMCMatchResultsSource (
		[TopLevelFraction] smallint NOT NULL ,
		[Fraction] smallint NOT NULL ,
		[Replicate] smallint NOT NULL ,
		[InternalStdMatch] tinyint NOT NULL ,
		[Mass_Tag_ID] int NOT NULL ,
		[High_Normalized_Score] real NOT NULL ,
		[High_Discriminant_Score] real NOT NULL ,
		[PMT_Quality_Score] real NOT NULL ,
		[Mass_Tag_Mods] [varchar](50) NOT NULL ,
		[MTAbundance] float NOT NULL ,
		[MTAbundanceLightPlusHeavy] float NOT NULL ,
		[Member_Count_Used_For_Abu] int NOT NULL ,
		[UMC_Ind] int NOT NULL ,
		[Member_Count] int NOT NULL ,
		[Matching_Member_Count] int NOT NULL ,
		[Match_Score] float NOT NULL ,
		[Del_Match_Score] real NOT NULL ,
		[MassTag_Hit_Count] int NOT NULL ,
		[Scan_First] int NOT NULL ,
		[Scan_Last] int NOT NULL ,
		[ElutionTime] real NOT NULL ,
		[MT_Avg_GANET] float NULL ,
		[MT_PNET] float NULL ,
		[Expression_Ratio] float NOT NULL ,
		[Expression_Ratio_StDev] float NULL ,
		[Expression_Ratio_Charge_State_Basis_Count] smallint NULL ,
		[Class_Stats_Charge_Basis] smallint NOT NULL ,
		[Charge_State_Min] smallint NOT NULL ,
		[Charge_State_Max] smallint NOT NULL ,
		[MassErrorPPM] float NOT NULL
	) ON [PRIMARY]

	If @InternalStdInclusionMode = 0 OR @InternalStdInclusionMode = 1
	Begin
		--
		-- Step 5b - Populate the temporary table with PMT tag matches
		--
		INSERT INTO #UMCMatchResultsSource
			(TopLevelFraction, 
			Fraction, 
			[Replicate], 
			InternalStdMatch,
			Mass_Tag_ID, 
			High_Normalized_Score,
			High_Discriminant_Score,
			PMT_Quality_Score,
			Mass_Tag_Mods,
			MTAbundance, 
			MTAbundanceLightPlusHeavy,
			Member_Count_Used_For_Abu,
			UMC_Ind,
			Member_Count, 
			Matching_Member_Count,
			Match_Score,
			Del_Match_Score,
			MassTag_Hit_Count,
			Scan_First,
			Scan_Last,
			ElutionTime,
			MT_Avg_GANET,
			MT_PNET,
			Expression_Ratio,
			Expression_Ratio_StDev,
			Expression_Ratio_Charge_State_Basis_Count,
			Class_Stats_Charge_Basis,
			Charge_State_Min,
			Charge_State_Max,
			MassErrorPPM)
		SELECT	TMDID.TopLevelFraction, 
				TMDID.Fraction, 
				TMDID.[Replicate], 
				0 AS InternalStdMatch,
				RD.Mass_Tag_ID,
				IsNull(MT.High_Normalized_Score,0),
				IsNull(MT.High_Discriminant_Score,0),
				IsNull(MT.PMT_Quality_Score,0),
				RD.Mass_Tag_Mods,
							
				CASE WHEN @UMCAbundanceMode = 0 
				THEN IsNull(R.Class_Abundance,0)			-- Use the defined abundance value
				ELSE IsNull(R.Abundance_Max,0)				-- Use maximum abundance for peak
				END,		-- MTAbundance 

				CASE WHEN ABS(IsNull(R.Expression_Ratio,0)) < 1E100 AND ABS(IsNull(R.Expression_Ratio,0)) > 1E-10
				THEN
					CASE WHEN @UMCAbundanceMode = 0 
					THEN IsNull(R.Class_Abundance,0) + IsNull(R.Class_Abundance,0) / R.Expression_Ratio
					ELSE IsNull(R.Abundance_Max,0) + IsNull(R.Abundance_Max,0) / R.Expression_Ratio
					END				
				ELSE 0
				END,		-- MTAbundanceLightPlusHeavy; Light Abu + Heavy Abu; Compute Heavy Abu using Light / ER; substitute, find Sum = Light + Light / ER
				
				IsNull(R.Member_Count_Used_For_Abu, 0),

				R.UMC_Ind,
				R.Member_Count,
				IsNull(RD.Matching_Member_Count, 0),
				IsNull(RD.Match_Score, -1),
				IsNull(RD.Del_Match_Score, 0),
				
				R.MassTag_Hit_Count,
				R.Scan_First,
				R.Scan_Last,
				IsNull(R.ElutionTime, 0),										-- ElutionTime
				
				MTN.AVG_GANET,		-- MT_Avg_GANET: Average observed GANET for mass_tag_ID
				MTN.PNET,			-- MT_PNET: Predicted NET for mass_tag_ID

				CASE WHEN ABS(IsNull(R.Expression_Ratio,0)) < 1E+100 AND ABS(IsNull(R.Expression_Ratio,0)) > 1E-10
				THEN R.Expression_Ratio
				ELSE 0
				END,									-- Expression_Ratio; note: guaranteed after this point to be between 1E-10 and 1E+100, or 0

				CASE WHEN ABS(IsNull(R.Expression_Ratio,0)) < 1E+100 AND ABS(IsNull(R.Expression_Ratio,0)) > 1E-10
				THEN IsNull(R.Expression_Ratio_StDev, 0)
				ELSE 0
				END,									-- Expression_Ratio_StDev

				CASE WHEN ABS(IsNull(R.Expression_Ratio,0)) < 1E+100 AND ABS(IsNull(R.Expression_Ratio,0)) > 1E-10
				THEN IsNull(R.Expression_Ratio_Charge_State_Basis_Count, 0)
				ELSE 0
				END,									-- Expression_Ratio_Charge_State_Basis_Count
				
				IsNull(R.Class_Stats_Charge_Basis, 0),
				IsNull(R.Charge_State_Min, 0),
				IsNull(R.Charge_State_Max, 0),
				
				CASE WHEN IsNull(MT.Monoisotopic_Mass,0) > 0 
				THEN 1E6 * ((R.Class_Mass - RD.Mass_Tag_Mod_Mass) - MT.Monoisotopic_Mass) / MT.Monoisotopic_Mass		-- Mass Error PPM; correcting for mass mods by subtracting Mass_Tag_Mod_Mass
				ELSE 0 
				END
		FROM T_Quantitation_MDIDs AS TMDID
	   		INNER JOIN T_FTICR_UMC_Results AS R
				ON TMDID.MD_ID = R.MD_ID
			INNER JOIN T_FTICR_UMC_ResultDetails AS RD
				ON R.UMC_Results_ID = RD.UMC_Results_ID
			INNER JOIN T_Mass_Tags AS MT
				ON RD.Mass_Tag_ID = MT.Mass_Tag_ID
			LEFT OUTER JOIN T_Mass_Tags_NET AS MTN
				ON RD.Mass_Tag_ID = MTN.Mass_Tag_ID
		WHERE TMDID.Quantitation_ID = @QuantitationID AND RD.Match_State = 6			-- Only include matches with a state of 6 = Hit
		ORDER BY TMDID.TopLevelFraction, TMDID.Fraction, RD.Mass_Tag_ID, RD.Mass_Tag_Mods, RD.Mass_Tag_Mod_Mass, TMDID.[Replicate]
		--
		SELECT @myError = @@error, @myRowCount = @@RowCount
		--
		If @myError <> 0 
		Begin
			Set @message = 'Error while populating the #UMCMatchResultsSource temporary table from T_FTICR_UMC_ResultDetails'
			Set @myError = 118
			Goto Done
		End
		
		Set @ResultsCount = @ResultsCount + @myRowCount
	End

	If @InternalStdInclusionMode = 1 OR @InternalStdInclusionMode = 2
	Begin	
		--
		-- Step 5c - Populate the temporary table with the Internal Standard Matches
		--			 Do not add new matches for PMTs that are already present
		--
		INSERT INTO #UMCMatchResultsSource
			(TopLevelFraction, 
			Fraction, 
			[Replicate], 
			InternalStdMatch,
			Mass_Tag_ID, 
			High_Normalized_Score,
			High_Discriminant_Score,
			PMT_Quality_Score,
			Mass_Tag_Mods,
			MTAbundance, 
			MTAbundanceLightPlusHeavy,
			Member_Count_Used_For_Abu,
			UMC_Ind,
			Member_Count, 
			Matching_Member_Count,
			Match_Score,
			Del_Match_Score,
			MassTag_Hit_Count,
			Scan_First,
			Scan_Last,
			ElutionTime,
			MT_Avg_GANET,
			MT_PNET,
			Expression_Ratio,
			Expression_Ratio_StDev,
			Expression_Ratio_Charge_State_Basis_Count,
			Class_Stats_Charge_Basis,
			Charge_State_Min,
			Charge_State_Max,
			MassErrorPPM)
		SELECT	TMDID.TopLevelFraction, 
				TMDID.Fraction, 
				TMDID.[Replicate], 
				1 AS InternalStdMatch,
				ISD.Seq_ID,					-- Mass_Tag_ID
				IsNull(MT.High_Normalized_Score,0),
				IsNull(MT.High_Discriminant_Score,0),
				IsNull(MT.PMT_Quality_Score,0),
				'',							-- Mass_Tag_Mods
							
				CASE WHEN @UMCAbundanceMode = 0 
				THEN IsNull(R.Class_Abundance,0)			-- Use the defined abundance value
				ELSE IsNull(R.Abundance_Max,0)				-- Use maximum abundance for peak
				END,		-- MTAbundance 

				CASE WHEN ABS(IsNull(R.Expression_Ratio,0)) < 1E100 AND ABS(IsNull(R.Expression_Ratio,0)) > 1E-10
				THEN
					CASE WHEN @UMCAbundanceMode = 0 
					THEN IsNull(R.Class_Abundance,0) + IsNull(R.Class_Abundance,0) / R.Expression_Ratio
					ELSE IsNull(R.Abundance_Max,0) + IsNull(R.Abundance_Max,0) / R.Expression_Ratio
					END				
				ELSE 0
				END,		-- MTAbundanceLightPlusHeavy; Light Abu + Heavy Abu; Compute Heavy Abu using Light / ER; substitute, find Sum = Light + Light / ER
				
				IsNull(R.Member_Count_Used_For_Abu, 0),

				R.UMC_Ind,
				R.Member_Count,
				IsNull(ISD.Matching_Member_Count, 0),
				IsNull(ISD.Match_Score, -1),
				IsNull(ISD.Del_Match_Score, 0),
				
				R.MassTag_Hit_Count,
				R.Scan_First,
				R.Scan_Last,
				IsNull(R.ElutionTime, 0),										-- ElutionTime
				
				ISC.AVG_NET,		-- Average observed NET for the Internal Standard
				ISC.PNET,			-- Predicted NET for the Internal Standard

				CASE WHEN ABS(IsNull(R.Expression_Ratio,0)) < 1E+100 AND ABS(IsNull(R.Expression_Ratio,0)) > 1E-10
				THEN R.Expression_Ratio
				ELSE 0
				END,									-- Expression_Ratio; note: guaranteed after this point to be between 1E-10 and 1E+100, or 0

				CASE WHEN ABS(IsNull(R.Expression_Ratio,0)) < 1E+100 AND ABS(IsNull(R.Expression_Ratio,0)) > 1E-10
				THEN IsNull(R.Expression_Ratio_StDev, 0)
				ELSE 0
				END,									-- Expression_Ratio_StDev

				CASE WHEN ABS(IsNull(R.Expression_Ratio,0)) < 1E+100 AND ABS(IsNull(R.Expression_Ratio,0)) > 1E-10
				THEN IsNull(R.Expression_Ratio_Charge_State_Basis_Count, 0)
				ELSE 0
				END,									-- Expression_Ratio_Charge_State_Basis_Count
				
				IsNull(R.Class_Stats_Charge_Basis, 0),
				IsNull(R.Charge_State_Min, 0),
				IsNull(R.Charge_State_Max, 0),
				
				CASE WHEN IsNull(MT.Monoisotopic_Mass,0) > 0 
				THEN 1E6 * ((R.Class_Mass) - MT.Monoisotopic_Mass) / MT.Monoisotopic_Mass		-- Mass Error PPM; correcting for mass mods by subtracting Mass_Tag_Mod_Mass
				ELSE 0 
				END
		FROM T_Quantitation_MDIDs AS TMDID
	   		INNER JOIN T_FTICR_UMC_Results AS R
				ON TMDID.MD_ID = R.MD_ID
			INNER JOIN T_FTICR_UMC_InternalStdDetails AS ISD
				ON R.UMC_Results_ID = ISD.UMC_Results_ID
			INNER JOIN MT_Main..T_Internal_Std_Components AS ISC 
				ON ISD.Seq_ID = ISC.Seq_ID
			INNER JOIN T_Mass_Tags AS MT
				ON ISC.Seq_ID = MT.Mass_Tag_ID
			LEFT OUTER JOIN #UMCMatchResultsSource AS UMRS ON
				UMRS.TopLevelFraction = TMDID.TopLevelFraction AND
				UMRS.Fraction = TMDID.Fraction AND
				UMRS.[Replicate] = TMDID.[Replicate] AND
				UMRS.Mass_Tag_ID = ISD.Seq_ID
		WHERE TMDID.Quantitation_ID = @QuantitationID AND ISD.Match_State = 6			-- Only include matches with a state of 6 = Hit
			  AND UMRS.Mass_Tag_ID IS NULL
		ORDER BY TMDID.TopLevelFraction, TMDID.Fraction, ISD.Seq_ID, TMDID.[Replicate]
		--
		SELECT @myError = @@error, @myRowCount = @@RowCount
		--
		If @myError <> 0 
		Begin
			Set @message = 'Error while populating the #UMCMatchResultsSource temporary table from T_FTICR_UMC_InternalStdDetails'
			Set @myError = 119
			Goto Done
		End
		
		Set @ResultsCount = @ResultsCount + @myRowCount
	End

	--
	-- Step 5d - Possibly delete low scoring matches
	--
	If @MinimumMatchScore > 0 AND @ResultsCount > 0
	Begin
		-- Transact-SQL delete notation
		DELETE FROM #UMCMatchResultsSource
		WHERE NOT (Match_Score >= @MinimumMatchScore AND Del_Match_Score >= @MinimumDelMatchScore)
		--
		SELECT @myError = @@error, @myRowCount = @@RowCount
		--
		If @myError <> 0 
		Begin
			Set @message = 'Error removing the low scoring matches from the #UMCMatchResultsSource temporary table'
			Set @myError = 120
			Goto Done
		End
		--
		If @myRowCount > 0
		Begin
			SELECT @myRowCount = Count(Mass_Tag_ID)
			FROM #UMCMatchResultsSource
			--
			If @myRowCount = 0
			Begin
				-- Post an error message to T_Log_Entries
				set @message = 'All matching mass tags were filtered out by the Minimum_Match_Score (SLiC Score) value of ' + Convert(varchar(12), Round(@MinimumMatchScore, 3)) + ' and Minimum_Del_Match_Score of ' +  Convert(varchar(12), Round(@MinimumDelMatchScore, 3)) + ' for Quantitation_ID = ' + convert(varchar(19), @QuantitationID) + ' listed in T_Quantitation_MDIDs'
				set @myError = 121
				goto Done
			End
		End
	End
	
	--
	-- Step 5e
	--
	-- Define the fields for the temporary table that rolls up data by UMC
	-- Necessary to do this now since we need an IDENTITY field
	--
	if exists (select * from dbo.sysobjects where id = object_id(N'[#UMCMatchResultsByJob]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	drop table [#UMCMatchResultsByJob]
		
	CREATE TABLE #UMCMatchResultsByJob (
		[UniqueID] int IDENTITY (1, 1) NOT NULL ,
		[TopLevelFraction] smallint NOT NULL ,
		[Fraction] smallint NOT NULL ,
		[Replicate] smallint NOT NULL ,
		[InternalStdMatch] tinyint NOT NULL ,
		[Mass_Tag_ID] int NOT NULL ,
		[High_Normalized_Score] real NOT NULL ,
		[High_Discriminant_Score] real NOT NULL ,
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
		[Match_Score_Avg] float NULL ,
		[Del_Match_Score_Avg] float NULL ,
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
		[Charge_State_Min] tinyint NOT NULL ,
		[Charge_State_Max] tinyint NOT NULL ,
		[MassErrorPPMAvg] float NOT NULL ,
		[UseValue] tinyint NOT NULL 
	) ON [PRIMARY]

	-- This used to be a Unique Primary Key (PK__UMCMatchResultsByJob) but that can lead to name collisions if this
	-- stored procedure is called more than once simultaneously; thus, we've switched to a Unique Clustered Index
	CREATE UNIQUE CLUSTERED INDEX #IX__TempTable__UMCMatchResultsByJob_UniqueID ON #UMCMatchResultsByJob([UniqueID]) ON [PRIMARY]

	--
	-- Step 5f - Populate the temporary table
	-- For now, we only rollup by UMC; we'll roll up by replicate, fraction,
	--  and top level fraction later
	--
	--
	INSERT INTO #UMCMatchResultsByJob
		(TopLevelFraction, 
		 Fraction, 
		 [Replicate], 
		 InternalStdMatch,
		 Mass_Tag_ID, 
		 High_Normalized_Score,
		 High_Discriminant_Score,
		 PMT_Quality_Score,
		 Mass_Tag_Mods,
		 MTAbundance, 
		 MTAbundanceLightPlusHeavy,
		 Member_Count_Used_For_Abu,
		 UMCMatchCount, 
		 UMCIonCountTotal, UMCIonCountMatch,

		 UMCIonCountMatchInUMCsWithSingleHit, FractionScansMatchingSingleMT,
		 UMCMultipleMTHitCountAvg, UMCMultipleMTHitCountStDev,
		 UMCMultipleMTHitCountMin, UMCMultipleMTHitCountMax,
		 Match_Score_Avg,
		 Del_Match_Score_Avg,
		 NET_Error_Obs_Avg,
		 NET_Error_Pred_Avg,
		 ER_WeightedAvg,					-- Weighted average expression ratio for given mass tag with several matching UMCs
		 ER_StDev,							-- Weighted average ER standard deviation
		 ER_Charge_State_Basis_Count_Avg,
		 MTAbundanceLight,
		 MTAbundanceHeavy,
		 ER_Recomputed,						-- Average ER for given mass tag with several matching UMCs; sum light UMC abundances and heavy UMC abundances, and re-compute average; compute below
		 ER_ToUse,
		 ScanMinimum,
		 ScanMaximum,
		 NET_Minimum,
		 NET_Maximum,
		 Class_Stats_Charge_Basis_Avg,
		 Charge_State_Min,
		 Charge_State_Max,
		 MassErrorPPMAvg,
		 UseValue)
	SELECT	TopLevelFraction, 
			Fraction, 
			[Replicate], 
			InternalStdMatch,
			Mass_Tag_ID,
			Max(High_Normalized_Score),
			Max(High_Discriminant_Score),
			Max(PMT_Quality_Score),
			Mass_Tag_Mods,
			Sum(MTAbundance),
			Sum(MTAbundanceLightPlusHeavy),
			SUM(Member_Count_Used_For_Abu),				-- Member_Count_Used_For_Abu; Sum, since we're summing MTAbundance
			COUNT(UMC_Ind),			-- UMCMatchCount
			SUM(Member_Count),		-- UMCIonCountTotal
			SUM(Matching_Member_Count),		-- UMCIonCountMatch
			-- The following is a conditional sum: we only sum Matching_Member_Count if
			--  MassTag_Hit_Count = 1
			SUM(	CASE WHEN MassTag_Hit_Count = 1
					THEN Matching_Member_Count
					ELSE 0
					END),									-- UMCIonCountMatchInUMCsWithSingleHit
			CONVERT(real, 0),						-- FractionScansMatchingSingleMT
			AVG(CONVERT(real, MassTag_Hit_Count)),
			STDEV(CONVERT(real, MassTag_Hit_Count)),	-- UMCMultipleMTHitCountStDev; this will be Null if only one UMC matched this mass tag
			MIN(MassTag_Hit_Count), 
			MAX(MassTag_Hit_Count),		-- UMCMultipleMTHitCountMax
			AVG(Match_Score),			-- Match_Score_Avg: Match_Score holds the likelihood of the match, a value between 0 and 1, or -1 if undefined
			AVG(Del_Match_Score),		-- Del_Match_Score_Avg: Del_Match_Score holds the distance of the given match to highest scoring match
			AVG(ElutionTime - IsNull(MT_Avg_GANET, ElutionTime)),		-- NET_Error_Obs_Avg
			AVG(ElutionTime - IsNull(MT_PNET, ElutionTime)),			-- NET_Error_Pred_Avg
			CASE WHEN SUM(MTAbundanceLightPlusHeavy) > 0
			THEN SUM(Expression_Ratio * MTAbundanceLightPlusHeavy) / SUM(MTAbundanceLightPlusHeavy)
			ELSE 0
			END,				-- ER_WeightedAvg; weighted average

			CASE WHEN SUM(MTAbundanceLightPlusHeavy) > 0
			THEN SQRT(SUM(SQUARE(Expression_Ratio_StDev) * MTAbundanceLightPlusHeavy) / SUM(MTAbundanceLightPlusHeavy))
			ELSE 0
			END,				-- ER_StDev; weighted average

			Avg(Convert(real, Expression_Ratio_Charge_State_Basis_Count)),		-- ER_Charge_State_Basis_Count_Avg

			SUM(CASE WHEN ABS(Expression_Ratio) > 0
				THEN MTAbundance						-- MTAbundanceLight: Sum of Light Abundance, but only if Expression_Ratio > 0
				ELSE 0
				END),
				
			SUM(CASE WHEN ABS(Expression_Ratio) > 0
				THEN MTAbundance / Expression_Ratio
				ELSE 0
				END),
			0,					-- ER_Recomputed; populated below
			0,					-- ER_ToUse; populated below
			Min(Scan_First),
			Max(Scan_Last),
			Min(ElutionTime),												-- NET_Minimum
			Max(ElutionTime),												-- NET_Maximum
			Avg(Convert(real, Class_Stats_Charge_Basis)),					-- Class_Stats_Charge_Basis_Avg
			Min(Charge_State_Min),
			Max(Charge_State_Max),
			AVG(MassErrorPPM),
			1					-- UseValue is initially set to 1; it will be changed to 0 below as needed if filtering out outliers
	FROM #UMCMatchResultsSource
	GROUP BY TopLevelFraction, Fraction, InternalStdMatch, Mass_Tag_ID, Mass_Tag_Mods, [Replicate]
	ORDER BY TopLevelFraction, Fraction, InternalStdMatch, Mass_Tag_ID, Mass_Tag_Mods, [Replicate]
	--
	SELECT @myError = @@error, @myRowCount = @@RowCount
	--
	If @myError <> 0 
	Begin
		Set @message = 'Error while populating the #UMCMatchResultsByJob temporary table'
		Set @myError = 122
		Goto Done
	End
	--
	
	set @MessageNoResults = ''
	set @MessageNoResults = @MessageNoResults + 'Could not find any results in '

	If @InternalStdInclusionMode = 0
		set @MessageNoResults = @MessageNoResults + 'T_FTICR_UMC_Results and T_FTICR_UMC_ResultDetails'
	Else
	Begin
		If @InternalStdInclusionMode = 1
			set @MessageNoResults = @MessageNoResults + 'T_FTICR_UMC_Results, T_FTICR_UMC_ResultDetails, and T_FTICR_UMC_InternalStdDetails'
		Else
			set @MessageNoResults = @MessageNoResults + 'T_FTICR_UMC_Results and T_FTICR_UMC_InternalStdDetails'
	End
	
	set @MessageNoResults = @MessageNoResults + ' corresponding to the MDID(s) for Quantitation_ID = ' + convert(varchar(19), @QuantitationID) + ' listed in T_Quantitation_MDIDs'
	
	
	If @myRowCount = 0
	Begin
		-- Post an error message to T_Log_Entries
		set @message = @MessageNoResults
		set @myError = 123
		goto Done
	End


	--
	-- Step 5g - Compute ER_Recomputed (Sum of light member of all UMCs for each mass tag divided by sum of heavy member of all UMCs for each mass tag)
	--
	UPDATE #UMCMatchResultsByJob
	SET ER_Recomputed = MTAbundanceLight / MTAbundanceHeavy
	WHERE MTAbundanceHeavy > 0
	--
	SELECT @myError = @@error, @myRowCount = @@RowCount
	--
	If @myError <> 0 
	Begin
		Set @message = 'Error while recomputing the Expression Ratio in the #UMCMatchResultsByJob temporary table'
		Set @myError = 124
		Goto Done
	End

	-- Copy the ER value into ER_ToUse
	If @ERMode = 0
	  Begin
		UPDATE #UMCMatchResultsByJob
		SET ER_ToUse = ER_Recomputed
	  End
	Else
	  Begin
		UPDATE #UMCMatchResultsByJob
		SET ER_ToUse = ER_WeightedAvg
	  End

	
	--
	-- Step 5h - Possibly delete hits that match mass tags with too low of a High_Normalized_Score
	--           or discriminant score or PMT Quality Score value
	--
	If @MinimumMTHighNormalizedScore > 0 OR @MinimumMTHighDiscriminantScore > 0 OR @MinimumPMTQualityScore > 0
	Begin
		DELETE FROM #UMCMatchResultsByJob
		WHERE InternalStdMatch = 0 AND 
			  (
				High_Normalized_Score < @MinimumMTHighNormalizedScore OR
				High_Discriminant_Score < @MinimumMTHighDiscriminantScore OR
				PMT_Quality_Score < @MinimumPMTQualityScore
			  )
		--
		SELECT @myError = @@error, @myRowCount = @@RowCount
		--
		If @myError <> 0
		Begin
			Set @message = 'Error removing the low score mass tags from the #UMCMatchResultsByJob temporary table'
			Set @myError = 125
			Goto Done
		End		
		--
		If @myRowCount > 0
		Begin
			SELECT @myRowCount = Count(*) FROM #UMCMatchResultsByJob
			--
			If @myRowCount = 0
			Begin
				-- Post an error message to T_Log_Entries
				set @message = 'All matching mass tags were filtered out by the Minimum MT High Normalized Score or Minimum PMT Quality Score for Quantitation_ID = ' + convert(varchar(19), @QuantitationID) + ' listed in T_Quantitation_MDIDs'
				set @myError = 126
				goto Done
			End
		End
	End

	--
	-- Step 5i - Possibly delete hits that match mass tags with peptide sequences that are too short
	--
	If @MinimumPeptideLength > 0
	Begin
		-- Transact-SQL delete notation
		DELETE #UMCMatchResultsByJob
		FROM #UMCMatchResultsByJob INNER JOIN 
			 T_Mass_Tags AS MT ON #UMCMatchResultsByJob.Mass_Tag_ID = MT.Mass_Tag_ID
		WHERE Len(MT.Peptide) < @MinimumPeptideLength
		--
		SELECT @myError = @@error, @myRowCount = @@RowCount
		--
		If @myError <> 0 
		Begin
			Set @message = 'Error removing the short peptides from the #UMCMatchResultsByJob temporary table'
			Set @myError = 127
			Goto Done
		End		
		--
		If @myRowCount > 0
		Begin
			SELECT @myRowCount = Count(*) FROM #UMCMatchResultsByJob
			--
			If @myRowCount = 0
			Begin
				-- Post an error message to T_Log_Entries
				set @message = 'All matching mass tags were filtered out by the Minimum Peptide Length value for Quantitation_ID = ' + convert(varchar(19), @QuantitationID) + ' listed in T_Quantitation_MDIDs'
				set @myError = 128
				goto Done
			End
		End
	End
	
	
	--
	-- Step 5j
	--
	-- Determine the percent of UMCs that matched just one mass tag (i.e. percent that had a unique match)
	-- In order to reflect larger UMCs that had a single match, we compute the percentage using:
	--  [Total number of matching ions (scans) in the UMC's for each mass tag wherein the UMC has MassTag_HitCount = 1]
	--	 divided by
	--  [Total number of matching ions (scans) in all UMC's for this mass tag]
	--

	-- The above two values are stored in UMCIonCountMatchInUMCsWithSingleHit and UMCIonCountMatch
	--  in the #UMCMatchResultsByJob temporary table, and were already obtained
	--  in the above Insert Into query.
	--	
	UPDATE #UMCMatchResultsByJob
	SET FractionScansMatchingSingleMT = 
		Convert(float, IsNull(UMCIonCountMatchInUMCsWithSingleHit, 0)) / 
		Convert(float, UMCIonCountMatch)
	WHERE UMCIonCountMatch > 0


	-----------------------------------------------------------
	-- Step 6
	--
	-- Normalize the abundances if requested
	-- We first use StandardAbundanceMax and StandardAbundanceMin to scale all of the data
	-- Then, for each fraction that has replicates, we normalize each of the replicates to the first replicate
	--
	-----------------------------------------------------------
	--
	-- Step 6a
	--
	If @NormalizeAbundances <> 0		-- <a> 
	 Begin
		Set @StandardAbundanceRange = @StandardAbundanceMax - @StandardAbundanceMin
		
		If @StandardAbundanceRange <= 0
			Set @StandardAbundanceRange = 1
		
		-- Each value is normalized by subtracting @StandardAbundanceMin, then
		--  dividing by @StandardAbundanceRange
		-- If the value minus @StandardAbundanceMin is less than 0, then the normalized
		--  abundance is simply 0.  The IsNull statement assures that no Null values
		-- are stored.

		UPDATE #UMCMatchResultsByJob
		SET MTAbundance = IsNull(	Case 
									When MTAbundance > @StandardAbundanceMin Then
										(MTAbundance - @StandardAbundanceMin) / @StandardAbundanceRange * 100
									Else 0
									End
									, 0)

		-- Step 6b
		--
		-- For each Fraction that has replicates, Normalize each of the replicates to the first replicate
		-- Do this by plotting the abundance of each mass tag in Replicate x (x = 2, 3, 4, etc.) vs. the abundance of the mass tag in Replicate 1
		-- and fitting a linear regression line, giving a line of the form y = m*x + b

		-- Normalizing Replicate Abundances is turned off for now
		Set @NormalizeReplicateAbu = 0
		If @NormalizeReplicateAbu <> 0	-- <b> 
		 Begin
			if exists (select * from dbo.sysobjects where id = object_id(N'[#RegressionSource]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
			drop table [#RegressionSource]
			
			CREATE TABLE #RegressionSource (
				[SourceID] int NOT NULL IDENTITY (1, 1),
				[TopLevelFraction] smallint NOT NULL ,
				[Fraction] smallint NOT NULL ,
				[ReplicateCount] smallint NOT NULL
			)

			if exists (select * from dbo.sysobjects where id = object_id(N'[#RegressionX]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
			drop table [#RegressionX]

			CREATE TABLE #RegressionX (
				[Mass_Tag_ID] int NOT NULL ,
				[Mass_Tag_Mods] [varchar](50) NOT NULL ,
				[MTAbundance] float NULL
			)
			CREATE INDEX #IX__TempTable__RegressionX ON #RegressionX([Mass_Tag_ID]) ON [PRIMARY]

			if exists (select * from dbo.sysobjects where id = object_id(N'[#RegressionY]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
			drop table [#RegressionY]

			CREATE TABLE #RegressionY (
				[Mass_Tag_ID] int NOT NULL ,
				[Mass_Tag_Mods] [varchar](50) NOT NULL ,
				[MTAbundance] float NULL
			)
			CREATE INDEX #IX__TempTable__RegressionY ON #RegressionY([Mass_Tag_ID]) ON [PRIMARY]

			if exists (select * from dbo.sysobjects where id = object_id(N'[#RegressionReplicateValues]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
			drop table [#RegressionReplicateValues]

			CREATE TABLE #RegressionReplicateValues (
				[Replicate] smallint NOT NULL
			)

			if exists (select * from dbo.sysobjects where id = object_id(N'[#RegressionStats]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
			drop table [#RegressionStats]

			CREATE TABLE #RegressionStats (
				[SumXY] float,
				[SumX] float,
				[SumY] float,
				[SumXX] float,
				[DataCount] int
			)

			-- Populate #RegressionSource
			
			INSERT INTO #RegressionSource
					(TopLevelFraction, Fraction, ReplicateCount)
			SELECT	TopLevelFraction, Fraction,
					Max([Replicate]) - Min([Replicate]) + 1
			FROM #UMCMatchResultsByJob
			GROUP BY TopLevelFraction, Fraction
			
			-- Remove any entries in #RegressionSource with a ReplicateCount of 1 or smaller
			DELETE FROM #RegressionSource
			WHERE ReplicateCount <=1
				
			Set @RegressionSourceID = 0
			While @RegressionSourceID >= 0		-- <c>
			Begin
				Set @RegressionSourceID = -1
		 
				-- Loop through the entries remaining in #RegressionSource and normalize the replicates for each one
				SELECT TOP 1 
						@RegressionSourceID = SourceID, 
						@TopLevelFractionWork = TopLevelFraction,
						@FractionWork = Fraction
				FROM #RegressionSource
				ORDER BY TopLevelFraction, Fraction
				--
				SELECT @myRowCount = @@RowCount
				
				If @myRowCount = 1 And @RegressionSourceID >= 0		-- <d>
				 Begin
					-- Obtain a list of the Replicate values for this TopLevelFraction and Fraction
					TRUNCATE TABLE #RegressionReplicateValues
					
					INSERT INTO #RegressionReplicateValues
							([Replicate])
					SELECT	[Replicate]
					FROM	#UMCMatchResultsByJob
					WHERE	TopLevelFraction = @TopLevelFractionWork AND 
							Fraction = @FractionWork
					GROUP BY [Replicate]
					ORDER BY [Replicate]
					
					-- Look up the minimum Replicate value
					SET @ReplicateValue = Null
					SELECT @ReplicateValue = MIN([Replicate]) 
					FROM #RegressionReplicateValues
					
					-- Populate #RegressionX
					TRUNCATE TABLE #RegressionX
					
					INSERT INTO #RegressionX
						(Mass_Tag_ID, Mass_Tag_Mods, MTAbundance)
					SELECT	Mass_Tag_ID, Mass_Tag_Mods, MTAbundance
					FROM	#UMCMatchResultsByJob
					WHERE	TopLevelFraction = @TopLevelFractionWork AND 
							Fraction = @FractionWork AND
							[Replicate] = @ReplicateValue

					-- Remove the minimum Replicate value from #RegressionReplicateValues
					DELETE FROM #RegressionReplicateValues
					WHERE [Replicate] = @ReplicateValue
					
					Set @ReplicateValue = 0
					While @ReplicateValue >=0	-- <e>
					Begin
						-- Look up the new minimum Replicate value
						SET @ReplicateValue = -1
						SELECT @ReplicateValue = MIN([Replicate])
						FROM #RegressionReplicateValues
						--
						SELECT @myRowCount = @@RowCount
						
						If @myRowCount = 1 And @ReplicateValue >=0		-- <f>
						Begin
							-- Populate #RegressionY
							TRUNCATE TABLE #RegressionY
							
							INSERT INTO #RegressionY
								(Mass_Tag_ID, Mass_Tag_Mods, MTAbundance)
							SELECT	Mass_Tag_ID, Mass_Tag_Mods, MTAbundance
							FROM	#UMCMatchResultsByJob
							WHERE	TopLevelFraction = @TopLevelFractionWork AND 
									Fraction = @FractionWork AND
									[Replicate] = @ReplicateValue
							
							-- Update @StatMathSummary
							If Len(@StatMathSummary) > 0
								Set @StatMathSummary = @StatMathSummary + ';'
							
							Set @StatMathSummary = @StatMathSummary + 'T' + LTrim(RTrim(convert(varchar(9), @TopLevelFractionWork)))
							Set @StatMathSummary = @StatMathSummary + 'F' + LTrim(RTrim(convert(varchar(9), @FractionWork)))
							Set @StatMathSummary = @StatMathSummary + 'R' + LTrim(RTrim(convert(varchar(9), @ReplicateValue))) + '='

							-- Perform the regression
							-- ToDo: Figure out how to compute the regression, fixing b = 0 (for y = mx + b)
							--
							-- Use the following to select the data to perform the regression on
							-- @PctDataToUseForNormalization is a value between 1 and 100

							TRUNCATE TABLE #RegressionStats
													
							SELECT @StatDataCount = Count(#RegressionX.MTAbundance)
							FROM #RegressionX INNER JOIN
						 		#RegressionY ON
						 		#RegressionX.Mass_Tag_ID = #RegressionY.Mass_Tag_ID
						 		AND
						 		#RegressionX.Mass_Tag_Mods = #RegressionY.Mass_Tag_Mods

							-- Compute the number of data points to discard from the beginning and end of the data (as sorted by intensity)
							Set @NumSmallDataToDiscard = @StatDataCount * (@PctSmallDataToDiscard/100.0)
							Set @NumLargeDataToDiscard = @StatDataCount * (@PctLargeDataToDiscard/100.0)
							If @NumSmallDataToDiscard < 0
								Set @NumSmallDataToDiscard = 0
							If @NumLargeDataToDiscard < 0
								Set @NumLargeDataToDiscard = 0
							
							-- Reset @StatsAreValid to 0
							Set @StatsAreValid = 0

							-- See if enough data points are present for normalization using regression
							If @StatDataCount - @NumSmallDataToDiscard - @NumLargeDataToDiscard >= @MinimumDataPointsForRegressionNormalization		-- <g>
							Begin
															
								Set @StatSql = ''
								Set @StatSql = @StatSql + ' INSERT INTO #RegressionStats (SumXY, SumX, SumY, SumXX, DataCount)'
								Set @StatSql = @StatSql + ' SELECT SUM(AbuX*AbuY), SUM(AbuX), SUM(AbuY), SUM(AbuX*AbuX), Count(AbuX)'
								Set @StatSql = @StatSql + '	FROM'
								Set @StatSql = @StatSql + '      (SELECT TOP ' + Convert(varchar(9), @StatDataCount - @NumLargeDataToDiscard - @NumSmallDataToDiscard) + ' DataToUse.AbuX, DataToUse.AbuY'
								Set @StatSql = @StatSql + '       FROM'
								Set @StatSql = @StatSql + '  (SELECT TOP ' + Convert(varchar(9), @StatDataCount - @NumSmallDataToDiscard) + ' #RegressionX.MTAbundance AS AbuX,'
								Set @StatSql = @StatSql + '             #RegressionY.MTAbundance AS AbuY'
								Set @StatSql = @StatSql + '          FROM #RegressionX INNER JOIN'
								Set @StatSql = @StatSql + '             #RegressionY ON'
								Set @StatSql = @StatSql + '             #RegressionX.Mass_Tag_ID = #RegressionY.Mass_Tag_ID'
								Set @StatSql = @StatSql + '               AND'
								Set @StatSql = @StatSql + '             #RegressionX.Mass_Tag_Mods = #RegressionY.Mass_Tag_Mods'
								Set @StatSql = @StatSql + '          ORDER BY #RegressionX.MTAbundance DESC) As DataToUse'
								Set @StatSql = @StatSql + '       ORDER BY DataToUse.AbuX ASC) As DataToUseOuter'
		
								Exec (@StatSql)
								
								SELECT TOP 1 @StatSumXY = SumXY, @StatSumX = SumX, @StatSumY = SumY, @StatSumXX = SumXX, @StatDataCount = DataCount
								FROM #RegressionStats
								
								Set @StatDenominator = @StatDataCount * @StatSumXX - @StatSumX * @StatSumX
								
								If IsNull(@StatDenominator,0) <> 0		-- <h>
								Begin
									-- Calculate the slope and intercept (for y = mx + b)
									-- It would be better to compute simply a slope (for y = mx, with b fixed at 0); don't know how to do this
									
									Set @StatM = (@StatDataCount * @StatSumXY - @StatSumX * @StatSumY) / @StatDenominator
									Set @StatB = (@StatSumY * @StatSumXX - @StatSumX * @StatSumXY) / @StatDenominator
									
									-- If StatM and StatB are within the accepted limits, then normalize the data for this replicate
									If @StatM <> 0 And @StatM >= @StatMinimumM And @StatM <= @StatMaximumM And @StatB >= @StatMinimumB And @StatB <= @StatMaximumB		-- <i>
									Begin
										UPDATE #UMCMatchResultsByJob
										-- SET		MTAbundance = (MTAbundance - @StatB) / @StatM
										SET		MTAbundance = MTAbundance / @StatM
										WHERE	TopLevelFraction = @TopLevelFractionWork AND 
												Fraction = @FractionWork AND
												[Replicate] = @ReplicateValue
										
										Set @StatsAreValid = 1
									End		-- <i>
								End		-- <h>
							End	-- <g>

							If @StatsAreValid = 0
							Begin
								Set @StatMathSummary = @StatMathSummary + '0,0'
							End
							Else
							Begin
								Set @StatMathSummary = @StatMathSummary + LTrim(RTrim(Convert(varchar(19), Round(@StatM,5)))) + ','
								Set @StatMathSummary = @StatMathSummary + LTrim(RTrim(Convert(varchar(19), Round(@StatB,5))))
							End
								
							-- Remove the minimum Replicate value
							DELETE FROM #RegressionReplicateValues
							WHERE [Replicate] = @ReplicateValue
							
						End 	-- <f>
					End		-- <e>
					
					-- Remove this combination of TopLevelFraction and Fraction from #RgressionSource			
					DELETE FROM #RegressionSource
					WHERE SourceID = @RegressionSourceID
				
				End 	-- <d>
			End 	-- <c>
		 End	-- <b>
	 End	-- <a>


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
	-- We first compute the average abundance for each peptide across replicates, 
	--  storing in #UMCMatchResultsByJob.AverageAbundanceAcrossReps
	-- We also compute the median abundance for each peptide across replicates,
	--  storing in #UMCMatchResultsByJob.MedianAbundanceAcrossReps
	-- Now, we set UseValue = 0 for those those peptides whose abundance is more than
	--  @FractionCrossReplicateAvgInRange away from the cross-replicate average
	-- Finally, we change UseValue back to 1 for those peptides is less than
	--  @FractionCrossReplicateAvgInRange away from the cross-replicate median

	If @RemoveOutlierAbundancesForReplicates <> 0 AND @ReplicateCountEstimate > 1
	Begin
		
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
		Begin
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
		End

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

	End


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
	SET 	FeatureCountWithMatchesAvg = @FeatureCountWithMatchesAvg,
		MTMatchingUMCsCount = @MTMatchingUMCsCount,
		MTMatchingUMCsCountFilteredOut = @MTMatchingUMCsCountFilteredOut,
		UniqueMassTagCount = @UniqueMassTagCount,
		UniqueMassTagCountFilteredOut = @UniqueMassTagCountFilteredOut,
		UniqueInternalStdCount = @UniqueInternalStdCount,
		UniqueInternalStdCountFilteredOut = @UniqueInternalStdCountFilteredOut,
		ReplicateNormalizationStats = @StatMathSummary,
		Last_Affected = GetDate()
	WHERE Quantitation_ID = @QuantitationID


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
		[MTAbundanceAvg] float NULL ,
		[MTAbundanceStDev] float NULL ,
		[MTAbundanceLightPlusHeavyAvg] float NULL ,
		[Member_Count_Used_For_Abu_Avg] real NULL ,
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
		MTAbundanceAvg, MTAbundanceStDev,
		MTAbundanceLightPlusHeavyAvg,
		Member_Count_Used_For_Abu_Avg,
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
			AVG(MTAbundance),									-- MTAbundanceAvg
			-- If only a single trial, then cannot have a MTAbundance StDev value
			-- Use IsNull() to convert the resultant Null StDev values to 0
			IsNull(STDEV(MTAbundance), 0),						-- MTAbundanceStDev

			AVG(MTAbundanceLightPlusHeavy),						-- MTAbundanceLightPlusHeavyAvg
			AVG(CONVERT(real, Member_Count_Used_For_Abu)),		-- Member_Count_Used_For_Abu_Avg; Avg, since we're averaging MTAbundance
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
		[MTAbundanceAvg] float NULL ,					-- Sum of MT Abundance values across fractions
		[MTAbundanceStDev] float NULL ,					-- Standard deviation for a sum of numbers = Sqrt(Sum(StDevs^2))
		[MTAbundanceLightPlusHeavyAvg] float NULL ,
		[Member_Count_Used_For_Abu_Avg] float NULL ,
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
		 Mass_Tag_ID, Mass_Tag_Mods,
		 MTAbundanceAvg, MTAbundanceStDev,
		 MTAbundanceLightPlusHeavyAvg,
		 Member_Count_Used_For_Abu_Avg,
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
			Mass_Tag_ID, Mass_Tag_Mods,
			SUM(MTAbundanceAvg),											-- MTAbundanceAvg = Sum of MTAbundanceAvg values across fractions
			-- Compute the standard deviation of the Sum of several numbers by finding the
			--  sum of the squares of the MTAbundanceStDev values, then taking the
			--  square root of the result
			SQRT(SUM(SQUARE(IsNull(MTAbundanceStDev, 0)))),					-- MTAbundanceStDev
			
			SUM(MTAbundanceLightPlusHeavyAvg),
			SUM(Member_Count_Used_For_Abu_Avg),								-- Sum, since we're summing MTAbundanceAvg
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
	--
	-- Step 11a
	--
	-- Pre-define the #UMCMatchResultsSummary table before populating it
	-- This is done to assure the correct data type is used
	-- We can also pre-define the indices
	--
	if exists (select * from dbo.sysobjects where id = object_id(N'[#UMCMatchResultsSummary]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	drop table [#UMCMatchResultsSummary]

	CREATE TABLE #UMCMatchResultsSummary (
		[Ref_ID] int NOT NULL ,
		[InternalStdMatch] tinyint NOT NULL ,
		[Mass_Tag_ID] int NOT NULL ,
		[Mass_Tag_Mods] [varchar](50) NOT NULL ,
		[Protein_Count] int NOT NULL ,
		[PMT_Quality_Score] real NOT NULL ,
		[Cleavage_State] tinyint NULL ,					-- This needs to be NULL in case a mass tag hasn't yet been processed by NamePeptides
		[Fragment_Span] smallint NULL ,					-- This needs to be NULL in case a mass tag hasn't yet been processed by NamePeptides
		[MTAbundanceAvg] float NULL ,						-- Sum of MT Abundance values across fractions
		[MTAbundanceStDev] float NULL ,					-- Standard deviation for a sum of numbers = Sqrt(Sum(StDevs^2))
		[MTAbundanceLightPlusHeavyAvg] float NULL ,
		[Member_Count_Used_For_Abu_Avg] float NOT NULL ,
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

	-- Step 11b
	--
	-- Sum peptide abundances across top level fractions
	INSERT INTO #UMCMatchResultsSummary
		(Ref_ID, InternalStdMatch, 
		 Mass_Tag_ID, Mass_Tag_Mods, 
		 Protein_Count, PMT_Quality_Score,
		 Cleavage_State, Fragment_Span,
		 MTAbundanceAvg, MTAbundanceStDev,
		 MTAbundanceLightPlusHeavyAvg,
		 Member_Count_Used_For_Abu_Avg,
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
			UMR.Mass_Tag_ID, UMR.Mass_Tag_Mods,
			IsNull(MT.Multiple_Proteins,0) + 1, IsNull(MT.PMT_Quality_Score,0),
			MTPM.Cleavage_State, MTPM.Fragment_Span,							-- Note that these values could be NULL
			SUM(MTAbundanceAvg),											-- MTAbundanceAvg = Sum of MTAbundanceAvg values across fractions
			-- Compute the standard deviation of the Sum of several numbers by finding the
			--  sum of the squares of the MTAbundanceStDev values, then taking the
			--  square root of the result
			SQRT(SUM(SQUARE(IsNull(MTAbundanceStDev, 0)))),					-- MTAbundanceStDev

			SUM(MTAbundanceLightPlusHeavyAvg),
			SUM(Member_Count_Used_For_Abu_Avg),
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
		-- Post an error message to T_Log_Entries
		set @message = @MessageNoResults
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
	-- Create the Protein Abundances Summary temporary table
	-- We can populate some of the columns when we create it
	-- The other columns will be populated below
	--
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
		[UMCMultipleMTHitCountAvg] real NULL ,
		[UMCMultipleMTHitCountStDev] float NULL ,
		[UMCMultipleMTHitCountMin] int NULL ,
		[UMCMultipleMTHitCountMax] int NULL ,
		[Abundance_Average] float NULL ,
		[Abundance_Minimum] float NULL ,
		[Abundance_Maximum] float NULL ,
		[Abundance_StDev] float NULL ,
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
	--   @FractionHighestAbuToUse of the maximum summed MT abundance for the given Protein
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
--						--  sum of the squares of the MTAbundanceStDev values, then taking the
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
	-- First determine the minimum potential MT High Normalized Score, MT High Discriminant Score, and PMT Quality Score
	Set @MinimumPotentialMTHighNormalizedScore = @MinimumMTHighNormalizedScore
	Set @MinimumPotentialMTHighDiscriminantScore = @MinimumMTHighDiscriminantScore
	Set @MinimumPotentialPMTQualityScore = @MinimumPMTQualityScore
	
	-- Find the smallest values used for the MDID's for this Quantitation ID

	Set @MinMTHighNormalizedScoreCompare = @MinimumMTHighNormalizedScore
	Set @MinMTHighDiscriminantScoreCompare = @MinimumMTHighDiscriminantScore
	Set @MinPMTQualityScoreCompare = @MinimumPMTQualityScore
	
	SELECT @MinMTHighNormalizedScoreCompare = Min(IsNull(MMD.Minimum_High_Normalized_Score, @MinimumMTHighNormalizedScore)),
		   @MinMTHighDiscriminantScoreCompare = Min(IsNull(MMD.Minimum_High_Discriminant_Score, @MinimumMTHighDiscriminantScore)),
		   @MinPMTQualityScoreCompare = Min(IsNull(MMD.Minimum_PMT_Quality_Score, @MinimumPMTQualityScore))
	FROM T_Quantitation_MDIDs AS TMDID INNER JOIN
		 T_Match_Making_Description AS MMD On TMDID.MD_ID = MMD.MD_ID
	WHERE TMDID.Quantitation_ID = @QuantitationID

	If @MinMTHighNormalizedScoreCompare > @MinimumPotentialMTHighNormalizedScore
		Set @MinimumPotentialMTHighNormalizedScore = @MinMTHighNormalizedScoreCompare
	If @MinMTHighDiscriminantScoreCompare > @MinimumPotentialMTHighDiscriminantScore
		Set @MinimumPotentialMTHighDiscriminantScore = @MinMTHighDiscriminantScoreCompare
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


	-----------------------------------------------------------
	-- Step 13
	--
	-- Compute Protein Coverage
	-----------------------------------------------------------

	If @ORFCoverageComputationLevel > 0
	Begin

		if exists (select * from dbo.sysobjects where id = object_id(N'[#Protein_Coverage]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [#Protein_Coverage]

		CREATE TABLE #Protein_Coverage (
			[Ref_ID] int NOT NULL ,
			[Protein_Sequence] varchar(8000) NOT NULL, 				-- Used to compute protein coverage
			[Protein_Coverage_Residue_Count] int NULL,
			[Protein_Coverage_Fraction] real NULL,
			[Protein_Coverage_Fraction_High_Abundance] real NULL,
			[Potential_Protein_Coverage_Residue_Count] int NULL,
			[Potential_Protein_Coverage_Fraction] real NULL
		) ON [PRIMARY]

		CREATE UNIQUE CLUSTERED INDEX #IX__TempTable__ProteinCoverage_Ref_ID ON #Protein_Coverage([Ref_ID]) ON [PRIMARY]

		-- Populate the #Protein_Coverage table
		-- We have to use a table separate from #UMCMatchResultsSummary for computing Protein coverage
		--  since Sql Server sets a maximum record length of 8060 bytes
		-- Note that proteins with sequences longer than 8000 residues will get truncated
		
		INSERT INTO #Protein_Coverage
			(Ref_ID, Protein_Sequence)
		SELECT #UMCMatchResultsSummary.Ref_ID,
			 LOWER(Convert(varchar(8000), T_Proteins.Protein_Sequence))				-- Convert the protein sequence to lowercase
		FROM #UMCMatchResultsSummary INNER JOIN
			 T_Proteins ON #UMCMatchResultsSummary.Ref_ID = T_Proteins.Ref_ID
		WHERE NOT T_Proteins.Protein_Sequence IS NULL
		GROUP BY #UMCMatchResultsSummary.Ref_ID, LOWER(Convert(varchar(8000), T_Proteins.Protein_Sequence))
		ORDER BY #UMCMatchResultsSummary.Ref_ID
		--	
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		If @myError <> 0 
		Begin
			Set @message = 'Error while populating the #Protein_Coverage temporary table'
			Set @myError = 138
			Goto Done
		End

/*		-- See if the master..xp_regex_replace procedure exists
		-- If it does, then we can use it to determine the number of capital letters in a string
		Set @RegExSPExists = 0
		SELECT @RegExSPExists = COUNT(*)
		FROM master..sysobjects
		WHERE name = 'xp_regex_replace'
		
		-- Make sure the user has permission to run xp_regex_replace
		If @RegExSPExists > 0
		Begin
			Set @Protein_Sequence_Full = 'massTAGdataBASE'
			EXEC master..xp_regex_replace @Protein_Sequence_Full, '[^A-Z]', '', @Protein_Sequence_Full OUTPUT
			If @Protein_Sequence_Full <> 'TAGBASE'
				Set @RegExSPExists = 0
		End
*/
		
		-- Process each Protein in #Protein_Coverage
		-- First determine the minimum Ref_ID value
		SET @LastRefID = -1
		SET @ProteinProcessingDone = 0
		--
		SELECT @LastRefID = MIN(Ref_ID)
		FROM #Protein_Coverage
		--
		SET @LastRefID = @LastRefID - 1
		
		-- Now step through the table
		WHILE @ProteinProcessingDone = 0
		Begin
			SELECT TOP 1 @LastRefID = Ref_ID,
						 @Protein_Sequence_Full = Protein_Sequence
			FROM #Protein_Coverage
			WHERE Ref_ID > @LastRefID
			--	
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--
			If @myError <> 0 
			Begin
				Set @message = 'Error while obtaining the next Ref_ID from the #Protein_Coverage temporary table'
				Set @myError = 139
				Goto Done
			End
			
			IF @myRowCount <> 1
				Set @ProteinProcessingDone = 1
			Else
			Begin
				Set @ProteinSequenceLength = Len(@Protein_Sequence_Full)
				If @ProteinSequenceLength > 0
				Begin
					--
					-- Step 13a - First compute the observed Protein coverage
					--
					Set @Protein_Sequence = @Protein_Sequence_Full
					SELECT @Protein_Sequence = REPLACE (@Protein_Sequence, T_Mass_Tags.Peptide, UPPER(T_Mass_Tags.Peptide))
					FROM #UMCMatchResultsSummary INNER JOIN
						T_Mass_Tags ON #UMCMatchResultsSummary.Mass_Tag_ID = T_Mass_Tags.Mass_Tag_ID
					WHERE #UMCMatchResultsSummary.Ref_ID = @LastRefID
					--	
					SELECT @myError = @@error, @myRowCount = @@rowcount
					--
					If @myError <> 0 
					Begin
						Set @message = 'Error while capitalizing the protein sequence for Protein_Coverage use'
						Set @myError = 140
						Goto Done
					End

					Set @ProteinCoverageResidueCount = 0
					
/*					If @RegExSPExists > 0
					Begin
						-- Replace all the non-capital letters in @Protein_Sequence with blanks using a regular expression
						-- This SP is part of the xp_regex.dll file, written by Dan Farino 
						-- and obtained from http://www.codeproject.com/managedcpp/xpregex.asp
						EXEC master..xp_regex_replace @Protein_Sequence, '[^A-Z]', '', @Protein_Sequence OUTPUT
						Set @ProteinCoverageResidueCount = Len(@Protein_Sequence)
					End
					Else
					Begin
						exec CountCapitalLetters @Protein_Sequence, @CapitalLetterCount = @ProteinCoverageResidueCount OUTPUT
					End
*/
					exec CountCapitalLetters @Protein_Sequence, @CapitalLetterCount = @ProteinCoverageResidueCount OUTPUT

					--
					-- Step 13b - Compute the observed Protein coverage using only the high abundance peptides
					--
					Set @Protein_Sequence = @Protein_Sequence_Full
					SELECT @Protein_Sequence = REPLACE (@Protein_Sequence, T_Mass_Tags.Peptide, UPPER(T_Mass_Tags.Peptide))
					FROM #UMCMatchResultsSummary INNER JOIN
						T_Mass_Tags ON #UMCMatchResultsSummary.Mass_Tag_ID = T_Mass_Tags.Mass_Tag_ID
					WHERE #UMCMatchResultsSummary.Ref_ID = @LastRefID AND 
						  #UMCMatchResultsSummary.Used_For_Abundance_Computation = 1
					--	
					SELECT @myError = @@error, @myRowCount = @@rowcount
					--
					If @myError <> 0 
					Begin
						Set @message = 'Error while capitalizing the protein sequence for Protein_Coverage use'
						Set @myError = 141
						Goto Done
					End

					Set @ProteinCoverageResidueCountHighAbu = 0
					
/*					If @RegExSPExists > 0
					Begin
						-- Replace all the non-capital letters in @Protein_Sequence with blanks using a regular expression
						-- This SP is part of the xp_regex.dll file, written by Dan Farino 
						-- and obtained from http://www.codeproject.com/managedcpp/xpregex.asp
						EXEC master..xp_regex_replace @Protein_Sequence, '[^A-Z]', '', @Protein_Sequence OUTPUT
						Set @ProteinCoverageResidueCountHighAbu = Len(@Protein_Sequence)
					End
					Else
					Begin
						exec CountCapitalLetters @Protein_Sequence, @CapitalLetterCount = @ProteinCoverageResidueCountHighAbu OUTPUT
					End
*/
						exec CountCapitalLetters @Protein_Sequence, @CapitalLetterCount = @ProteinCoverageResidueCountHighAbu OUTPUT

					--
					-- Lookup the potential protein coverage fraction from T_Protein_Coverage
					-- Protein coverage values are stored precomputed in this table, using PMT_Quality_Score >= 0 and >= 0.001
					Set @PotentialProteinCoverageFraction = Null
					--
					SELECT TOP 1 @PotentialProteinCoverageFraction = Coverage_PMTs
					FROM T_Protein_Coverage
					WHERE Ref_ID = @LastRefID AND PMT_Quality_Score_Minimum >= @MinimumPotentialPMTQualityScore
					ORDER BY PMT_Quality_Score_Minimum ASC
					--
					SELECT @myError = @@error, @myRowCount = @@rowcount
					--
					If @myRowCount = 0
					Begin
						-- Entry not found with PMT_Quality_Score_Minimum >= @MinimumPotentialPMTQualityScore
						-- See if any entries exist for @LastRefID; sort descending this time
						
						SELECT TOP 1 @PotentialProteinCoverageFraction = Coverage_PMTs
						FROM T_Protein_Coverage
						WHERE Ref_ID = @LastRefID
						ORDER BY PMT_Quality_Score_Minimum DESC
						--
						SELECT @myError = @@error, @myRowCount = @@rowcount
						
					End
					
					If IsNull(@PotentialProteinCoverageFraction, -1) >= 0
						Set @PotentialProteinCoverageResidueCount = @PotentialProteinCoverageFraction * Convert(float, @ProteinSequenceLength)
					Else
						Set @PotentialProteinCoverageResidueCount = Null


					-- Record the computed Protein Coverage values in #Protein_Coverage	
					UPDATE #Protein_Coverage
					SET Protein_Coverage_Residue_Count = @ProteinCoverageResidueCount,
						Protein_Coverage_Fraction = @ProteinCoverageResidueCount / Convert(float, @ProteinSequenceLength),
						Protein_Coverage_Fraction_High_Abundance = @ProteinCoverageResidueCountHighAbu / Convert(float, @ProteinSequenceLength),
						Potential_Protein_Coverage_Residue_Count = @PotentialProteinCoverageResidueCount,
						Potential_Protein_Coverage_Fraction = @PotentialProteinCoverageFraction
					WHERE Ref_ID = @LastRefID
					--	
					SELECT @myError = @@error, @myRowCount = @@rowcount
					--
					If @myError <> 0 
					Begin
						Set @message = 'Error updating the Protein coverage values in the #Protein_Coverage temporary table'
						Set @myError = 142
						Goto Done
					End

				End
			End
		End
		
		-- Copy the Protein Coverage Values from #Protein_Coverage to #ProteinAbundanceSummary
		UPDATE #ProteinAbundanceSummary
		SET Protein_Coverage_Residue_Count = #Protein_Coverage.Protein_Coverage_Residue_Count,
			Protein_Coverage_Fraction = #Protein_Coverage.Protein_Coverage_Fraction,
			Protein_Coverage_Fraction_High_Abundance = #Protein_Coverage.Protein_Coverage_Fraction_High_Abundance,
			Potential_Protein_Coverage_Residue_Count = #Protein_Coverage.Potential_Protein_Coverage_Residue_Count,
			Potential_Protein_Coverage_Fraction = #Protein_Coverage.Potential_Protein_Coverage_Fraction
		FROM #ProteinAbundanceSummary INNER JOIN
			 #Protein_Coverage ON #ProteinAbundanceSummary.Ref_ID = #Protein_Coverage.Ref_ID
		--	
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		If @myError <> 0 
		Begin
			Set @message = 'Error copying the Protein coverage values from #Protein_Coverage to #ProteinAbundanceSummary'
			Set @myError = 143
			Goto Done
		End
		
	End


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

	-- Display a status message
	--
	Set @message = 'Processed ' + convert(varchar(19), @myRowCount) + ' Proteins for QuantitationID ' + convert(varchar(19), @QuantitationID)
	
	-- Echo the message to the console
	--
	--Print @message
	--Select @message


Done:
	-----------------------------------------------------------
	-- Done processing; 
	-----------------------------------------------------------
		
	If @myError <> 0 
		Begin
			If Len(@message) > 0
				Set @message = ': ' + @message
			
			Set @message = 'Quantitation Processing Work Error ' + convert(varchar(19), @myError) + @message
			Execute PostLogEntry 'Error', @message, 'QuantitationProcessing'
			Print @message
		End
			
	Return @myError


GO
GRANT EXECUTE ON [dbo].[QuantitationProcessWork] TO [DMS_SP_User]
GO
