/****** Object:  StoredProcedure [dbo].[PMLookupFilterThresholdsWork] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure PMLookupFilterThresholdsWork
/****************************************************	
**  Desc:	
**		Determines the filter thresholds used during the peak matching for the given MDIDs
**
**		If @MDIDs is empty, or if none of the entries in @MDIDs is valid,
**		 then uses the thresholds for all entries in T_Match_Making_Description
**
**		If T_Match_Making_Description is empty, then uses the thresholds in T_Peak_Matching_Defaults
**
**		Returns the filter thresholds in temp table #Tmp_ScoreThresholds
**		The calling procedure must create this table
**
**  Return values:	0 if success, otherwise, error code 
**
**  Auth:	mem
**	Date:	07/16/2009
**			10/27/2009 mem - Added support for Minimum_Cleavage_State
**
****************************************************/
(
	@MDIDs varchar(max) = '',				-- If empty (or if no valid MDIDs), then uses all combinations of thresholds in T_Match_Making_Description
	@ComputeMTCounts tinyint = 1,			-- When 1, then computes the number of MTs that pass each of the filter threshold combinations; this could take some time if there is a large number of combinations
	@previewSql tinyint = 0,
	@message varchar(512) = '' output
)
AS
	Set NoCount On

	Declare @myError int
	Declare @myRowcount int
	Set @myRowcount = 0
	Set @myError = 0

	Declare @MinimumHighNormalizedScore real
	Declare @MinimumHighDiscriminantScore real
	Declare @MinimumPeptideProphetProbability real
	Declare @MinimumPMTQualityScore real
	Declare @MinimumCleavageState smallint

	Declare @AMTCount int
	Declare @AMTLastAffectedMax datetime
	
	Declare @EntryID int
	Declare @continue tinyint
	
	Declare @ReturnDefaultThresholds tinyint
	Set @ReturnDefaultThresholds = 1
	
	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Begin Try
		
		-------------------------------------------------
		-- Validate the inputs
		-------------------------------------------------	
		Set @MDIDs = IsNull(@MDIDs, '')
		Set @ComputeMTCounts = IsNull(@ComputeMTCounts, 1)
		Set @previewSql = IsNull(@previewSql, 0)
		Set @message = ''

		-------------------------------------------------
		-- Create two temporary tables
		-------------------------------------------------	

		CREATE TABLE #Tmp_MDIDList (
			MD_ID int NOT NULL
		)
		CREATE UNIQUE INDEX IX_Tmp_MDIDList_MDID ON #Tmp_MDIDList (MD_ID ASC)

		-- Note: This table is used by SP PMPopulateAMTTable, so do not rename it
		CREATE TABLE #Tmp_FilteredMTs (
			Mass_Tag_ID int NOT NULL
		)
		CREATE UNIQUE INDEX IX_Tmp_FilteredMTs_Mass_Tag_ID ON #Tmp_FilteredMTs (Mass_Tag_ID ASC)


		If @MDIDs <> ''
		Begin -- <a>
			-------------------------------------------------
			-- Populate #Tmp_MDIDList with the values in @MDIDs
			-------------------------------------------------	

			exec @myError = PMPopulateMDIDTable @MDIDs, @message = @message output
			if @myError <> 0
				Goto Done

			If Exists (SELECT * FROM #Tmp_MDIDList)
			Begin -- <b>
			
				Set @ReturnDefaultThresholds = 0
				
				-------------------------------------------------	
				-- Populate #Tmp_ScoreThresholds using #Tmp_MDIDList
				-------------------------------------------------	

				INSERT INTO #Tmp_ScoreThresholds( Minimum_High_Normalized_Score,
				                                  Minimum_High_Discriminant_Score,
				                                  Minimum_Peptide_Prophet_Probability,
				                                  Minimum_PMT_Quality_Score,
				                                  Minimum_Cleavage_State,
				                                  MDID_Minimum,
				                                  MDID_Maximum )
				SELECT MMD.Minimum_High_Normalized_Score,
				       MMD.Minimum_High_Discriminant_Score,
				       MMD.Minimum_Peptide_Prophet_Probability,
				       MMD.Minimum_PMT_Quality_Score,
				       0 AS Minimum_Cleavage_State,
				       MIN(MMD.MD_ID) AS MDID_Minimum,
				       MAX(MMD.MD_ID) AS MDID_Maximum
				FROM T_Match_Making_Description MMD
				     INNER JOIN #Tmp_MDIDList ML
				       ON MMD.MD_ID = ML.MD_ID
				GROUP BY Minimum_High_Normalized_Score, 
				         Minimum_High_Discriminant_Score, 
				         Minimum_Peptide_Prophet_Probability,
				         Minimum_PMT_Quality_Score
				--
				SELECT @myError = @@Error, @myRowCount = @@RowCount
			End -- </b>
			
		End -- </a>
		
		If @ReturnDefaultThresholds = 1
		Begin -- <c>
			-------------------------------------------------	
			-- Either @MDIDs is empty or none of the MDIDs 
			-- in @MDIDList is in T_Match_Making_Description
			-------------------------------------------------	

			Set @message = 'Note: Thresholds obtained using all entries in T_Match_Making_Description'
			
			-------------------------------------------------	
			-- Populate #Tmp_ScoreThresholds using all entries in T_Match_Making_Description
			-------------------------------------------------	

			INSERT INTO #Tmp_ScoreThresholds( Minimum_High_Normalized_Score,
			                                  Minimum_High_Discriminant_Score,
			                                  Minimum_Peptide_Prophet_Probability,
			                                  Minimum_PMT_Quality_Score,
			                                  Minimum_Cleavage_State,
			                                  MDID_Minimum,
			                                  MDID_Maximum )
			SELECT MMD.Minimum_High_Normalized_Score,
			       MMD.Minimum_High_Discriminant_Score,
			       MMD.Minimum_Peptide_Prophet_Probability,
			       MMD.Minimum_PMT_Quality_Score,
			       0 AS Minimum_Cleavage_State,
			       MIN(MMD.MD_ID) AS MDID_Minimum,
			       MAX(MMD.MD_ID) AS MDID_Maximum
			FROM T_Match_Making_Description MMD
			GROUP BY Minimum_High_Normalized_Score, 
					 Minimum_High_Discriminant_Score, 
					 Minimum_Peptide_Prophet_Probability,
					 Minimum_PMT_Quality_Score
			--
			SELECT @myError = @@Error, @myRowCount = @@RowCount
			
			If @myRowCount = 0
			Begin -- <d>
				-------------------------------------------------	
				-- No entries in T_Match_Making_Description
				-- Populate #Tmp_ScoreThresholds using T_Peak_Matching_Defaults
				-------------------------------------------------	

				Exec @myError = PMLookupDefaultFilterThresholds
									@MinimumHighNormalizedScore = @MinimumHighNormalizedScore output,
									@MinimumHighDiscriminantScore = @MinimumHighDiscriminantScore output,
									@MinimumPeptideProphetProbability = @MinimumPeptideProphetProbability output,
									@MinimumPMTQualityScore = @MinimumPMTQualityScore output

				INSERT INTO #Tmp_ScoreThresholds( Minimum_High_Normalized_Score,
				                                  Minimum_High_Discriminant_Score,
				                                  Minimum_Peptide_Prophet_Probability,
				                                  Minimum_PMT_Quality_Score,
				                                  Minimum_Cleavage_State, MDID_Minimum, MDID_Maximum 
				                                 )
				VALUES(	@MinimumHighNormalizedScore, 
						@MinimumHighDiscriminantScore,
						@MinimumPeptideProphetProbability, 
						@MinimumPMTQualityScore, 
						0, 0, 0 )
				--
				SELECT @myError = @@Error, @myRowCount = @@RowCount
				      
			End -- </d>
			
		End -- </c>
		
		If @ComputeMTCounts <> 0
		Begin -- <e>
		
			-------------------------------------------------	
			-- Step through #Tmp_ScoreThresholds
			--
			-- For each combination of thresholds, call PMPopulateAMTTable
			--  to count the number of AMTs that pass the threshold
			-------------------------------------------------	

			Set @EntryID = 0
			Set @continue = 1
			
			While @continue = 1
			Begin -- <f>
				SELECT TOP 1 @EntryID = EntryID,
				             @MinimumHighNormalizedScore = Minimum_High_Normalized_Score,
				             @MinimumHighDiscriminantScore = Minimum_High_Discriminant_Score,
				             @MinimumPeptideProphetProbability = Minimum_Peptide_Prophet_Probability,
				             @MinimumPMTQualityScore = Minimum_PMT_Quality_Score,
				             @MinimumCleavageState = Minimum_Cleavage_State
				FROM #Tmp_ScoreThresholds
				WHERE EntryID > @EntryID
				ORDER BY EntryID
				--
				SELECT @myError = @@Error, @myRowCount = @@RowCount
				
				If @myRowCount = 0
					Set @continue = 0
				Else
				Begin -- <g>

					TRUNCATE TABLE #Tmp_FilteredMTs
			
					-------------------------------------------------
					-- Populate #Tmp_FilteredMTs with the AMT tags that pass the 
					--  current set of thresholds
					--
					-- If @CountRowsOnly is non-zero, then @AMTCount is populated
					--   but #Tmp_FilteredMTs is not populated.
					-- However, if there are multiple rows in #Tmp_ScoreThresholds, then
					--  we cannot use the @CountRowsOnly = 1 option
					-------------------------------------------------	
					
					exec @myError = PMPopulateAMTTable 
										@FilterByMDID = 0,
										@UseScoreThresholds = 1,
										@MinimumHighNormalizedScore = @MinimumHighNormalizedScore,
										@MinimumHighDiscriminantScore = @MinimumHighDiscriminantScore,
										@MinimumPeptideProphetProbability = @MinimumPeptideProphetProbability,
										@MinimumPMTQualityScore = @MinimumPMTQualityScore,
										@MinimumCleavageState = @MinimumCleavageState,
										@CountRowsOnly = 1,
										@AMTCount = @AMTCount output,
										@AMTLastAffectedMax = @AMTLastAffectedMax output,
										@previewSql = @previewSql,
										@message = @message output

					If @myError <> 0
						Set @continue = 0
					
					-- Store the AMTCount value in #Tmp_ScoreThresholds
					UPDATE #Tmp_ScoreThresholds
					Set MTCount = @AMTCount,
					    MTLastAffectedMax = @AMTLastAffectedMax
					WHERE EntryID = @EntryID
						
				End -- </g>
				
			End -- </f>
		
		End -- </e>
		
		-------------------------------------------------
		-- Update HashText in #Tmp_ScoreThresholds
		-------------------------------------------------
		--
		UPDATE #Tmp_ScoreThresholds
		SET HashText = Convert(varchar(12), Minimum_High_Normalized_Score) + '_' + 
		                 Convert(varchar(12), Minimum_High_Discriminant_Score) + '_' + 
		                 Convert(varchar(12), Minimum_Peptide_Prophet_Probability) + '_' + 
		                 Convert(varchar(12), Minimum_PMT_Quality_Score) + '_' + 
		                 Convert(varchar(12), Minimum_Cleavage_State) + '_' + 
		                 IsNull(Convert(varchar(12), MTCount), '??') + '_' + 
		                 IsNull(Convert(varchar(32), MTLastAffectedMax, 126), '??')
		
	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'PMLookupFilterThresholdsWork')
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
		Execute PostLogEntry 'Error', @message, 'PMLookupFilterThresholdsWork'
		Print @message
	End

DoneSkipLog:	
	Return @myError


GO
