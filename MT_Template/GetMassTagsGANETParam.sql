/****** Object:  StoredProcedure [dbo].[GetMassTagsGANETParam] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.GetMassTagsGANETParam
/****************************************************************
**  Desc: Returns mass tags and NET values relevant for PMT peak matching
**
**  Return values: 0 if success, otherwise, error code 
**
**  Parameters: See comments below
**
**  Auth:	mem
**	Date:	01/06/2004
**			02/02/2004 mem - Now returning High_Normalized_Score in the 6th column of the output
**			07/27/2004 mem - Now returning StD_GANET in the 7th column of the output
**			09/21/2004 mem - Changed format of @MassCorrectionIDFilterList and removed parameters @AmtsOnly and @LockersOnly
**			01/12/2004 mem - Now returning High_Discriminant_Score in the 8th column of the output
**			02/05/2005 mem - Added parameters @MinimumHighDiscriminantScore, @ExperimentFilter, and @ExperimentExclusionFilter
**			09/08/2005 mem - Now returning Number_of_Peptides in the 9th column of the output
**			09/28/2005 mem - Switched to using Peptide_Obs_Count_Passing_Filter instead of Number_of_Peptides for the 9th column of data
**			12/22/2005 mem - Added parameter @JobToFilterOnByDataset
**			06/08/2006 mem - Now returning Mod_Count and Mod_Description as the 10th and 11th columns
**			09/06/2006 mem - Added parameter @MinimumPeptideProphetProbability
**						   - Updated parsing of @ExperimentFilter and @ExperimentExclusionFilter to check for percent signs in the parameter; if no percent signs are present, then auto-adds them at the beginning and end
**			10/09/2006 mem - Now returning Peptide Prophet Probability in the 12th column (where the 1st column is column 1)
**			04/06/2007 mem - Updated to call GetMassTagsPassingFiltersWork to populate #TmpMassTags with the PMTs to use
**  
****************************************************************/
(
	@MassCorrectionIDFilterList varchar(255) = '',
											-- Mass tag modification masses inclusion list, leave blank or Null to include all mass tags
											-- Items in list can be of the form:  [Not] GlobModID/Any
											-- For example: 1014			will filter for Mass Tags containing Mod 1014
											--          or: 1014, 1010		will filter for Mass Tags containing Mod 1014 or Mod 1010
											--			or: Any				will filter for any and all mass tags, regardless of mods
											--			or: Not 1014		will filter for Mass Tags not containing Mod 1014 (including unmodified mass tags)
											--			or: Not Any			will filter for Mass Tags without modifications
											-- Note that GlobModID = 1 means no modification, and thus:
											--				1				will filter for Mass Tags without modifications (just like Not Any)
											--				Not 1			will filter for Mass Tags with modifications
											-- Mods are defined in T_Mass_Correction_Factors in DMS and are accessible via MT_Main.V_DMS_Mass_Correction_Factors
	@ConfirmedOnly tinyint = 0,				-- Mass Tag must have Is_Confirmed = 1
	@MinimumHighNormalizedScore float = 0,	-- The minimum value required for High_Normalized_Score; 0 to allow all
	@MinimumPMTQualityScore decimal(9,5) = 0,	-- The minimum PMT_Quality_Score to allow; 0 to allow all
	@NETValueType tinyint = 0,					-- 0 to use GANET values, 1 to use PNET values
	@MinimumHighDiscriminantScore real = 0,		-- The minimum High_Discriminant_Score to allow; 0 to allow all
	@ExperimentFilter varchar(64) = '',				-- If non-blank, then selects PMT tags from datasets with this experiment; ignored if @JobToFilterOnByDataset is non-zero
	@ExperimentExclusionFilter varchar(64) = '',	-- If non-blank, then excludes PMT tags from datasets with this experiment; ignored if @JobToFilterOnByDataset is non-zero
	@JobToFilterOnByDataset int = 0,				-- Set to a non-zero value to only select PMT tags from the dataset associated with the given MS job; useful for matching LTQ-FT MS data to peptides detected during the MS/MS portion of the same analysis; if the job is not present in T_FTICR_Analysis_Description then no data is returned
	@MinimumPeptideProphetProbability real = 0		-- The minimum High_Peptide_Prophet_Probability value to allow; 0 to allow all
)
As
	Set NoCount On

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @DatasetToFilterOn varchar(256)
	
	---------------------------------------------------	
	-- Validate the input parameters
	---------------------------------------------------	
	Set @NETValueType = IsNull(@NETValueType, 0)
	Set @JobToFilterOnByDataset = IsNull(@JobToFilterOnByDataset, 0)
	Set @DatasetToFilterOn = ''
	
	---------------------------------------------------	
	-- Create a temporary table to hold the list of mass tags that match the 
	-- inclusion list criteria and Is_Confirmed requirements
	---------------------------------------------------	
	CREATE TABLE #TmpMassTags (
		Mass_Tag_ID int
	)

	CREATE CLUSTERED INDEX #IX_TmpMassTags ON #TmpMassTags (Mass_Tag_ID ASC)

	Exec @myError = GetMassTagsPassingFiltersWork	
							@MassCorrectionIDFilterList, @ConfirmedOnly, 
							@ExperimentFilter, @ExperimentExclusionFilter, @JobToFilterOnByDataset, 
							@MinimumHighNormalizedScore, @MinimumPMTQualityScore, 
							@MinimumHighDiscriminantScore, @MinimumPeptideProphetProbability,
							@DatasetToFilterOn = @DatasetToFilterOn Output
	
	If @myError <> 0
		Goto Done					
    
	---------------------------------------------------
	-- Join the data in #TmpMassTags with T_Mass_Tags
	-- and T_Mass_Tags_NET
	---------------------------------------------------

	If @NETValueType < 0 or @NETValueType > 1
		Set @NETValueType = 0

	If @JobToFilterOnByDataset <> 0
		SELECT	MT.Mass_Tag_ID, 
				MT.Peptide, 
				MT.Monoisotopic_Mass, 
				CASE WHEN @NETValueType = 1
				THEN MTN.PNET
				ELSE MIN(P.GANET_Obs) 
				END As Net_Value_to_Use, 
				MTN.PNET,
				MT.High_Normalized_Score, 
				0 AS StD_GANET,
				MT.High_Discriminant_Score, 
				MT.Peptide_Obs_Count_Passing_Filter,
				MT.Mod_Count,
				MT.Mod_Description,
				MT.High_Peptide_Prophet_Probability
		FROM #TmpMassTags
			 INNER JOIN T_Mass_Tags MT ON #TmpMassTags.Mass_Tag_ID = MT.Mass_Tag_ID 
			 INNER JOIN T_Peptides P ON MT.Mass_Tag_ID = P.Mass_Tag_ID 
			 INNER JOIN T_Mass_Tags_NET MTN ON MT.Mass_Tag_ID = MTN.Mass_Tag_ID 
			 INNER JOIN T_Analysis_Description TAD ON P.Analysis_ID = TAD.Job
		WHERE TAD.Dataset = @DatasetToFilterOn AND
				P.Max_Obs_Area_In_Job = 1
		GROUP BY MT.Mass_Tag_ID, MT.Peptide, MT.Monoisotopic_Mass, 
					MT.High_Normalized_Score, MT.High_Discriminant_Score, 
					MT.Peptide_Obs_Count_Passing_Filter, MT.Mod_Count, MT.Mod_Description, 
					MTN.PNET, MT.High_Peptide_Prophet_Probability
		ORDER BY MT.Monoisotopic_Mass
	Else
		-- Return Avg_GANET as Net_Value_To_Use
		SELECT DISTINCT
			MT.Mass_Tag_ID, 
			MT.Peptide, 
			MT.Monoisotopic_Mass, 
			CASE WHEN @NETValueType = 1 
			THEN MTN.PNET
			ELSE MTN.Avg_GANET 
			END As Net_Value_to_Use, 
			MTN.PNET, 
			MT.High_Normalized_Score, 
			MTN.StD_GANET,
			MT.High_Discriminant_Score,
			MT.Peptide_Obs_Count_Passing_Filter,
			MT.Mod_Count,
			MT.Mod_Description,
			MT.High_Peptide_Prophet_Probability
		FROM #TmpMassTags 
			INNER JOIN T_Mass_Tags AS MT ON #TmpMassTags.Mass_Tag_ID = MT.Mass_Tag_ID
			INNER JOIN T_Mass_Tags_NET AS MTN ON #TmpMassTags.Mass_Tag_ID = MTN.Mass_Tag_ID
		ORDER BY MT.Monoisotopic_Mass


	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


Done:
	Return @myError


GO
GRANT EXECUTE ON [dbo].[GetMassTagsGANETParam] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetMassTagsGANETParam] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetMassTagsGANETParam] TO [MTS_DB_Lite] AS [dbo]
GO
