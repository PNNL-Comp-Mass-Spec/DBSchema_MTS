/****** Object:  StoredProcedure [dbo].[GetMTStats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.GetMTStats
/****************************************************************
**  Desc: Returns MT stats and NET values for the AMTs in this DB that pass the given filters
**
**		Note: Unlike GetMassTagsGANETParam and GetMassTagsPlusPepProphetStats, this procedure does not return peptide sequence information
**		Note: This procedure is a simpler version of GetMTStatsAndPepProphetStats (which also uses T_Mass_Tag_Peptide_Prophet_Stats)
**		      The old version of SMART used the data in T_Mass_Tag_Peptide_Prophet_Stats but the 2010 version does not
**
**  Return values: 0 if success, otherwise, error code 
**
**  Parameters: See comments below
**
**  Auth:	mem
**	Date:	01/11/2010
**			01/20/2010 mem - Now returning PMT_Quality_Score
**  
****************************************************************/
(
	@MinimumHighNormalizedScore real = 0,		-- The minimum value required for High_Normalized_Score; 0 to allow all
	@MinimumHighDiscriminantScore real = 0,		-- The minimum High_Discriminant_Score to allow; 0 to allow all
	@MinimumPeptideProphetProbability real = 0,	-- The minimum High_Peptide_Prophet_Probability value to allow; 0 to allow all
	@MinimumPMTQualityScore real = 0,			-- The minimum PMT_Quality_Score to allow; 0 to allow all
	@infoOnly tinyint = 0						-- When non-zero, then shows the SQL that would be used; also returns the RowCount of the number of filter-passing AMT Tags
)
As
	Set NoCount On

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	---------------------------------------------------	
	-- Validate the input parameters
	---------------------------------------------------	

	Set @MinimumHighNormalizedScore = IsNull(@MinimumHighNormalizedScore, 0)
	Set @MinimumHighDiscriminantScore = IsNull(@MinimumHighDiscriminantScore, 0)
	Set @MinimumPeptideProphetProbability = IsNull(@MinimumPeptideProphetProbability, 0)
	Set @MinimumPMTQualityScore = IsNull(@MinimumPMTQualityScore, 0)
	Set @infoOnly = IsNull(@infoOnly, 0)
	
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

	---------------------------------------------------	
	-- Populate #TmpMassTags
	---------------------------------------------------	

	Exec @myError = GetMassTagsPassingFiltersWork	
							@MassCorrectionIDFilterList, @ConfirmedOnly, 
							@ExperimentFilter, @ExperimentExclusionFilter, @JobToFilterOnByDataset, 
							@MinimumHighNormalizedScore, @MinimumPMTQualityScore, 
							@MinimumHighDiscriminantScore, @MinimumPeptideProphetProbability,
							@DatasetToFilterOn = @DatasetToFilterOn Output,
							@infoOnly = @infoOnly
	
	If @myError <> 0
		Goto Done					

	If @infoOnly <> 0
		SELECT COUNT(*) AS MTCountPassingFilters
		FROM #TmpMassTags
	Else
	Begin

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
			MT.High_Peptide_Prophet_Probability,
			MT.Cleavage_State_Max,
			MT.PMT_Quality_Score
		FROM #TmpMassTags
			INNER JOIN T_Mass_Tags MT
			ON #TmpMassTags.Mass_Tag_ID = MT.Mass_Tag_ID
			INNER JOIN T_Mass_Tags_NET MTN
			ON #TmpMassTags.Mass_Tag_ID = MTN.Mass_Tag_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	End

Done:
	Return @myError


GO
GRANT EXECUTE ON [dbo].[GetMTStats] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetMTStats] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetMTStats] TO [MTS_DB_Lite] AS [dbo]
GO
