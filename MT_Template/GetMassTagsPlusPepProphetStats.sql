/****** Object:  StoredProcedure [dbo].[GetMassTagsPlusPepProphetStats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.GetMassTagsPlusPepProphetStats
/****************************************************************
**  Desc: Returns mass tags and NET values relevant for PMT peak matching
**		  Also returns Peptide Prophet stats from T_Mass_Tag_Peptide_Prophet_Stats
**
**  Return values: 0 if success, otherwise, error code 
**
**  Parameters: See comments below
**
**  Auth:	mem
**	Date:	04/06/2007 mem - Created this procedure by extending GetMassTagsGANETParam to include data in T_Mass_Tag_Peptide_Prophet_Stats
**			05/21/2007 mem - Replaced PepProphet_Probability_Avg_CS1 with PepProphet_FScore_Avg_CS1
**			11/08/2007 mem - Now returning Cleavage_State as the final column
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
	-- Join the data in #TmpMassTags with T_Mass_Tags,
	-- T_Mass_Tags_NET, and T_Mass_Tag_Peptide_Prophet_Stats
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
				MT.High_Peptide_Prophet_Probability,
				MTPPS.Mass_Tag_ID, 
				MTPPS.ObsCount_CS1, 
				MTPPS.ObsCount_CS2, 
				MTPPS.ObsCount_CS3, 
				MTPPS.PepProphet_FScore_Max_CS1, 
				MTPPS.PepProphet_FScore_Max_CS2, 
				MTPPS.PepProphet_FScore_Max_CS3, 
				MTPPS.PepProphet_Probability_Max_CS1, 
				MTPPS.PepProphet_Probability_Max_CS2, 
				MTPPS.PepProphet_Probability_Max_CS3, 
				MTPPS.PepProphet_FScore_Avg_CS1, 
				MTPPS.PepProphet_FScore_Avg_CS2, 
				MTPPS.PepProphet_FScore_Avg_CS3,
				MAX(IsNull(MTPM.Cleavage_State, 0)) AS Cleavage_State
		FROM #TmpMassTags
			 INNER JOIN T_Mass_Tags MT ON #TmpMassTags.Mass_Tag_ID = MT.Mass_Tag_ID 
			 INNER JOIN T_Peptides P ON MT.Mass_Tag_ID = P.Mass_Tag_ID 
			 INNER JOIN T_Mass_Tags_NET MTN ON MT.Mass_Tag_ID = MTN.Mass_Tag_ID 
			 INNER JOIN T_Analysis_Description TAD ON P.Analysis_ID = TAD.Job
			 INNER JOIN T_Mass_Tag_to_Protein_Map MTPM ON MT.Mass_Tag_ID = MTPM.Mass_Tag_ID
			 LEFT OUTER JOIN T_Mass_Tag_Peptide_Prophet_Stats MTPPS ON MT.Mass_Tag_ID = MTPPS.Mass_Tag_ID
		WHERE TAD.Dataset = @DatasetToFilterOn AND
				P.Max_Obs_Area_In_Job = 1
		GROUP BY MT.Mass_Tag_ID, MT.Peptide, MT.Monoisotopic_Mass, 
					MT.High_Normalized_Score, MT.High_Discriminant_Score, 
					MT.Peptide_Obs_Count_Passing_Filter, MT.Mod_Count, MT.Mod_Description, 
					MTN.PNET, MT.High_Peptide_Prophet_Probability,
					MTPPS.Mass_Tag_ID, 
					MTPPS.ObsCount_CS1, 
					MTPPS.ObsCount_CS2, 
					MTPPS.ObsCount_CS3, 
					MTPPS.PepProphet_FScore_Max_CS1, 
					MTPPS.PepProphet_FScore_Max_CS2, 
					MTPPS.PepProphet_FScore_Max_CS3, 
					MTPPS.PepProphet_Probability_Max_CS1, 
					MTPPS.PepProphet_Probability_Max_CS2, 
					MTPPS.PepProphet_Probability_Max_CS3, 
					MTPPS.PepProphet_FScore_Avg_CS1, 
					MTPPS.PepProphet_FScore_Avg_CS2, 
					MTPPS.PepProphet_FScore_Avg_CS3
		ORDER BY MT.Monoisotopic_Mass
	Else
		-- Return Avg_GANET as Net_Value_To_Use
		SELECT 
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
			MT.High_Peptide_Prophet_Probability,
			MTPPS.Mass_Tag_ID, 
			MTPPS.ObsCount_CS1, 
			MTPPS.ObsCount_CS2, 
			MTPPS.ObsCount_CS3, 
			MTPPS.PepProphet_FScore_Max_CS1, 
			MTPPS.PepProphet_FScore_Max_CS2, 
			MTPPS.PepProphet_FScore_Max_CS3, 
			MTPPS.PepProphet_Probability_Max_CS1, 
			MTPPS.PepProphet_Probability_Max_CS2, 
			MTPPS.PepProphet_Probability_Max_CS3, 
			MTPPS.PepProphet_FScore_Avg_CS1, 
			MTPPS.PepProphet_FScore_Avg_CS2, 
			MTPPS.PepProphet_FScore_Avg_CS3,
			MAX(IsNull(MTPM.Cleavage_State, 0)) AS Cleavage_State
		FROM #TmpMassTags 
			INNER JOIN T_Mass_Tags AS MT ON #TmpMassTags.Mass_Tag_ID = MT.Mass_Tag_ID
			INNER JOIN T_Mass_Tags_NET AS MTN ON #TmpMassTags.Mass_Tag_ID = MTN.Mass_Tag_ID
			INNER JOIN T_Mass_Tag_to_Protein_Map MTPM ON MT.Mass_Tag_ID = MTPM.Mass_Tag_ID
			LEFT OUTER JOIN T_Mass_Tag_Peptide_Prophet_Stats MTPPS ON MT.Mass_Tag_ID = MTPPS.Mass_Tag_ID
		GROUP BY MT.Mass_Tag_ID, 
			MT.Peptide, 
			MT.Monoisotopic_Mass, 
			MTN.PNET,
			MTN.Avg_GANET ,
			MTN.PNET, 
			MT.High_Normalized_Score, 
			MTN.StD_GANET,
			MT.High_Discriminant_Score,
			MT.Peptide_Obs_Count_Passing_Filter,
			MT.Mod_Count,
			MT.Mod_Description,
			MT.High_Peptide_Prophet_Probability,
			MTPPS.Mass_Tag_ID, 
			MTPPS.ObsCount_CS1, 
			MTPPS.ObsCount_CS2, 
			MTPPS.ObsCount_CS3, 
			MTPPS.PepProphet_FScore_Max_CS1, 
			MTPPS.PepProphet_FScore_Max_CS2, 
			MTPPS.PepProphet_FScore_Max_CS3, 
			MTPPS.PepProphet_Probability_Max_CS1, 
			MTPPS.PepProphet_Probability_Max_CS2, 
			MTPPS.PepProphet_Probability_Max_CS3, 
			MTPPS.PepProphet_FScore_Avg_CS1, 
			MTPPS.PepProphet_FScore_Avg_CS2, 
			MTPPS.PepProphet_FScore_Avg_CS3
		ORDER BY MT.Monoisotopic_Mass

	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


Done:
	Return @myError


GO
GRANT EXECUTE ON [dbo].[GetMassTagsPlusPepProphetStats] TO [DMS_SP_User]
GO
