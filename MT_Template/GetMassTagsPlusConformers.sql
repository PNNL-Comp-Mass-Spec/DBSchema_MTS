/****** Object:  StoredProcedure [dbo].[GetMassTagsPlusConformers] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.GetMassTagsPlusConformers
/****************************************************************
**  Desc: Returns mass tags and NET values relevant for PMT peak matching
**		  Also includes conformer information from T_Mass_Tag_Conformers_Observed
**
**  Return values: 0 if success, otherwise, error code 
**
**  Parameters: See comments below
**
**  Auth:	mem
**	Date:	03/24/2011 mem - Initial version (modeled after GetMassTagsPlusPepProphetStats)
**			05/25/2011 mem - Now sorting on Monoisotopic_Mass then Mass_Tag_ID
**			01/06/2012 mem - Updated to use T_Peptides.Job
**			02/28/2012 mem - Now calling AddUpdatePMTCollection to update T_PMT_Collection; if a match is not found, then adds new rows to T_PMT_Collection and T_PMT_Collection_Members
**			               - Added parameter @PMTCollectionID
**			02/29/2012 mem - Updated #Tmp_MTandConformer_Details to include PMT_QS
**			               - Added parameters @AMTCount and @infoOnly
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
	@ConfirmedOnly tinyint = 0,				-- Mass Tag must have Is_Confirmed = 1  (ignored as of February 2012)
	@MinimumHighNormalizedScore float = 0,	-- The minimum value required for High_Normalized_Score; 0 to allow all
	@MinimumPMTQualityScore decimal(9,5) = 0,	-- The minimum PMT_Quality_Score to allow; 0 to allow all
	@NETValueType tinyint = 0,					-- 0 to use GANET values, 1 to use PNET values
	@MinimumHighDiscriminantScore real = 0,		-- The minimum High_Discriminant_Score to allow; 0 to allow all
	@ExperimentFilter varchar(64) = '',				-- If non-blank, then selects PMT tags from datasets with this experiment; ignored if @JobToFilterOnByDataset is non-zero
	@ExperimentExclusionFilter varchar(64) = '',	-- If non-blank, then excludes PMT tags from datasets with this experiment; ignored if @JobToFilterOnByDataset is non-zero
	@JobToFilterOnByDataset int = 0,				-- Set to a non-zero value to only select PMT tags from the dataset associated with the given MS job; useful for matching LTQ-FT MS data to peptides detected during the MS/MS portion of the same analysis; if the job is not present in T_FTICR_Analysis_Description then no data is returned
	@MinimumPeptideProphetProbability real = 0,		-- The minimum High_Peptide_Prophet_Probability value to allow; 0 to allow all
	@MaximumMSGFSpecProb float = 0,					-- The maximum MSGF Spectrum Probability value to allow (examines Min_MSGF_SpecProb in T_Mass_Tags); 0 to allow all
	@PMTCollectionID int = 0 output,
	@AMTCount int = 0 output,				-- Number of rows returned (or that would be returned if @infoOnly = 0)
	@infoOnly int = 0						-- Set to 0 to return the data; set to 1 to preview the results; Set to 2 to update @PMTCollectionID and @AMTCount but not return the specific AMTs
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
	Set @PMTCollectionID = 0
	Set @AMTCount = 0
	Set @infoOnly = IsNull(@infoOnly, 0)
	
	---------------------------------------------------	
	-- Create a temporary table to hold the list of mass tags that match the 
	-- inclusion list criteria and Is_Confirmed requirements
	---------------------------------------------------	
	CREATE TABLE #TmpMassTags (
		Mass_Tag_ID int
	)

	CREATE CLUSTERED INDEX #IX_TmpMassTags ON #TmpMassTags (Mass_Tag_ID ASC)
	
	---------------------------------------------------	
	-- Create a temporary table to hold the MT details
	-- This will be used when calling AddUpdatePMTCollection
	---------------------------------------------------
	--
	CREATE TABLE #Tmp_MTandConformer_Details (
		Mass_Tag_ID int NOT NULL,
		Monoisotopic_Mass float NULL,
		NET real NULL,
		PMT_QS real NULL,
		Conformer_ID int NULL,
		Conformer_Charge smallint NULL,
		Conformer smallint NULL,
		Drift_Time_Avg real NULL
	)

	CREATE CLUSTERED INDEX #IX_Tmp_MTandConformer_Details ON #Tmp_MTandConformer_Details (Mass_Tag_ID ASC, Conformer_ID ASC)


	---------------------------------------------------	
	-- Populate #TmpMassTags with the AMTs to use
	---------------------------------------------------
	--
	Exec @myError = GetMassTagsPassingFiltersWork	
							@MassCorrectionIDFilterList, @ConfirmedOnly, 
							@ExperimentFilter, @ExperimentExclusionFilter, @JobToFilterOnByDataset, 
							@MinimumHighNormalizedScore, @MinimumPMTQualityScore, 
							@MinimumHighDiscriminantScore, @MinimumPeptideProphetProbability,
							@MaximumMSGFSpecProb,
							@DatasetToFilterOn = @DatasetToFilterOn Output							
	
	If @myError <> 0
		Goto Done					
    
	---------------------------------------------------
	-- Join the data in #TmpMassTags with T_Mass_Tags,
	-- T_Mass_Tags_NET, and T_Mass_Tag_Conformers_Observed
	---------------------------------------------------

	If @NETValueType < 0 or @NETValueType > 1
		Set @NETValueType = 0

	If @JobToFilterOnByDataset <> 0
	Begin
		---------------------------------------------------
		-- Possibly create a new PMT_Collection		
		---------------------------------------------------
		
		INSERT INTO #Tmp_MTandConformer_Details( Mass_Tag_ID,
		                                         Monoisotopic_Mass,
		                                         NET,
		                                         PMT_QS,
		                                         Conformer_ID,
		                                         Conformer_Charge,
		                                         Conformer,
		                                         Drift_Time_Avg )
		SELECT MT.Mass_Tag_ID,
		       MT.Monoisotopic_Mass,
		       CASE
		           WHEN @NETValueType = 1 THEN MTN.PNET
		           ELSE MIN(P.GANET_Obs)
		       END AS NET_Value_to_Use,
		       MT.PMT_Quality_Score,
		       MTC.Conformer_ID,
		       MTC.Charge AS Conformer_Charge,
		       MTC.Conformer,
		       MTC.Drift_Time_Avg
		FROM #TmpMassTags
		     INNER JOIN T_Mass_Tags MT ON #TmpMassTags.Mass_Tag_ID = MT.Mass_Tag_ID
		     INNER JOIN T_Peptides P ON MT.Mass_Tag_ID = P.Mass_Tag_ID
		     INNER JOIN T_Mass_Tags_NET MTN ON MT.Mass_Tag_ID = MTN.Mass_Tag_ID
		     INNER JOIN T_Analysis_Description TAD ON P.Job = TAD.Job
		     LEFT OUTER JOIN T_Mass_Tag_Conformers_Observed MTC ON MT.Mass_Tag_ID = MTC.Mass_Tag_ID
		WHERE TAD.Dataset = @DatasetToFilterOn AND
		      P.Max_Obs_Area_In_Job = 1
		GROUP BY MT.Mass_Tag_ID, MT.Monoisotopic_Mass, MTN.PNET, 
		         MTC.Conformer_ID, MTC.Charge, MTC.Conformer, MTC.Drift_Time_Avg
		--
		SELECT @AMTCount = @@RowCount
		
		exec AddUpdatePMTCollection
							@MinimumHighNormalizedScore, @MinimumHighDiscriminantScore, 
							@MinimumPeptideProphetProbability, @MaximumMSGFSpecProb, @MinimumPMTQualityScore, 
							@ExperimentFilter, @ExperimentExclusionFilter, @JobToFilterOnByDataset, 
							@MassCorrectionIDFilterList, @NETValueType, @infoOnly=@infoOnly, @PMTCollectionID = @PMTCollectionID output
		
		
		If @infoOnly = 0
		Begin
			---------------------------------------------------
			-- Return data for just one job
			-- Using GANET_Obs in T_Peptides for each MT's NET
			-- Returning 0 for StD_GANET
			---------------------------------------------------
			--
			SELECT	MT.Mass_Tag_ID, 
					MT.Peptide, 
					MT.Monoisotopic_Mass, 
					CASE WHEN @NETValueType = 1
					THEN MTN.PNET
					ELSE MIN(P.GANET_Obs) 
					END As NET_Value_to_Use, 
					MTN.Cnt_GANET AS NET_Obs_Count,
					MTN.PNET,
					MT.High_Normalized_Score, 
					0 AS StD_GANET,
					MT.High_Discriminant_Score, 
					MT.Peptide_Obs_Count_Passing_Filter,
					MT.Mod_Count,
					MT.Mod_Description,
					MT.High_Peptide_Prophet_Probability,
					MT.Min_MSGF_SpecProb,
					MT.Cleavage_State_Max AS Cleavage_State,
					MTC.Conformer_ID, 
					MTC.Charge AS Conformer_Charge, 
					MTC.Conformer, 
					MTC.Drift_Time_Avg, 
					MTC.Drift_Time_StDev, 
					MTC.Obs_Count AS Conformer_Obs_Count
			FROM #TmpMassTags
				INNER JOIN T_Mass_Tags MT ON #TmpMassTags.Mass_Tag_ID = MT.Mass_Tag_ID 
				INNER JOIN T_Peptides P ON MT.Mass_Tag_ID = P.Mass_Tag_ID 
				INNER JOIN T_Mass_Tags_NET MTN ON MT.Mass_Tag_ID = MTN.Mass_Tag_ID 
				INNER JOIN T_Analysis_Description TAD ON P.Job = TAD.Job
				LEFT OUTER JOIN T_Mass_Tag_Conformers_Observed MTC ON MT.Mass_Tag_ID = MTC.Mass_Tag_ID
			WHERE TAD.Dataset = @DatasetToFilterOn AND
					P.Max_Obs_Area_In_Job = 1
			GROUP BY MT.Mass_Tag_ID, MT.Peptide, MT.Monoisotopic_Mass, MTN.PNET, MTN.Cnt_GANET, MTN.PNET,
					MT.High_Normalized_Score, MT.High_Discriminant_Score, MT.Peptide_Obs_Count_Passing_Filter,
					MT.Mod_Count, MT.Mod_Description, MT.High_Peptide_Prophet_Probability, MT.Min_MSGF_SpecProb, MT.Cleavage_State_Max, 
					MTC.Conformer_ID, MTC.Charge, MTC.Conformer, MTC.Drift_Time_Avg, MTC.Drift_Time_StDev, MTC.Obs_Count
			ORDER BY MT.Monoisotopic_Mass
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
		End

	End
	Else
	Begin
	
		---------------------------------------------------
		-- Possibly create a new PMT_Collection		
		---------------------------------------------------
		
		INSERT INTO #Tmp_MTandConformer_Details( Mass_Tag_ID,
		                                         Monoisotopic_Mass,
		                                         NET,
		                                         PMT_QS,
		                                         Conformer_ID,
		                                         Conformer_Charge,
		                                         Conformer,
		                                         Drift_Time_Avg )
		SELECT MT.Mass_Tag_ID,
		       MT.Monoisotopic_Mass,
		       CASE
		           WHEN @NETValueType = 1 THEN MTN.PNET
		           ELSE MTN.Avg_GANET
		       END AS NET_Value_to_Use,
		       MT.PMT_Quality_Score,
		       MTC.Conformer_ID,
		       MTC.Charge AS Conformer_Charge,
		       MTC.Conformer,
		       MTC.Drift_Time_Avg
		FROM #TmpMassTags
		     INNER JOIN T_Mass_Tags AS MT ON #TmpMassTags.Mass_Tag_ID = MT.Mass_Tag_ID
		     INNER JOIN T_Mass_Tags_NET AS MTN ON #TmpMassTags.Mass_Tag_ID = MTN.Mass_Tag_ID
		     LEFT OUTER JOIN T_Mass_Tag_Conformers_Observed MTC ON MT.Mass_Tag_ID = MTC.Mass_Tag_ID
		--
		SELECT @AMTCount = @@RowCount
		
		exec AddUpdatePMTCollection
							@MinimumHighNormalizedScore, @MinimumHighDiscriminantScore, 
							@MinimumPeptideProphetProbability, @MaximumMSGFSpecProb, @MinimumPMTQualityScore, 
							@ExperimentFilter, @ExperimentExclusionFilter, @JobToFilterOnByDataset, 
							@MassCorrectionIDFilterList, @NETValueType, @infoOnly=@infoOnly, @PMTCollectionID = @PMTCollectionID output
		
	
		If @infoOnly = 0
		Begin
			---------------------------------------------------
			-- Return stats for all matching MTs
			-- Using Avg_GANET in T_Mass_Tags_NET for each MT's NET
			-- Returning StD_GANET from T_Mass_Tags_NET for StD_GANET
			---------------------------------------------------
			--
			SELECT 
				MT.Mass_Tag_ID, 
				MT.Peptide, 
				MT.Monoisotopic_Mass, 
				CASE WHEN @NETValueType = 1 
				THEN MTN.PNET
				ELSE MTN.Avg_GANET 
				END As NET_Value_to_Use, 
				MTN.Cnt_GANET AS NET_Obs_Count,
				MTN.PNET,
				MT.High_Normalized_Score, 
				MTN.StD_GANET,
				MT.High_Discriminant_Score,
				MT.Peptide_Obs_Count_Passing_Filter,
				MT.Mod_Count,
				MT.Mod_Description,
				MT.High_Peptide_Prophet_Probability,
				MT.Min_MSGF_SpecProb,
				MT.Cleavage_State_Max AS Cleavage_State,
				MTC.Conformer_ID, 
				MTC.Charge AS Conformer_Charge, 
				MTC.Conformer, 
				MTC.Drift_Time_Avg, 
				MTC.Drift_Time_StDev, 
				MTC.Obs_Count AS Conformer_Obs_Count			
			FROM #TmpMassTags 
				INNER JOIN T_Mass_Tags AS MT ON #TmpMassTags.Mass_Tag_ID = MT.Mass_Tag_ID
				INNER JOIN T_Mass_Tags_NET AS MTN ON #TmpMassTags.Mass_Tag_ID = MTN.Mass_Tag_ID
				LEFT OUTER JOIN T_Mass_Tag_Conformers_Observed MTC ON MT.Mass_Tag_ID = MTC.Mass_Tag_ID
			ORDER BY MT.Monoisotopic_Mass, MT.Mass_Tag_ID
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
		End

	End

Done:
	Return @myError


GO
GRANT EXECUTE ON [dbo].[GetMassTagsPlusConformers] TO [DMS_SP_User] AS [dbo]
GO
