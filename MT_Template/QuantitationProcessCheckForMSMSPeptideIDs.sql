/****** Object:  StoredProcedure [dbo].[QuantitationProcessCheckForMSMSPeptideIDs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE QuantitationProcessCheckForMSMSPeptideIDs
/****************************************************	
**
**  Desc:	Examines the jobs and Mass_Tag_ID values in #UMCMatchResultsByJob
**			to look for identical peptides identified by MS/MS
**			in the same dataset but using Sequest or XTandem
**
**			The #UMCMatchResultsByJob table must contain columns:
**			 Job, Mass_Tag_ID, and Observed_By_MSMS_in_This_Dataset
**
**  Return values: 0 if success, otherwise, error code
**
**  Auth:	mem
**	Date:	05/28/2007
**			06/08/2007 mem - Added parameters to allow filtering on Normalized score (aka XCorr), Discriminant Score, Peptide Prophet Probabiblity, and PMT Quality Score
**			06/13/2007 mem - Updated to call CheckFilterForAnalysesWork for MTDBs in addition to for Peptide DBs
**			10/17/2007 mem - Updated to filter on Instrument_Class_Filter if applicable
**			10/20/2008 mem - Re-worked the #TmpQRFilterPassingMTs update query to explicitly define the table-joining order
**						   - Added Try/Catch error handling
**			01/06/2012 mem - Updated to use T_Peptides.Job
**			12/05/2012 mem - Added support for MSGFDB and MSAlign (types MSG_Peptide_Hit and MSA_Peptide_Hit)
**
****************************************************/
(
	@CheckResultsInRemotePeptideDBs tinyint = 1,
	@MinimumMTHighNormalizedScore real=0,			-- 0 to use all mass tags, > 0 to filter by XCorr
	@MinimumMTHighDiscriminantScore real=0,			-- 0 to use all mass tags, > 0 to filter by Discriminant Score
	@MinimumMTPeptideProphetProbability real=0,		-- 0 to use all mass tags, > 0 to filter by Peptide_Prophet_Probability
	@MinimumPMTQualityScore real=0,					-- 0 to use all mass tags, > 0 to filter by PMT Quality Score (as currently set in T_Mass_Tags)
	@message varchar(512)='' output
)
AS
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Declare @CurrentJob int
	Declare @DatasetID int
	Declare @PepDBUniqueID int
	Declare @PeptideDBPath varchar(256)
	
	Declare @MatchCount int
	Declare @ProcessNextJob tinyint
	Declare @ProcessNextPeptideDB tinyint
	
	Declare @S nvarchar(max)
	Declare @SParams nvarchar(128)

	Declare @UniqueRowID int
	Declare @ContinuePMTQS tinyint
	Declare @FilterSetID int
	Declare @FilterSetExperimentFilter varchar(128)
	Declare @FilterSetInstrumentClassFilter varchar(128)
	
	Declare @SavedExperimentFilter varchar(128)
	Declare @SavedInstrumentClassFilter varchar(128)

	Declare @JobsTablePopulated tinyint
	Declare @FilterSetsEvaluated int
	Set @FilterSetsEvaluated = 0
	
	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Begin Try

		-----------------------------------------------------------
		-- Validate the inputs
		-----------------------------------------------------------
		--	
		Set @CheckResultsInRemotePeptideDBs = IsNull(@CheckResultsInRemotePeptideDBs, 1)
		Set @message = ''

		Set @MinimumMTHighNormalizedScore = IsNull(@MinimumMTHighNormalizedScore, 0)
		Set @MinimumMTHighDiscriminantScore = IsNull(@MinimumMTHighDiscriminantScore, 0)
		Set @MinimumMTPeptideProphetProbability = IsNull(@MinimumMTPeptideProphetProbability, 0)
		Set @MinimumPMTQualityScore = IsNull(@MinimumPMTQualityScore, 0)

		-----------------------------------------------------------
		-- Create several temporary tables
		-----------------------------------------------------------
		--	
		CREATE TABLE #TmpQRJobsToProcess (
			Job int NOT NULL
		)

		-- Note: SP LookupPeptideDBLocations uses this table and expects it to be named #T_Peptide_Database_List
		CREATE TABLE #T_Peptide_Database_List (
			UniqueID int identity(1,1),
			PeptideDBName varchar(128) NULL,
			PeptideDBID int NULL,
			PeptideDBServer varchar(128) NULL,
			PeptideDBPath varchar(256) NULL
		)

		-- Note: SP GetPMTQualityScoreFilterSetDetails uses this table
		CREATE TABLE #FilterSetDetails (
			Filter_Set_Text varchar(256),
			Filter_Set_ID int NULL,
			Score_Value real NULL,
			Experiment_Filter varchar(128) NULL,
			Instrument_Class_Filter varchar(128) NULL,
			Unique_Row_ID int Identity(1,1)
		)

		-- Note: SP CheckFilterForAnalysesWork uses this table
		CREATE TABLE #JobsInBatch (
			Job int
		)

		-- Note: SP CheckFilterForAnalysesWork uses this table
		CREATE TABLE #PeptideFilterResults (
			Job int NOT NULL ,
			Peptide_ID int NOT NULL ,
			Pass_FilterSet tinyint NOT NULL		
		)

		CREATE TABLE #TmpQRFilterPassingMTs (
			Mass_Tag_ID int NOT NULL,
			Pass_FilterSet tinyint NOT NULL
		)

		CREATE UNIQUE INDEX #IX_TmpQRFilterPassingMTs ON #TmpQRFilterPassingMTs (Mass_Tag_ID)

		CREATE TABLE #TmpPepIDToSeqIDMap (
			Peptide_ID int NOT NULL ,
			Mass_Tag_ID int NOT NULL,
		)

		CREATE INDEX #IX_TmpPepIDToSeqIDMap ON #TmpQRFilterPassingMTs (Mass_Tag_ID)

		
		-----------------------------------------------------------
		-- Populate #TmpQRJobsToProcess using #UMCMatchResultsByJob
		-----------------------------------------------------------
		--
		INSERT INTO #TmpQRJobsToProcess (Job)
		SELECT Job
		FROM #UMCMatchResultsByJob
		GROUP BY Job
		ORDER BY Job
		--
		SELECT @myError = @@error, @myRowCount = @@RowCount

		If @myRowCount = 0
			Set @ProcessNextJob = 0
		Else
			Set @ProcessNextJob = 1
		
		If @ProcessNextJob = 1
		Begin
			-- Initialize @CurrentJob
			Set @CurrentJob = 0
			
			SELECT @CurrentJob = MIN(Job)-1
			FROM #TmpQRJobsToProcess
			
			If @CheckResultsInRemotePeptideDBs <> 0
			Begin
				-- Use the peptide database name(s) in T_Process_Config to populate #T_Peptide_Database_List
				--
				Exec @myError = LookupPeptideDBLocations @message = @message output
				
				-- Note that @myError will be 40000 if no peptide DBs are defined
				-- We'll ignore errors returned by LookupPeptideDBLocations
			End

			If @MinimumPMTQualityScore > 0
			Begin
				-- Populate #FilterSetDetails
				exec @myError = GetPMTQualityScoreFilterSetDetails @message = @message output
				
				If @myError <> 0
				Begin
					-- Post an entry to the log, but continue processing
					execute PostLogEntry 'Error', @message, 'QuantitationProcessCheckForMSMSPeptideIDs'
					Set @message = ''
					Set @myError = 0
				End
				
				-- Remove filter sets from #FilterSetDetails that have Score_Values below @MinimumPMTQualityScore
				DELETE FROM #FilterSetDetails
				WHERE Score_Value < @MinimumPMTQualityScore
				
				-- See if #FilterSetDetails still contains any rows
				-- If not, set @MinimumPMTQualityScore to 0
				
				Set @MatchCount = 0
				SELECT @MatchCount = Count(*)
				FROM #FilterSetDetails
				
				If @MatchCount = 0
					Set @MinimumPMTQualityScore = 0
			End

		End

		-----------------------------------------------------------
		-- Process each of the jobs in #TmpQRJobsToProcess
		-----------------------------------------------------------
		--	

		While @ProcessNextJob = 1
		Begin -- <a>
			-- Get the next job from #TmpQRJobsToProcess
			--
			SELECT TOP 1 @CurrentJob = Job
			FROM #TmpQRJobsToProcess
			WHERE Job > @CurrentJob
			ORDER BY Job
			--
			SELECT @myError = @@error, @myRowCount = @@RowCount

			If @myRowCount = 0
				Set @ProcessNextJob = 0
			Else
			Begin -- <b>
				-- Lookup the Dataset_ID corresponding to @CurrentJob
				--
				SELECT @DatasetID = Dataset_ID
				FROM T_FTICR_Analysis_Description
				WHERE Job = @CurrentJob
				--
				SELECT @myError = @@error, @myRowCount = @@RowCount
				
				If @myRowCount = 0
				Begin
					Set @message = 'Job ' + Convert(varchar(19), @CurrentJob) + ' not found in T_FTICR_Analysis_Description; this is unexpected'
					Execute PostLogEntry 'Error', @message, 'QuantitationProcessWorkStepB'
					Print @message
					Set @message = ''
				End
				Else
				Begin -- <c>
					-- Look for @DatasetID in T_Analysis_Description in this DB
					Set @MatchCount = 0
					
					SELECT @MatchCount = COUNT(*)
					FROM T_Analysis_Description
					WHERE Dataset_ID = @DatasetID
					
					If @MatchCount > 0
					Begin -- <d1>

						-- This database contains Sequest or XTandem results for this dataset; 
						-- look for matching Mass Tags that pass the score filters
						--
						UPDATE #UMCMatchResultsByJob
						SET Observed_By_MSMS_in_This_Dataset = 1
						FROM #UMCMatchResultsByJob UMR INNER JOIN
							(	SELECT DISTINCT Pep.Mass_Tag_ID
								FROM T_Analysis_Description TAD INNER JOIN 
									 T_Peptides Pep ON TAD.Job = Pep.Job 
									 INNER JOIN T_Score_Discriminant SD  ON Pep.Peptide_ID = SD.Peptide_ID 
									 LEFT OUTER JOIN T_Score_XTandem XT  ON Pep.Peptide_ID = XT.Peptide_ID 
									 LEFT OUTER JOIN T_Score_Sequest SS  ON Pep.Peptide_ID = SS.Peptide_ID
									 LEFT OUTER JOIN T_Score_MSGFDB  MSG ON Pep.Peptide_ID = MSG.Peptide_ID
									 LEFT OUTER JOIN T_Score_MSAlign MSA ON Pep.Peptide_ID = MSA.Peptide_ID
								WHERE (TAD.Dataset_ID = @DatasetID) AND
									   (SD.DiscriminantScoreNorm IS NULL OR SD.DiscriminantScoreNorm >= @MinimumMTHighDiscriminantScore) AND
									   (SD.Peptide_Prophet_Probability IS NULL OR SD.Peptide_Prophet_Probability >= @MinimumMTPeptideProphetProbability) AND
									   (SS.XCorr IS NULL OR SS.XCorr >= @MinimumMTHighNormalizedScore) AND
									   (XT.Normalized_Score IS NULL OR XT.Normalized_Score >= @MinimumMTHighNormalizedScore) AND
									   (MSG.Normalized_Score IS NULL OR MSG.Normalized_Score >= @MinimumMTHighNormalizedScore) AND
									   (MSA.Normalized_Score IS NULL OR MSA.Normalized_Score >= @MinimumMTHighNormalizedScore)
							) LookupQ ON
							  UMR.Mass_Tag_ID = LookupQ.Mass_Tag_ID AND
							  UMR.Job = @CurrentJob
						--
						SELECT @myError = @@error, @myRowCount = @@RowCount

						If @MinimumPMTQualityScore > 0
						Begin -- <e>
							-----------------------------------------------------------
							-- Also filtering on PMT Quality Score
							-- Use CheckFilterForAnalysesWork to determine the mass tag IDs that pass @MinimumPMTQualityScore
							-----------------------------------------------------------

							-----------------------------------------------------------
							-- First populate #TmpQRFilterPassingMTs using only those MTs that passed the score filters
							-----------------------------------------------------------
							--
							DELETE FROM #TmpQRFilterPassingMTs
							--
							INSERT INTO #TmpQRFilterPassingMTs (Mass_Tag_ID, Pass_FilterSet)
							SELECT DISTINCT Mass_Tag_ID, 0 AS Pass_FilterSet
							FROM #UMCMatchResultsByJob
							WHERE Observed_By_MSMS_in_This_Dataset = 1 AND
								  Job = @CurrentJob
							--
							SELECT @myError = @@error, @myRowCount = @@RowCount
							
							-----------------------------------------------------------
							-- Now loop through the Filter_Set_ID values in #FilterSetDetails
							-- Call CheckFilterForAnalysesWork for each
							-----------------------------------------------------------

							Set @UniqueRowID = 0
							Set @ContinuePMTQS = 1
							Set @FilterSetsEvaluated = 0
							Set @JobsTablePopulated = 0
							Set @SavedExperimentFilter = ''
							
							While @ContinuePMTQS > 0
							Begin -- <f1>

								-- Process the filter sets in #FilterSetDetails with PMT QS >= @MinimumPMTQualityScore
								-- Keep track of the Mass Tags that pass each filter set

								Set @FilterSetID = 0
								
								SELECT TOP 1 @FilterSetID = Filter_Set_ID,
											 @FilterSetExperimentFilter = IsNull(Experiment_Filter, ''),
											 @FilterSetInstrumentClassFilter = IsNull(Instrument_Class_Filter, ''),
											 @UniqueRowID = Unique_Row_ID
								FROM #FilterSetDetails
								WHERE Unique_Row_ID > @UniqueRowID
								ORDER BY Unique_Row_ID
								--
								SELECT @myError = @@error, @myRowCount = @@RowCount

								If @myRowCount = 0
									Set @ContinuePMTQS = 0
								Else
								Begin -- <g>
								
									-----------------------------------------------------------
									-- Populate #JobsInBatch if @FilterSetExperimentFilter or 
									--  @FilterSetInstrumentClassFilter are changed or if @SavedExperimentFilter Is Null
									-----------------------------------------------------------
									--
									If @JobsTablePopulated = 0 OR 
									   (@SavedExperimentFilter <> @FilterSetExperimentFilter) OR
									   (@SavedInstrumentClassFilter <> @FilterSetInstrumentClassFilter)
									Begin
										DELETE FROM #JobsInBatch
										
										Set @S = ''
										Set @S = @S + ' INSERT INTO #JobsInBatch (Job)'
										Set @S = @S + ' SELECT Job'
										Set @S = @S + ' FROM T_Analysis_Description'
										Set @S = @S + ' WHERE Dataset_ID = ' + Convert(varchar(19), @DatasetID)
										
										If Len(@FilterSetExperimentFilter) > 0
											Set @S = @S +    ' AND Experiment LIKE (''' + @FilterSetExperimentFilter + ''')'

										If Len(@FilterSetInstrumentClassFilter) > 0
											Set @S = @S +    ' AND Instrument_Class LIKE (''' + @FilterSetInstrumentClassFilter + ''')'
											
										Set @S = @S +        ' AND ResultType IN (SELECT ResultType FROM dbo.tblPeptideHitResultTypes())'
										
										Exec @myError = sp_executesql @S

										Set @SavedExperimentFilter = @FilterSetExperimentFilter
										Set @SavedInstrumentClassFilter = @FilterSetInstrumentClassFilter
										
										Set @JobsTablePopulated = 1
									End
									
									-- Only continue if #JobsInBatch contains 1 or more jobs
									Set @MatchCount = 0
									SELECT @MatchCount = COUNT(*)
									FROM #JobsInBatch
									
									If @MatchCount > 0
									Begin  -- <h>
										DELETE FROM #PeptideFilterResults
										
										exec @myError = CheckFilterForAnalysesWork @FilterSetID, @message = @message output
										
										If @myError <> 0
										Begin
											If Len(@message) = 0
												Set @message = 'Error calling CheckFilterForAnalysesWork in this DB'
												
											execute PostLogEntry 'Error', @message, 'QuantitationProcessCheckForMSMSPeptideIDs'
											Set @message = ''
											Set @myError = 0
										End
										Else
										Begin -- <i>
											-- Update #TmpQRFilterPassingMTs using #PeptideFilterResults
											-- The trick here is that #PeptideFilterResults contains Peptide_ID but not Mass_Tag_ID
																					
											UPDATE #TmpQRFilterPassingMTs
											SET Pass_FilterSet = 1
											FROM #TmpQRFilterPassingMTs QRMTs INNER JOIN
												T_Peptides P ON P.Mass_Tag_ID = QRMTs.Mass_Tag_ID INNER JOIN
												#PeptideFilterResults PFR ON P.Peptide_ID = PFR.Peptide_ID
											WHERE PFR.Pass_FilterSet <> 0
											--
											SELECT @myError = @@error, @myRowCount = @@RowCount
											
											
											Set @FilterSetsEvaluated = @FilterSetsEvaluated + 1
										End -- </i>
										
									End -- </h>												
								End -- </g>
							End  -- </f1>
							
							If @FilterSetsEvaluated > 0
							Begin -- <f2>
								-- Un-flag any flagged entries in #UMCMatchResultsByJob
								--  that do not have Pass_FilterSet = 1 in #TmpQRFilterPassingMTs
								
								UPDATE #UMCMatchResultsByJob
								SET Observed_By_MSMS_in_This_Dataset = 0
								FROM #UMCMatchResultsByJob UMR INNER JOIN
									 #TmpQRFilterPassingMTs QRMTs ON UMR.Mass_Tag_ID = QRMTs.Mass_Tag_ID
								WHERE UMR.Observed_By_MSMS_in_This_Dataset = 1 AND
									  UMR.Job = @CurrentJob AND
									  QRMTs.Pass_FilterSet = 0
								--
								SELECT @myError = @@error, @myRowCount = @@RowCount
								
							End -- </f2>
							
						End -- </e>

					End -- </d1>
					Else
					Begin -- <d2>
						-- This database does not contain Sequest or XTandem results for this dataset
						-- Look for @DatasetID in the PT Databases linked to this DB (defined in #T_Peptide_Database_List)
						
						If @CheckResultsInRemotePeptideDBs <> 0
						Begin -- <e>
							Set @PepDBUniqueID = 0
							
							SELECT @PepDBUniqueID = MIN(UniqueID)-1
							FROM #T_Peptide_Database_List
							--
							SELECT @myError = @@error, @myRowCount = @@RowCount
							
							If @myRowCount = 0
								Set @ProcessNextPeptideDB = 0
							Else
								Set @ProcessNextPeptideDB = 1

							While @ProcessNextPeptideDB = 1
							Begin -- <f>
							
								-- Get the next Peptide DB from #T_Peptide_Database_List
								--
								SELECT TOP 1 @PeptideDBPath = PeptideDBPath, @PepDBUniqueID = UniqueID
								FROM #T_Peptide_Database_List
								WHERE UniqueID > @PepDBUniqueID
								ORDER BY UniqueID
								--
								SELECT @myError = @@error, @myRowCount = @@RowCount

								If @myRowCount = 0
									Set @ProcessNextPeptideDB = 0
								Else
								Begin -- <g>
									-- Look for @DatasetID in T_Analysis_Description in the remote DB
									Set @S = ''
									Set @S = @S + ' SELECT @MatchCount = COUNT(*)'
									Set @S = @S + ' FROM ' + @PeptideDBPath + '.dbo.T_Analysis_Description'
									Set @S = @S + ' WHERE Dataset_ID = ' + Convert(varchar(19), @DatasetID)
									Set @S = @S +       ' AND ResultType IN (SELECT ResultType FROM dbo.tblPeptideHitResultTypes())'
									
									Set @MatchCount = 0
									Set @SParams = '@MatchCount int output'
									--
									Exec sp_executesql @S, @SParams, @MatchCount = @MatchCount output
									
									If IsNull(@MatchCount, 0) > 0
									Begin -- <h>
										-- The dataset was found
										-- First test the Score Filters
										
										Set @S = ''
										Set @S = @S + ' UPDATE #UMCMatchResultsByJob '
										Set @S = @S + ' SET Observed_By_MSMS_in_This_Dataset = 1 '
										Set @S = @S + ' FROM #UMCMatchResultsByJob UMR INNER JOIN '
										Set @S = @S +     ' (SELECT DISTINCT Pep.Seq_ID AS Mass_Tag_ID '
										Set @S = @S +      ' FROM ' + @PeptideDBPath + '.dbo.T_Analysis_Description TAD INNER JOIN '
										Set @S = @S +                 @PeptideDBPath + '.dbo.T_Peptides Pep ON TAD.Job = Pep.Job INNER JOIN'
										Set @S = @S +                 @PeptideDBPath + '.dbo.T_Score_Discriminant SD ON Pep.Peptide_ID = SD.Peptide_ID LEFT OUTER JOIN '
										Set @S = @S +                 @PeptideDBPath + '.dbo.T_Score_XTandem XT  ON Pep.Peptide_ID = XT.Peptide_ID LEFT OUTER JOIN '
										Set @S = @S +                 @PeptideDBPath + '.dbo.T_Score_Sequest SS  ON Pep.Peptide_ID = SS.Peptide_ID LEFT OUTER JOIN '
										Set @S = @S +                 @PeptideDBPath + '.dbo.T_Score_MSGFDB  MSG ON Pep.Peptide_ID = MSG.Peptide_ID LEFT OUTER JOIN '
										Set @S = @S +                 @PeptideDBPath + '.dbo.T_Score_MSAlign MSA ON Pep.Peptide_ID = MSA.Peptide_ID '
										Set @S = @S +      ' WHERE TAD.Dataset_ID = ' + Convert(varchar(19), @DatasetID) + ' AND '
										Set @S = @S +           ' (SD.DiscriminantScoreNorm IS NULL OR '
										Set @S = @S +            ' SD.DiscriminantScoreNorm >= ' + Convert(varchar(19), @MinimumMTHighDiscriminantScore) + ') AND '
										Set @S = @S +           ' (SD.Peptide_Prophet_Probability IS NULL OR '
										Set @S = @S +            ' SD.Peptide_Prophet_Probability >= ' + Convert(varchar(19), @MinimumMTPeptideProphetProbability) + ') AND '
										Set @S = @S +           ' (SS.XCorr IS NULL OR SS.XCorr >= ' + Convert(varchar(19), @MinimumMTHighNormalizedScore) + ') AND '
										Set @S = @S +           ' (XT.Normalized_Score IS NULL OR    XT.Normalized_Score >= ' + Convert(varchar(19), @MinimumMTHighNormalizedScore) + ') AND '
										Set @S = @S +           ' (MSG.Normalized_Score IS NULL OR  MSG.Normalized_Score >= ' + Convert(varchar(19), @MinimumMTHighNormalizedScore) + ') AND '
										Set @S = @S +           ' (MSA.Normalized_Score IS NULL OR  MSA.Normalized_Score >= ' + Convert(varchar(19), @MinimumMTHighNormalizedScore) + ')'
										Set @S = @S +     ' ) LookupQ ON '
										Set @S = @S +   ' UMR.Mass_Tag_ID = LookupQ.Mass_Tag_ID AND '
										Set @S = @S +   ' UMR.Job = ' + Convert(varchar(19), @CurrentJob)
										--
										Exec sp_executesql @S
										--
										SELECT @myError = @@error, @myRowCount = @@RowCount

										If @MinimumPMTQualityScore > 0
										Begin -- <i>
											-----------------------------------------------------------
											-- Also filtering on PMT Quality Score
											-- Use CheckFilterForAnalysesWork in the peptide DB to determine the Seq IDs (i.e. mass tag IDs)
											--   that pass @MinimumPMTQualityScore
											-----------------------------------------------------------

											-----------------------------------------------------------
											-- First populate #TmpQRFilterPassingMTs using only those MTs that passed the score filters
											-----------------------------------------------------------
											--
											DELETE FROM #TmpQRFilterPassingMTs
											--
											INSERT INTO #TmpQRFilterPassingMTs (Mass_Tag_ID, Pass_FilterSet)
											SELECT DISTINCT Mass_Tag_ID, 0 AS Pass_FilterSet
											FROM #UMCMatchResultsByJob
											WHERE Observed_By_MSMS_in_This_Dataset = 1 AND 
												  Job = @CurrentJob
											--
											SELECT @myError = @@error, @myRowCount = @@RowCount
											
											-----------------------------------------------------------
											-- Now loop through the Filter_Set_ID values in #FilterSetDetails
											-- Call CheckFilterForAnalysesWork for each
											-----------------------------------------------------------

											Set @UniqueRowID = 0
											Set @ContinuePMTQS = 1
											Set @FilterSetsEvaluated = 0
											Set @JobsTablePopulated = 0
											Set @SavedExperimentFilter = ''
											
											While @ContinuePMTQS > 0
											Begin -- <j1>

												-- Process the filter sets in #FilterSetDetails with PMT QS >= @MinimumPMTQualityScore
												-- Keep track of the Mass Tags that pass each filter set

												Set @FilterSetID = 0
												
												SELECT TOP 1 @FilterSetID = Filter_Set_ID,
															 @FilterSetExperimentFilter = IsNull(Experiment_Filter, ''),
															 @FilterSetInstrumentClassFilter = IsNull(Instrument_Class_Filter, ''),
															 @UniqueRowID = Unique_Row_ID
												FROM #FilterSetDetails
												WHERE Unique_Row_ID > @UniqueRowID
												ORDER BY Unique_Row_ID
												--
												SELECT @myError = @@error, @myRowCount = @@RowCount

												If @myRowCount = 0
													Set @ContinuePMTQS = 0
												Else
												Begin -- <k>
													
													-----------------------------------------------------------
													-- Populate #JobsInBatch if @FilterSetExperimentFilter or 
													--  @FilterSetInstrumentClassFilter are changed or if @SavedExperimentFilter Is Null
													-----------------------------------------------------------
													--
													If @JobsTablePopulated = 0 OR 
													   (@SavedExperimentFilter <> @FilterSetExperimentFilter) OR
													   (@SavedInstrumentClassFilter <> @FilterSetInstrumentClassFilter)
													Begin
														DELETE FROM #JobsInBatch
														
														Set @S = ''
														Set @S = @S + ' INSERT INTO #JobsInBatch (Job)'
														Set @S = @S + ' SELECT Job'
														Set @S = @S + ' FROM ' + @PeptideDBPath + '.dbo.T_Analysis_Description'
														Set @S = @S + ' WHERE Dataset_ID = ' + Convert(varchar(19), @DatasetID)
														
														If Len(@FilterSetExperimentFilter) > 0
															Set @S = @S +    ' AND Experiment LIKE (''' + @FilterSetExperimentFilter + ''')'

														If Len(@FilterSetInstrumentClassFilter) > 0
															Set @S = @S +    ' AND Instrument_Class LIKE (''' + @FilterSetInstrumentClassFilter + ''')'
														
														Set @S = @S +        ' AND ResultType IN (SELECT ResultType FROM dbo.tblPeptideHitResultTypes())'
														
														Exec @myError = sp_executesql @S

														Set @SavedExperimentFilter = @FilterSetExperimentFilter
														Set @SavedInstrumentClassFilter = @FilterSetInstrumentClassFilter
														
														Set @JobsTablePopulated = 1
													End
													
													-- Only continue if #JobsInBatch contains 1 or more jobs
													Set @MatchCount = 0
													SELECT @MatchCount = COUNT(*)
													FROM #JobsInBatch
													
													If @MatchCount > 0
													Begin  -- <l>
														DELETE FROM #PeptideFilterResults
														
														Set @S = 'exec ' + @PeptideDBPath + '.dbo.CheckFilterForAnalysesWork ' + Convert(varchar(12), @FilterSetID) + ', @message = @message output'
														Set @SParams = '@message varchar(512) output'
														--
														Exec @myError = sp_executesql @S, @SParams, @message = @message output

														If @myError <> 0
														Begin
															If Len(@message) = 0
																Set @message = 'Error calling CheckFilterForAnalysesWork in ' + @PeptideDBPath
																
															execute PostLogEntry 'Error', @message, 'QuantitationProcessCheckForMSMSPeptideIDs'
															Set @message = ''
															Set @myError = 0
														End
														Else
														Begin -- <m>
															-- Update #TmpQRFilterPassingMTs using #PeptideFilterResults
															-- The trick here is that #PeptideFilterResults contains Peptide_ID but not Mass_Tag_ID
															
															-- The SQL commented out here should complete successfully
															-- However, it started hanging once PT_Shewanella_ProdTest_A123 surpassed 53 GB in October 2008 (with T_Peptides containing 12,400 jobs and 81 million rows)
															--
															--   UPDATE #TmpQRFilterPassingMTs
															--   SET Pass_FilterSet = 1
															--   FROM #TmpQRFilterPassingMTs QRMTs INNER JOIN 
															--        @PeptideDBPath + '.dbo.T_Peptides P ON P.Seq_ID = QRMTs.Mass_Tag_ID INNER JOIN 
															--        #PeptideFilterResults PFR ON P.Peptide_ID = PFR.Peptide_ID 
															--   WHERE PFR.Pass_FilterSet <> 0
															--
															-- Consequently, we're now performing this update in a 2-step process
															-- First we populate #TmpPepIDToSeqIDMap with the Peptide_ID to Mass_Tag_ID mapping
															-- Then we update #TmpQRFilterPassingMTs

															DELETE FROM #TmpPepIDToSeqIDMap
															
															Set @S = ''
															Set @S = @S + ' INSERT INTO #TmpPepIDToSeqIDMap (Peptide_ID, Mass_Tag_ID)'
															Set @S = @S + ' SELECT P.Peptide_ID, P.Seq_ID'
															Set @S = @S + ' FROM ' + @PeptideDBPath + '.dbo.T_Peptides P'
															Set @S = @S +        ' INNER JOIN #PeptideFilterResults PFR'
															Set @S = @S +          ' ON P.Peptide_ID = PFR.Peptide_ID'
															--
															Exec @myError = sp_executesql @S
															--
															SELECT @myError = @@error, @myRowCount = @@RowCount
															
															UPDATE #TmpQRFilterPassingMTs
															SET Pass_FilterSet = 1
															FROM #PeptideFilterResults PFR
															     INNER JOIN #TmpPepIDToSeqIDMap MapQ
															       ON MapQ.Peptide_ID = PFR.Peptide_ID
															     INNER JOIN #TmpQRFilterPassingMTs QRMTs
															       ON MapQ.Mass_Tag_ID = QRMTs.Mass_Tag_ID
															WHERE PFR.Pass_FilterSet <> 0
															--
															SELECT @myError = @@error, @myRowCount = @@RowCount
															
															Set @FilterSetsEvaluated = @FilterSetsEvaluated + 1
														End -- </m>
														
													End -- </l>												
												End -- </k>
											End  -- </j1>
											
											If @FilterSetsEvaluated > 0
											Begin -- <j2>
												-- Un-flag any flagged entries in #UMCMatchResultsByJob
												--  that do not have Pass_FilterSet = 1 in #TmpQRFilterPassingMTs
												
												UPDATE #UMCMatchResultsByJob
												SET Observed_By_MSMS_in_This_Dataset = 0
												FROM #UMCMatchResultsByJob UMR INNER JOIN
													 #TmpQRFilterPassingMTs QRMTs ON UMR.Mass_Tag_ID = QRMTs.Mass_Tag_ID
												WHERE UMR.Observed_By_MSMS_in_This_Dataset = 1 AND
													  UMR.Job = @CurrentJob AND
													  QRMTs.Pass_FilterSet = 0
												--
												SELECT @myError = @@error, @myRowCount = @@RowCount
												
											End -- </j2>
											
										End -- </i>
									End -- </h>
								End -- </g>
							End -- </f>
						End -- </e>
					End -- </d2>
				End -- </c>
			End -- </b>
		End -- </a>

	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'QuantitationProcessCheckForMSMSPeptideIDs')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, @LogWarningErrorList = '',
								@ErrorNum = @myError output, @message = @message output
	End Catch	
	
Done:
	Return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[QuantitationProcessCheckForMSMSPeptideIDs] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[QuantitationProcessCheckForMSMSPeptideIDs] TO [MTS_DB_Lite] AS [dbo]
GO
