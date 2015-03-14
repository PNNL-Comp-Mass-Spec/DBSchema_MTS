/****** Object:  StoredProcedure [dbo].[AddUpdatePMTCollection] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE dbo.AddUpdatePMTCollection
/****************************************************************
**  Desc:	Updates T_PMT_Collection and T_PMT_Collection_Members
**
**			The calling procedure must create and populate table
**
**		CREATE TABLE #Tmp_MTandConformer_Details (
**			Mass_Tag_ID int NOT NULL,
**			Monoisotopic_Mass float NULL,
**			NET real NULL,
**			NET_Count int NULL,
**			NET_StDev real NULL,
**			PMT_QS real NULL,
**			Conformer_ID int NULL,
**			Conformer_Charge smallint NULL,
**			Conformer smallint NULL,
**			Drift_Time_Avg real NULL,
**          Drift_Time_Obs_Count int NULL
**          Drift_Time_StDev real NULL,
**		)
**
**
**  Return values: 0 if success, otherwise, error code 
**
**  Auth:	mem
**	Date:	02/28/2012 mem - Initial version
**			02/29/2012 mem - Now populating PMT_QS in T_PMT_Collection_Members
**			03/01/2012 mem - Now exiting procedure if #Tmp_MTandConformer_Details is empty
**			07/25/2012 mem - Now populating NET_Count, NET_StDev, Drift_Time_Obs_Count, and Drift_Time_StDev in T_PMT_Collection_Members
**  
****************************************************************/
(
	@MinimumHighNormalizedScore real,				-- The minimum value required for High_Normalized_Score; 0 to allow all
	@MinimumHighDiscriminantScore real,				-- The minimum High_Discriminant_Score to allow; 0 to allow all
	@MinimumPeptideProphetProbability real,			-- The minimum High_Peptide_Prophet_Probability value to allow; 0 to allow all
	@MaximumMSGFSpecProb real,						-- The maximum MSGF Spectrum Probability value to allow (examines Min_MSGF_SpecProb in T_Mass_Tags); 0 to allow all
	@MinimumPMTQualityScore real,					-- The minimum PMT_Quality_Score to allow; 0 to allow all

	@ExperimentFilter varchar(64) = '',				-- If non-blank, then selects PMT tags from datasets with this experiment; ignored if @JobToFilterOnByDataset is non-zero
	@ExperimentExclusionFilter varchar(64) = '',	-- If non-blank, then excludes PMT tags from datasets with this experiment; ignored if @JobToFilterOnByDataset is non-zero
	@JobToFilterOnByDataset int = 0,				-- Set to a non-zero value to only select PMT tags from the dataset associated with the given MS job; useful for matching LTQ-FT MS data to peptides detected during the MS/MS portion of the same analysis; if the job is not present in T_FTICR_Analysis_Description then no data is returned

	@MassCorrectionIDFilterList varchar(255) = '',	-- Mass tag modification masses inclusion list, leave blank or Null to include all mass tags; see GetMassTagsPlusConformers for the gory details of this parameter
	@NETValueType tinyint = 0,						-- 0 to use GANET values, 1 to use PNET values
	@infoOnly tinyint = 0,							-- Set to 1 to preview the results; Set to 2 to update @PMTCollectionID if a matching collection is found, but not preview the results
	@PMTCollectionID int = 0 output,                -- Matching PMT_Collection_ID; 0 if no match
	@message varchar(128) = '' output

)
As
	Set NoCount On

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	Declare @CreateNewCollection tinyint = 1
	Declare @CheckPMTCollection varchar(24) = 'Check_PMT_Collection'
	
	DECLARE @TmpCandidateIDs AS Table (
		PMT_Collection_ID int NOT NULL
	 )
	 
	---------------------------------------------------	
	-- Validate the input parameters
	---------------------------------------------------	
	
	Set @MinimumHighNormalizedScore = IsNull(@MinimumHighNormalizedScore, 0)
	Set @MinimumHighDiscriminantScore = IsNull(@MinimumHighDiscriminantScore, 0)
	Set @MinimumPeptideProphetProbability = IsNull(@MinimumPeptideProphetProbability, 0)
	Set @MaximumMSGFSpecProb = IsNull(@MaximumMSGFSpecProb, 0)
	Set @MinimumPMTQualityScore = IsNull(@MinimumPMTQualityScore, 0)
	
	Set @ExperimentFilter = IsNull(@ExperimentFilter, '')
	Set @ExperimentExclusionFilter = IsNull(@ExperimentExclusionFilter, '')
	Set @JobToFilterOnByDataset = IsNull(@JobToFilterOnByDataset, 0)

	Set @MassCorrectionIDFilterList = IsNull(@MassCorrectionIDFilterList, '')
	Set @NETValueType = IsNull(@NETValueType, 0)

	Set @infoOnly = IsNull(@infoOnly, 0)
	Set @PMTCollectionID = 0
	Set @message = ''
	
	-- Initially assume we will need to create a new collection
	Set @CreateNewCollection = 1

	---------------------------------------------------	
	-- Count the number of AMTs and Conformers in #Tmp_MTandConformer_Details
	---------------------------------------------------	
	
	Declare @AMTCount int = 0
	Declare @AMTCountDistinct int = 0
	Declare @ConformerCount int = 0
	
	SELECT @AMTCount = COUNT(*),
	       @AMTCountDistinct = COUNT(Distinct Mass_Tag_ID),
	       @ConformerCount = IsNull(SUM (CASE WHEN Conformer_ID IS NULL Then 0 Else 1 End), 0)
	FROM #Tmp_MTandConformer_Details
	
	If @AMTCount = 0
	Begin
		Set @message = '#Tmp_MTandConformer_Details is empty; nothing to do'
		Set @myError = 0
		Goto Done
	End
	
	Begin Tran @CheckPMTCollection
	
	---------------------------------------------------	
	-- See if any potential entries already exist in T_PMT_Collection
	-- There could be more than one entry if the filter values are the same, but the MT details differ
	-- The where-clause accounts for the fact that we commonly use Normalized_Score_Min of 0 and 1 interchangably
	---------------------------------------------------	
	--
	INSERT INTO @TmpCandidateIDs (PMT_Collection_ID)
	SELECT PMT_Collection_ID
	FROM T_PMT_Collection
	WHERE (Normalized_Score_Min = @MinimumHighNormalizedScore OR 
	       Normalized_Score_Min IN (0, 1) And @MinimumHighNormalizedScore IN (0, 1)) AND
	      Discriminant_Score_Min = @MinimumHighDiscriminantScore AND
	      Peptide_Prophet_Min = @MinimumPeptideProphetProbability AND
	      MSGF_SpecProb_Max = @MaximumMSGFSpecProb AND
	      PMT_QS_Min = @MinimumPMTQualityScore AND
	      NET_Value_Type = @NETValueType AND
	      Experiment_Filter = @ExperimentFilter AND
	      Experiment_Exclusion_Filter = @ExperimentExclusionFilter AND
	      Job_To_Filter_On_By_Dataset = @JobToFilterOnByDataset AND
	      MassCorrectionID_Filter_List = @MassCorrectionIDFilterList AND
	      AMT_Count = @AMTCount AND
	      AMT_Count_Distinct = @AMTCountDistinct AND
	      Conformer_Count = @ConformerCount
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	If @myRowCount > 0
	Begin -- <a>
		DECLARE @rowCountExpected int = 0
		
		SELECT @rowCountExpected = COUNT(*)
		FROM #Tmp_MTandConformer_Details
		
		If @rowCountExpected > 0
		Begin -- <b>

			-- Compare the entries in T_PMT_Collection_Members to each ID in @TmpCandidateIDs
			-- If any match, update @PMTCollectionID for the match
			-- Otherweise, make a new collection
			-- Note that we're stepping through @TmpCandidateIDs in reverse, favoring higher values of PMT_Collection_ID

			Declare @rowCountMatching int
			Declare @CurrentPMTCollectionID int
			Declare @Continue tinyint = 1

			SELECT @CurrentPMTCollectionID = MAX(PMT_Collection_ID) + 1
			FROM @TmpCandidateIDs
			
			While @Continue = 1
			Begin -- <c>
				SELECT TOP 1 @CurrentPMTCollectionID = PMT_Collection_ID
				FROM @TmpCandidateIDs
				WHERE PMT_Collection_ID < @CurrentPMTCollectionID
				ORDER BY PMT_Collection_ID DESC
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
	
				If @myRowCount = 0
					Set @Continue = 0
				Else
				Begin -- <d>
					Set @rowCountMatching = 0
					
					SELECT @rowCountMatching = COUNT(*)
					FROM T_PMT_Collection_Members ColA
					     INNER JOIN #Tmp_MTandConformer_Details ColB
					       ON ColA.Mass_Tag_ID = ColB.Mass_Tag_ID AND
					          IsNull(ColA.Conformer_ID, 0) = IsNull(ColB.Conformer_ID, 0)
					WHERE ColA.PMT_Collection_ID = @CurrentPMTCollectionID AND
					      IsNull(ColA.Monoisotopic_Mass, 0) = IsNull(ColB.Monoisotopic_Mass, 0) AND
					      IsNull(ColA.NET, 0) = IsNull(ColB.NET, 0) AND
					      IsNull(ColA.Conformer_Charge, 0) = IsNull(ColB.Conformer_Charge, 0) AND
					      IsNull(ColA.Conformer, 0) = IsNull(ColB.Conformer, 0) AND
					      IsNull(ColA.Drift_Time_Avg, 0) = IsNull(ColB.Drift_Time_Avg, 0) AND
					      IsNull(ColA.PMT_QS, 0) = IsNull(ColB.PMT_QS, 0)
					
					If @rowCountExpected = @rowCountMatching
					Begin -- </e>
					
						-- Matching collection found
						--
						Set @PMTCollectionID = @CurrentPMTCollectionID
						
						If @InfoOnly = 0
						Begin
							UPDATE T_PMT_Collection
							SET Last_Used = GetDate(),
								Usage_Count = Usage_Count + 1
							WHERE PMT_Collection_ID = @PMTCollectionID
						End

						Set @CreateNewCollection = 0
						Set @message = 'Found existing PMT collection: ' + Convert(varchar(12), @PMTCollectionID)
						Set @myError = 0

						Set @Continue = 0
						
					End -- </e>
					
				End -- </d>				
			End -- </c>
			
		End -- </b>
	End -- </a>
	
	
	If @CreateNewCollection = 0
	Begin
		If @InfoOnly = 1
		Begin
			SELECT *
			FROM T_PMT_Collection
			WHERE PMT_Collection_ID = @PMTCollectionID
		End
	End
	Else
	Begin -- <x>
	
		Set @PMTCollectionID = 0
		
		If @InfoOnly <> 0
		Begin 
			If @InfoOnly = 1
			Begin
				SELECT 'New' AS PMT_Collection_ID,
					Mass_Tag_ID,
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
					Drift_Time_StDev					
				FROM #Tmp_MTandConformer_Details
				ORDER BY Mass_Tag_ID, Conformer_ID
			End
		End
		Else
		Begin -- <y>
			
			-- Add a new row to T_PMT_Collection
			--
			INSERT INTO T_PMT_Collection ( Normalized_Score_Min,
										   Discriminant_Score_Min,
										   Peptide_Prophet_Min,
										   MSGF_SpecProb_Max,
										   PMT_QS_Min,
										   NET_Value_Type,
										   Experiment_Filter,
										   Experiment_Exclusion_Filter,
										   Job_To_Filter_On_By_Dataset,
										   MassCorrectionID_Filter_List,
										   AMT_Count,
										   AMT_Count_Distinct,
										   Conformer_Count,
										   Entered,
										   Last_Used,
										   Usage_Count )
			VALUES ( @MinimumHighNormalizedScore, @MinimumHighDiscriminantScore, @MinimumPeptideProphetProbability,
			         @MaximumMSGFSpecProb, @MinimumPMTQualityScore, @NETValueType, 
			         @ExperimentFilter, @ExperimentExclusionFilter, @JobToFilterOnByDataset, @MassCorrectionIDFilterList, 
			         @AMTCount, @AMTCountDistinct, @ConformerCount, GetDate(), GetDate(), 1)
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount, @PMTCollectionID = SCOPE_IDENTITY()

			If @myError <> 0
			Begin
				ROLLBACK TRANSACTION @CheckPMTCollection
				Set @message = 'Error adding new row to T_PMT_Collection'
				Set @myError = 50000
				Goto Done
			End
			
			-- Append new rows to T_PMT_Collection_Members
			--
			INSERT INTO T_PMT_Collection_Members ( PMT_Collection_ID,
			                                       Mass_Tag_ID,
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
			SELECT @PMTCollectionID AS PMT_Collection_ID,
			       Mass_Tag_ID,
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
			       Drift_Time_StDev		       			       
			FROM #Tmp_MTandConformer_Details
			ORDER BY Mass_Tag_ID, Conformer_ID
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			If @myError <> 0
			Begin
				ROLLBACK TRANSACTION @CheckPMTCollection
				Set @message = 'Error adding new rows to T_PMT_Collection_Members'
				Set @myError = 50001
				Goto Done
			End
			
			Set @message = 'Created new PMT collection: ' + Convert(varchar(12), @PMTCollectionID)
			Set @myError = 0
			
		End -- </y>
	End -- </x>
	
	
	Commit Tran @CheckPMTCollection


Done:
	If @myError <> 0 And @InfoOnly = 0
	Begin
		Exec PostLogEntry 'Error', @message, 'AddUpdatePMTCollection'
	End
	
	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[AddUpdatePMTCollection] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[AddUpdatePMTCollection] TO [MTS_DB_Lite] AS [dbo]
GO
