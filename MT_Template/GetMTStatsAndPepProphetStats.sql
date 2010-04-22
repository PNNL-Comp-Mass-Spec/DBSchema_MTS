/****** Object:  StoredProcedure [dbo].[GetMTStatsAndPepProphetStats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.GetMTStatsAndPepProphetStats
/****************************************************************
**  Desc: Returns MT stats and NET values plus peptide prophet stats for the AMTs in this DB
**		  Returns all MTs passing the filters.  Returns a sampling of the MTs that do not pass the filters
**		  Unlike GetMassTagsGANETParam and GetMassTagsPlusPepProphetStats, this procedure does not return peptide sequence information
**
**		Note: This procedure was used by the 2008 version of SMART and is no longer used
**		      The 2010 version of SMART uses GetMTStats
**
**  Return values: 0 if success, otherwise, error code 
**
**  Parameters: See comments below
**
**  Auth:	mem
**	Date:	04/07/2008
**  
****************************************************************/
(
	@NonFilterPassingMTsSamplingFraction real = 0.5,
	@NonFilterPassingMTsMaxCount int = 500000,
	@MinimumHighNormalizedScore real = 0,		-- The minimum value required for High_Normalized_Score; 0 to allow all
	@MinimumHighDiscriminantScore real = 0,		-- The minimum High_Discriminant_Score to allow; 0 to allow all
	@MinimumPeptideProphetProbability real = 0,	-- The minimum High_Peptide_Prophet_Probability value to allow; 0 to allow all
	@MinimumPMTQualityScore real = 0,	-- The minimum PMT_Quality_Score to allow; 0 to allow all
	@ShowDebugInfo tinyint = 0
)
As
	Set NoCount On

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Declare @NonFilterPassingMTCount int
	Declare @NonFilterPassingMTsToReturn int
	
	---------------------------------------------------	
	-- Validate the input parameters
	---------------------------------------------------	

	Set @NonFilterPassingMTsSamplingFraction = IsNull(@NonFilterPassingMTsSamplingFraction, 0.25)
	Set @NonFilterPassingMTsMaxCount = IsNull(@NonFilterPassingMTsMaxCount, 750000)
	
	Set @MinimumHighNormalizedScore = IsNull(@MinimumHighNormalizedScore, 0)
	Set @MinimumHighDiscriminantScore = IsNull(@MinimumHighDiscriminantScore, 0)
	Set @MinimumPeptideProphetProbability = IsNull(@MinimumPeptideProphetProbability, 0)
	Set @MinimumPMTQualityScore = IsNull(@MinimumPMTQualityScore, 0)
	Set @ShowDebugInfo = IsNull(@ShowDebugInfo, 0)
	
	---------------------------------------------------	
	-- Define the extra parameters needed for GetMassTagsPassingFiltersWork
	---------------------------------------------------	

	Declare @MassCorrectionIDFilterList varchar(255)
	Declare @ConfirmedOnly tinyint
	Declare @ExperimentFilter varchar(64)
	Declare @ExperimentExclusionFilter varchar(64)
	Declare @JobToFilterOnByDataset int
	Declare @DatasetToFilterOn varchar(256)
	
	Set @MassCorrectionIDFilterList = ''
	Set @ConfirmedOnly = 0
	Set @ExperimentFilter = ''
	Set @ExperimentExclusionFilter = ''
	Set @JobToFilterOnByDataset = 0
	Set @DatasetToFilterOn = ''
	
	---------------------------------------------------	
	-- Create a temporary table to hold the list of mass tags that match the 
	-- inclusion list criteria and Is_Confirmed requirements
	---------------------------------------------------	
	CREATE TABLE #TmpMassTags (
		Mass_Tag_ID int NOT NULL
	)

	CREATE CLUSTERED INDEX #IX_TmpMassTags ON #TmpMassTags (Mass_Tag_ID ASC)

	CREATE TABLE #TmpNonFilterPassingMTs (
		Mass_Tag_ID int NOT NULL,
		RandomID int NOT NULL
	)

	CREATE CLUSTERED INDEX #IX_TmpNonFilterPassingMTs ON #TmpNonFilterPassingMTs (Mass_Tag_ID ASC)

	---------------------------------------------------	
	-- Populate #TmpMassTags
	---------------------------------------------------	

	Exec @myError = GetMassTagsPassingFiltersWork	
							@MassCorrectionIDFilterList, @ConfirmedOnly, 
							@ExperimentFilter, @ExperimentExclusionFilter, @JobToFilterOnByDataset, 
							@MinimumHighNormalizedScore, @MinimumPMTQualityScore, 
							@MinimumHighDiscriminantScore, @MinimumPeptideProphetProbability,
							@DatasetToFilterOn = @DatasetToFilterOn Output
	
	If @myError <> 0
		Goto Done					

	If @ShowDebugInfo <> 0
		SELECT COUNT(*) AS MTCountPassingFilters
		FROM #TmpMassTags


	---------------------------------------------------	
	-- Now populate #TmpNonFilterPassingMTs
	---------------------------------------------------	

	INSERT INTO #TmpNonFilterPassingMTs (Mass_Tag_ID, RandomID)
	SELECT MT.Mass_Tag_ID,
	       RAND(MT.Mass_Tag_ID + DATEPART(ms, GETDATE()))
	FROM T_Mass_Tags MT LEFT OUTER JOIN
		 #TmpMassTags ON MT.Mass_Tag_ID = #TmpMassTags.Mass_Tag_ID
	WHERE #TmpMassTags.Mass_Tag_ID IS NULL
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	Set @NonFilterPassingMTCount = @myRowCount
		
	Set @NonFilterPassingMTsToReturn = @NonFilterPassingMTCount * @NonFilterPassingMTsSamplingFraction
	If @NonFilterPassingMTsMaxCount > 0 AND @NonFilterPassingMTsToReturn > @NonFilterPassingMTsMaxCount
		Set @NonFilterPassingMTsToReturn = @NonFilterPassingMTsMaxCount

	If @ShowDebugInfo <> 0
		SELECT @NonFilterPassingMTCount AS NonFilterPassingMTCountOriginal,
			   @NonFilterPassingMTsToReturn AS NonFilterPassingMTsToReturn


	---------------------------------------------------
	-- Return stats for all matching MTs
	-- Using Avg_GANET in T_Mass_Tags_NET for each MT's NET
	-- Returning StD_GANET from T_Mass_Tags_NET for StD_GANET
	---------------------------------------------------
	--
	SELECT MT.Mass_Tag_ID,
	       MT.Monoisotopic_Mass,
	       MTN.Avg_GANET AS NET,
	       MTN.StD_GANET,
	       MTN.Cnt_GANET,
	       MT.Peptide_Obs_Count_Passing_Filter,
	       MT.High_Normalized_Score,
	       MT.High_Discriminant_Score,
	       MT.High_Peptide_Prophet_Probability,
	       MT.Mod_Count,
	       MT.Cleavage_State_Max,
	       MTPPS.ObsCount_CS1,
	       MTPPS.ObsCount_CS2,
	       MTPPS.ObsCount_CS3,
	       MTPPS.PepProphet_FScore_Avg_CS1,
	       MTPPS.PepProphet_FScore_Avg_CS2,
	       MTPPS.PepProphet_FScore_Avg_CS3,
	       Convert(tinyint, 1) As PassesFilters
	FROM #TmpMassTags
	     INNER JOIN T_Mass_Tags MT
	       ON #TmpMassTags.Mass_Tag_ID = MT.Mass_Tag_ID
	     INNER JOIN T_Mass_Tags_NET MTN
	       ON #TmpMassTags.Mass_Tag_ID = MTN.Mass_Tag_ID
	     INNER JOIN T_Mass_Tag_Peptide_Prophet_Stats MTPPS
	       ON MT.Mass_Tag_ID = MTPPS.Mass_Tag_ID
	UNION
	SELECT Mass_Tag_ID,
	       Monoisotopic_Mass,
	       NET,
	       StD_GANET,
	       Cnt_GANET,
	       Peptide_Obs_Count_Passing_Filter,
	       High_Normalized_Score,
	       High_Discriminant_Score,
	       High_Peptide_Prophet_Probability,
	       Mod_Count,
	       Cleavage_State_Max,
	       ObsCount_CS1,
	       ObsCount_CS2,
	       ObsCount_CS3,
	       PepProphet_FScore_Avg_CS1,
	       PepProphet_FScore_Avg_CS2,
	       PepProphet_FScore_Avg_CS3,
	       Convert(tinyint, 0) AS PassesFilters
	FROM ( SELECT TOP (@NonFilterPassingMTsToReturn)
               MT.Mass_Tag_ID,
               MT.Monoisotopic_Mass,
               MTN.Avg_GANET AS NET,
               MTN.StD_GANET,
               MTN.Cnt_GANET,
               MT.Peptide_Obs_Count_Passing_Filter,
               MT.High_Normalized_Score,
               MT.High_Discriminant_Score,
               MT.High_Peptide_Prophet_Probability,
               MT.Mod_Count,
               MT.Cleavage_State_Max,
               MTPPS.ObsCount_CS1,
               MTPPS.ObsCount_CS2,
               MTPPS.ObsCount_CS3,
               MTPPS.PepProphet_FScore_Avg_CS1,
               MTPPS.PepProphet_FScore_Avg_CS2,
               MTPPS.PepProphet_FScore_Avg_CS3
	       FROM #TmpNonFilterPassingMTs
	            INNER JOIN T_Mass_Tags MT
	              ON #TmpNonFilterPassingMTs.Mass_Tag_ID = MT.Mass_Tag_ID
	            INNER JOIN T_Mass_Tags_NET MTN
	              ON #TmpNonFilterPassingMTs.Mass_Tag_ID = MTN.Mass_Tag_ID
	            INNER JOIN T_Mass_Tag_Peptide_Prophet_Stats MTPPS
	              ON MT.Mass_Tag_ID = MTPPS.Mass_Tag_ID
	       ORDER BY #TmpNonFilterPassingMTs.RandomID 
         ) LookupQ
	ORDER BY Mass_Tag_ID

	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


Done:
	Return @myError


GO
GRANT EXECUTE ON [dbo].[GetMTStatsAndPepProphetStats] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetMTStatsAndPepProphetStats] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetMTStatsAndPepProphetStats] TO [MTS_DB_Lite] AS [dbo]
GO
