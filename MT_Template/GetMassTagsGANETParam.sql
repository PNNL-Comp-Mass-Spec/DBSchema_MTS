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
**			09/15/2010 mem - Now returning Cnt_GANET as the 12th column
**			03/24/2011 mem - Added parameter @MaximumMSGFSpecProb
**			01/06/2012 mem - Updated to use T_Peptides.Job
**			02/28/2012 mem - Now calling AddUpdatePMTCollection to update T_PMT_Collection; if a match is not found, then adds new rows to T_PMT_Collection and T_PMT_Collection_Members
**			               - Added parameter @PMTCollectionID
**			02/29/2012 mem - Updated #Tmp_MTandConformer_Details to include PMT_QS
**			               - Added parameters @AMTCount and @infoOnly
**			07/25/2012 mem - Updated #Tmp_MTandConformer_Details to include NET_Count, NET_StDev, Drift_Time_Obs_Count, and Drift_Time_StDev
**			02/12/2014 mem - Now passing @infoOnly to GetMassTagsPassingFiltersWork
**			11/18/2015 mem - Add missing reference to PMT_Quality_Score in the Group By clause when @JobToFilterOnByDataset is non-zero
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
	@MinimumPeptideProphetProbability real = 0,		-- The minimum High_Peptide_Prophet_Probability value to allow; 0 to allow all
	@MaximumMSGFSpecProb float = 0,					-- The maximum MSGF Spectrum Probability value to allow (examines Min_MSGF_SpecProb in T_Mass_Tags); 0 to allow all
	@PMTCollectionID int = 0 output,
	@AMTCount int = 0 output,				-- Number of rows returned (or that would be returned if @infoOnly = 0)
	@infoOnly int = 0						-- Set to 0 to return the data; set to 1 to preview the results; Set to 2 to update @PMTCollectionID and @AMTCount but not return the specific AMTs; Set to 3 to create new entries in T_PMT_Collection but not return any AMTs
)
As
	Set NoCount On

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @DatasetToFilterOn varchar(256)
	Declare @InfoOnlyForAddUpdatePMTCollection int = 0
	
	---------------------------------------------------	
	-- Validate the input parameters
	---------------------------------------------------	
	Set @NETValueType = IsNull(@NETValueType, 0)
	Set @JobToFilterOnByDataset = IsNull(@JobToFilterOnByDataset, 0)
	Set @DatasetToFilterOn = ''
	Set @PMTCollectionID = 0
	Set @AMTCount = 0
	Set @infoOnly = IsNull(@infoOnly, 0)
	
	If @infoOnly IN (1,2)
		Set @InfoOnlyForAddUpdatePMTCollection = @InfoOnly
	Else
		Set @InfoOnlyForAddUpdatePMTCollection = 0
		
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
		NET_Count int NULL,
		NET_StDev real NULL,
		PMT_QS real NULL,
		Conformer_ID int NULL,
		Conformer_Charge smallint NULL,
		Conformer smallint NULL,
		Drift_Time_Avg real NULL,
		Drift_Time_Obs_Count int NULL,
		Drift_Time_StDev real NULL
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
							@DatasetToFilterOn = @DatasetToFilterOn Output,
							@infoOnly = @infoOnly
	
	If @myError <> 0
		Goto Done					
    
	---------------------------------------------------
	-- Join the data in #TmpMassTags with T_Mass_Tags
	-- and T_Mass_Tags_NET
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
		                                         NET_Count,
		                                         NET_StDev,
		                                         PMT_QS,
		                                         Conformer_ID,
		                                         Conformer_Charge,
		                                         Conformer,
		                                         Drift_Time_Avg,
		                                         Drift_Time_Obs_Count,
		                                         Drift_Time_StDev)
		SELECT MT.Mass_Tag_ID,
		       MT.Monoisotopic_Mass,
		       CASE
		           WHEN @NETValueType = 1 THEN MTN.PNET
		           ELSE MIN(P.GANET_Obs)
		       END AS NET_Value_to_Use,
		       1 AS NET_Count,
		       0 AS NET_StDev,
		       MT.PMT_Quality_Score,
		       NULL AS Conformer_ID,
		       NULL AS Conformer_Charge,
		       NULL AS Conformer,
		       NULL AS Drift_Time_Avg,
		       NULL AS Drift_Time_Obs_Count,
		       NULL AS Drift_Time_StDev		       
		FROM #TmpMassTags
		     INNER JOIN T_Mass_Tags MT ON #TmpMassTags.Mass_Tag_ID = MT.Mass_Tag_ID
		     INNER JOIN T_Peptides P ON MT.Mass_Tag_ID = P.Mass_Tag_ID
		     INNER JOIN T_Mass_Tags_NET MTN ON MT.Mass_Tag_ID = MTN.Mass_Tag_ID
		     INNER JOIN T_Analysis_Description TAD ON P.Job = TAD.Job
		WHERE TAD.Dataset = @DatasetToFilterOn AND
		      P.Max_Obs_Area_In_Job = 1
		GROUP BY MT.Mass_Tag_ID, MT.Monoisotopic_Mass, MTN.PNET, MT.PMT_Quality_Score
		--
		SELECT @AMTCount = @@RowCount
		
		exec AddUpdatePMTCollection
							@MinimumHighNormalizedScore, @MinimumHighDiscriminantScore, 
							@MinimumPeptideProphetProbability, @MaximumMSGFSpecProb, @MinimumPMTQualityScore, 
							@ExperimentFilter, @ExperimentExclusionFilter, @JobToFilterOnByDataset, 
							@MassCorrectionIDFilterList, @NETValueType, @infoOnly=@InfoOnlyForAddUpdatePMTCollection, @PMTCollectionID = @PMTCollectionID output


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
					END As Net_Value_to_Use, 
					MTN.PNET,
					MT.High_Normalized_Score, 
					0 AS StD_GANET,
					MT.High_Discriminant_Score, 
					MT.Peptide_Obs_Count_Passing_Filter,
					MT.Mod_Count,
					MT.Mod_Description,
					MT.High_Peptide_Prophet_Probability,
					MTN.Cnt_GANET
			FROM #TmpMassTags
				INNER JOIN T_Mass_Tags MT ON #TmpMassTags.Mass_Tag_ID = MT.Mass_Tag_ID 
				INNER JOIN T_Peptides P ON MT.Mass_Tag_ID = P.Mass_Tag_ID 
				INNER JOIN T_Mass_Tags_NET MTN ON MT.Mass_Tag_ID = MTN.Mass_Tag_ID 
				INNER JOIN T_Analysis_Description TAD ON P.Job = TAD.Job
			WHERE TAD.Dataset = @DatasetToFilterOn AND
					P.Max_Obs_Area_In_Job = 1
			GROUP BY MT.Mass_Tag_ID, MT.Peptide, MT.Monoisotopic_Mass, 
						MT.High_Normalized_Score, MT.High_Discriminant_Score, 
						MT.Peptide_Obs_Count_Passing_Filter, MT.Mod_Count, MT.Mod_Description, 
						MTN.PNET, MTN.Cnt_GANET, MT.High_Peptide_Prophet_Probability
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
		                                         NET_Count,
		                                         NET_StDev,
		                                         PMT_QS,
		                                         Conformer_ID,
		                                         Conformer_Charge,
		                                         Conformer,
		                                         Drift_Time_Avg,
		                                         Drift_Time_Obs_Count,
		                                         Drift_Time_StDev)
		SELECT MT.Mass_Tag_ID,
		       MT.Monoisotopic_Mass,
		       CASE
		           WHEN @NETValueType = 1 THEN MTN.PNET
		           ELSE MTN.Avg_GANET
		       END AS NET_Value_to_Use,
		       CASE
		           WHEN @NETValueType = 1 THEN 1
		           ELSE MTN.Cnt_GANET
		       END AS NET_Count,
		       CASE
		           WHEN @NETValueType = 1 THEN 0
		           ELSE MTN.StD_GANET
		       END AS NET_StDev,
		       MT.PMT_Quality_Score,
		       NULL AS Conformer_ID,
		       NULL AS Conformer_Charge,
		       NULL AS Conformer,
		       NULL AS Drift_Time_Avg,
		       NULL AS Drift_Time_Obs_Count,
		       NULL AS Drift_Time_StDev
		FROM #TmpMassTags
		     INNER JOIN T_Mass_Tags AS MT ON #TmpMassTags.Mass_Tag_ID = MT.Mass_Tag_ID
		     INNER JOIN T_Mass_Tags_NET AS MTN ON #TmpMassTags.Mass_Tag_ID = MTN.Mass_Tag_ID
		--
		SELECT @AMTCount = @@RowCount
		
		exec AddUpdatePMTCollection
							@MinimumHighNormalizedScore, @MinimumHighDiscriminantScore, 
							@MinimumPeptideProphetProbability, @MaximumMSGFSpecProb, @MinimumPMTQualityScore, 
							@ExperimentFilter, @ExperimentExclusionFilter, @JobToFilterOnByDataset, 
							@MassCorrectionIDFilterList, @NETValueType, @infoOnly=@InfoOnlyForAddUpdatePMTCollection, @PMTCollectionID = @PMTCollectionID output


		If @infoOnly = 0
		Begin
			---------------------------------------------------
			-- Return stats for all matching MTs
			-- Using Avg_GANET in T_Mass_Tags_NET for each MT's NET
			-- Returning StD_GANET from T_Mass_Tags_NET for StD_GANET
			---------------------------------------------------
			--
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
				MT.High_Peptide_Prophet_Probability,
				MTN.Cnt_GANET
			FROM #TmpMassTags 
				INNER JOIN T_Mass_Tags AS MT ON #TmpMassTags.Mass_Tag_ID = MT.Mass_Tag_ID
				INNER JOIN T_Mass_Tags_NET AS MTN ON #TmpMassTags.Mass_Tag_ID = MTN.Mass_Tag_ID
			ORDER BY MT.Monoisotopic_Mass
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
		End
			
	End

Done:
	Return @myError


GO
GRANT EXECUTE ON [dbo].[GetMassTagsGANETParam] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetMassTagsGANETParam] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetMassTagsGANETParam] TO [MTS_DB_Lite] AS [dbo]
GO
