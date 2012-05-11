/****** Object:  StoredProcedure [dbo].[CheckFilterForAvailableAnalysesBulk] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE CheckFilterForAvailableAnalysesBulk
/****************************************************
**
**	Desc: 	Compare the peptides for each of the available analyses 
**			against the given filter set
**
**	Return values: 0:  success, otherwise, error code
**
**	Parameters:
**
**	Auth:	grk
**	Date:	11/2/2001
**			03/01/2004 mem - Switched from using a cursor to using temporary tables; this greatly improves efficiency of checking whether jobs need to be checked against the filter
**								 Additionally, implemented the @ReprocessAllJobs option and added the @numJobsToProcess parameter
**		    07/03/2004 mem - Changed to use of Process_State and ResultType fields for choosing next job
**			08/07/2004 mem - Added @ProcessStateMatch, @NextProcessState, and @numJobsProcessed parameters
**			09/06/2004 mem - Now processing multiple jobs simultaneously, but with a maximum number of peptides to process per bulk operation
**			09/12/2004 mem - Switched to using T_Peptide_to_Protein_Map
**		    11/08/2004 mem - Now looking for jobs in a state > @ProcessStateMatch that have not been checked against @filterSetID; resets state to @ProcessStateMatch for any found
**						   - Additionally, no longer advancing the state of processed jobs, since this SP could easily be called several times for different filters within the same update cycle
**			12/13/2004 mem - Updated to excluded MASIC jobs
**			12/28/2004 mem - Fixed bug that was reprocessing jobs that didn't need to be reprocessed
**			01/31/2005 mem - Updated to delete entries in T_Analysis_Filter_Flags for jobs in State @ProcessStateMatch with Filter ID @filterSetID
**			03/25/2005 mem - Fixed bug that used the peptide sequence in T_Peptides to determine peptide length, rather than T_Sequences.Clean_Sequence
**			03/26/2005 mem - Updated call to GetThresholdsForFilterSet to include @ProteinCount and @TerminusState criteria
**			11/24/2005 mem - Now updating Last_Affected when rolling job states back to state @ProcessStateMatch if needing to reprocess the filters
**			11/26/2005 mem - Now rolling back job states to @ProcessStateFilterEvaluationRequired rather than to state @ProcessStateMatch
**			12/12/2005 mem - Updated to support XTandem results
**			07/04/2006 mem - Added parameter @ProcessStateAllStepsComplete
**			06/08/2007 mem - Now calling CheckFilterForAnalysesWork for each batch of jobs to process
**			10/10/2008 mem - Added support for result type IN_Peptide_Hit
**			08/22/2011 mem - Added support for result type MSG_Peptide_Hit
**			09/17/2011 mem - Now calling CheckFilterUsingCustomCriteria if @filterSetID is < 100
**			01/06/2012 mem - Updated to use T_Peptides.Job
**    
*****************************************************/
(
	@filterSetID int,							-- Note: If less than 100, then calls CheckFilterUsingCustomCriteria; you must supply a table name using @CustomFilterTableName
	@ReprocessAllJobs tinyint = 0,				-- If nonzero, then will reprocess all jobs against the given filter
	@ProcessStateMatch int = 60,
	@ProcessStateFilterEvaluationRequired int = 65,
	@ProcessStateAllStepsComplete int = 70,
	@numJobsToProcess int = 50000,
	@CustomFilterTableName varchar(128) = '',
	@numJobsProcessed int = 0 OUTPUT,
	@infoOnly tinyint = 0
)
AS
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	declare @message varchar(255)
	declare @Job int
	declare @PeptideCountForJob int
	declare @SkipProcessedJobs tinyint		-- If nonzero, then will skip jobs already checked against filter @filterSetID
	
	Declare @LastJobPolled int
	declare @peptideMatchCount int
	declare	@peptideUnmatchedCount int
	
	declare @jobMatchCount int
	declare @intContinue int	

	declare @JobAvailableCount int 
	declare @AddnlJobAvailableCount int
	declare @TotalHitCount int

	declare @PeptidesInBatch int
	declare @JobsInBatch int
	declare @ResultTypeID int

	declare @MaxPeptidesPerBatch int
	Set @MaxPeptidesPerBatch = 25000

	declare @ResultType varchar(32)
	Set @ResultType = 'Unknown'
	
	declare @filterSetStr varchar(11)
	Set @filterSetStr = Convert(varchar(11), @filterSetID)

	set @TotalHitCount = 0
	set @numJobsProcessed = 0

	Declare @JobList varchar(max)
	Declare @CheckFilterProcedureName varchar(64) = ''
	
	-----------------------------------------------------------
	-- Create the temporary tables to hold the jobs to process
	-----------------------------------------------------------
	CREATE TABLE #JobsToProcess (
		Job int,
		ResultType varchar(32),
		PeptideCount int
	)

	CREATE TABLE #JobsInBatch (
		Job int,
		PeptideCount int,
		MatchCount int NULL,
		UnmatchedCount int NULL
	)

	-----------------------------------------------------------
	-- Create a table that lists the peptides in each job
	-- and whether or not they pass the filterset
	-----------------------------------------------------------
	
	CREATE TABLE #PeptideFilterResults (
		Job int NOT NULL ,
		Peptide_ID int NOT NULL ,
		Pass_FilterSet tinyint NOT NULL			-- 0 or 1
	)
	
	CREATE UNIQUE INDEX #IX_PeptideFilterResults ON #PeptideFilterResults (Peptide_ID)

	-----------------------------------------------
	-- Populate a temporary table with the list of known Result Types
	-----------------------------------------------
	CREATE TABLE #T_ResultTypeList (
		UniqueID int IDENTITY(1,1),
		ResultType varchar(64)
	)
	
	INSERT INTO #T_ResultTypeList (ResultType) Values ('Peptide_Hit')
	INSERT INTO #T_ResultTypeList (ResultType) Values ('XT_Peptide_Hit')
	INSERT INTO #T_ResultTypeList (ResultType) Values ('IN_Peptide_Hit')
	INSERT INTO #T_ResultTypeList (ResultType) Values ('MSG_Peptide_Hit')


	-----------------------------------------------------------
	-- Set @SkipProcessedJobs to 1 when the process state to match is
	-- the same as @ProcessStateFilterEvaluationRequired
	-----------------------------------------------------------
	If @ProcessStateMatch = @ProcessStateFilterEvaluationRequired
		Set @SkipProcessedJobs = 1


	-----------------------------------------------------------
	-- process list of analyses 
	-----------------------------------------------------------

	if @ReprocessAllJobs <> 0
	Begin
		-- Reprocessing all jobs, assure that @SkipProcessedJobs is 0
		Set @SkipProcessedJobs = 0
		
		-- Delete entries from T_Analysis_Filter_Flags for @filterSetID
		DELETE FROM T_Analysis_Filter_Flags
		WHERE Filter_ID = @filterSetID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0
		 begin
			set @message = 'Error deleting existing entries in T_Analysis_Filter_Flags matching filter set ' + @filterSetStr
			set @myError = 51101
			goto Done
		 end

		-- Delete entries from T_Peptide_Filter_Flags for @filterSetID
		DELETE FROM T_Peptide_Filter_Flags
		WHERE Filter_ID = @filterSetID
		--
		SELECT @myError = @@error, @peptideMatchCount = @@RowCount
		--
		if @myError <> 0
		 begin
			set @message = 'Error deleting existing entries in T_Peptide_Filter_Flags matching filter set ' + @filterSetStr
			set @myError = 51102
			goto Done
		 end
		else
		 begin
			-- Post an entry to T_Log_Entries
			Set @message = 'Re-checking all analyses against filter set ' + @filterSetStr + ' (Deleted ' + convert(varchar(11), @peptideMatchCount) + ' rows from T_Peptide_Filter_Flags)'
			Execute PostLogEntry 'Normal', @message, 'CheckFilterForAvailableAnalysesBulk'
			Set @message = ''
		 end

	End


	-----------------------------------------------------------
	-- Update jobs in T_Analysis_Description that have a state
	-- between @ProcessStateFilterEvaluationRequired+1 and 
	-- @ProcessStateAllStepsComplete but have not yet been tested 
	-- against this filter
	-----------------------------------------------------------
	--
	UPDATE T_Analysis_Description
	SET Process_State = @ProcessStateFilterEvaluationRequired,
	    Last_Affected = GETDATE()
	FROM T_Analysis_Description AS TAD INNER JOIN
		 #T_ResultTypeList AS RTL ON TAD.ResultType = RTL.ResultType LEFT OUTER JOIN
		 T_Analysis_Filter_Flags AS AFF ON TAD.Job = AFF.Job AND AFF.Filter_ID = @filterSetID
	WHERE (TAD.Process_State BETWEEN @ProcessStateFilterEvaluationRequired+1 AND @ProcessStateAllStepsComplete) AND 
		  AFF.Job Is Null
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Error resetting Process_State for jobs'
		set @myError = 51103
		goto Done
	end

	if @myRowCount > 0
	Begin
		-- make log entry
		Declare @TextNum varchar(9)
		Set @TextNum = Convert(varchar(9), @ProcessStateFilterEvaluationRequired)
		
		Set @message = 'Jobs were found with state > ' + @TextNum + ' which have not been checked against Filter Set ID ' + Convert(varchar(9), @filterSetID) + '; their states have been reset to ' + @TextNum
		execute PostLogEntry 'Warning', @message, 'CheckFilterForAvailableAnalysesBulk'
		Set @message = ''
	End


	if @ReprocessAllJobs = 0 and @SkipProcessedJobs = 0
	Begin
	
		-----------------------------------------------------------
		-- Make sure jobs in state @ProcessStateMatch do not have
		-- an entry in T_Analysis_Filter_Flags
		-----------------------------------------------------------
	
		DELETE T_Analysis_Filter_Flags
		FROM T_Analysis_Filter_Flags AS AFF INNER JOIN
			 T_Analysis_Description AS TAD ON 
			 AFF.Job = TAD.Job 
		WHERE (TAD.Process_State = @ProcessStateMatch) AND (AFF.Filter_ID = @filterSetID)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0
		 begin
			set @message = 'Error deleting entries in T_Analysis_Filter_Flags for jobs in state ' + convert(varchar(9), @ProcessStateMatch)
			set @myError = 51104
			goto Done
		 end
	End

	-----------------------------------------------------------
	-- Get list of analyses that need to be checked against @filterSetID
	-----------------------------------------------------------
	--
	INSERT INTO #JobsToProcess (Job, ResultType, PeptideCount)
	SELECT TAD.Job, TAD.ResultType, IsNull(COUNT(P.Peptide_ID), 0) AS PeptideCount
	FROM T_Analysis_Description AS TAD INNER JOIN
		 #T_ResultTypeList AS RTL ON TAD.ResultType = RTL.ResultType LEFT OUTER JOIN 
		 T_Peptides AS P ON TAD.Job = P.Job
	WHERE TAD.Process_State = @ProcessStateMatch AND
		 TAD.Job NOT IN (	SELECT Job
							FROM T_Analysis_Filter_Flags
							WHERE Filter_ID = @filterSetID)
	GROUP BY TAD.ResultType, TAD.Job
	ORDER BY TAD.ResultType, TAD.Job
	--
	SELECT @myError = @@error, @JobAvailableCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Error populating #JobsToProcess with the jobs to process'
		set @myError = 51105
		goto Done
	end

	-----------------------------------------------------------
	-- Lookup the first ResultType
	-----------------------------------------------------------
	Set @ResultTypeID = 0
	--	
	SELECT TOP 1 @ResultType = ResultType, @ResultTypeID = UniqueID
	FROM #T_ResultTypeList
	WHERE UniqueID > @ResultTypeID
	ORDER BY UniqueID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	
	-- Loop through the available jobs, and process them in groups
	-- In addition, group the jobs by ResultType
	--
	While Len(IsNull(@ResultType, '')) > 0 And @myError = 0 And @numJobsProcessed < @numJobsToProcess
	Begin -- <a>
		-- See if at least one job is available with ResultType = @ResultType
		SELECT TOP 1 @job = Job, @PeptideCountForJob = PeptideCount
		FROM #JobsToProcess
		WHERE ResultType = @ResultType
		ORDER BY Job
		--
		SELECT @myError = @@error, @JobAvailableCount = @@rowcount
		--
		if @myError <> 0
		begin
			set @message = 'Could not get next entry from #JobsToProcess'
			set @myError = 51106
			goto Done
		end

		If @JobAvailableCount = 0
		Begin
			-----------------------------------------------------------
			-- No more available jobs for ResultType @ResultType
			-- Lookup the next ResultType
			-----------------------------------------------------------
			--
			SELECT TOP 1 @ResultType = ResultType, @ResultTypeID = UniqueID
			FROM #T_ResultTypeList
			WHERE UniqueID > @ResultTypeID
			ORDER BY UniqueID
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			
			-- If no more ResultTypes, then set @ResultType to '' so that the While Loop exits
			If @myRowCount = 0
				Set @ResultType = ''
		End
		Else 
		Begin -- <b>
			-- Populate #JobsInBatch with jobs from #JobsToProcess,
			-- limiting the list to at most @MaxPeptidesPerBatch peptides
		
			-- Delete this job from #JobsToProcess
			DELETE FROM #JobsToProcess 
			WHERE Job = @Job
		
			-- Reset #JobsInBatch
			TRUNCATE TABLE #JobsInBatch
			
			INSERT INTO #JobsInBatch (Job, PeptideCount, MatchCount, UnmatchedCount)
			VALUES (@job, @PeptideCountForJob, 0, 0)

			Set @PeptidesInBatch = @PeptideCountForJob
			Set @JobsInBatch = 1
			Set @AddnlJobAvailableCount = 1
			
			-- Add additional jobs to #JobsInBatch
			While @PeptidesInBatch < @MaxPeptidesPerBatch AND @AddnlJobAvailableCount > 0 AND @numJobsProcessed + @JobsInBatch < @numJobsToProcess
			Begin -- <c>
				SELECT TOP 1 @job = Job, @PeptideCountForJob = PeptideCount
				FROM #JobsToProcess
				WHERE ResultType = @ResultType
				ORDER BY Job
				--
				SELECT @myError = @@error, @AddnlJobAvailableCount = @@rowcount
			
				If @AddnlJobAvailableCount = 1
				Begin
					If @PeptidesInBatch + @PeptideCountForJob < @MaxPeptidesPerBatch
					Begin
						-- Delete this job from #JobsToProcess
						DELETE FROM #JobsToProcess WHERE Job = @Job
					
						INSERT INTO #JobsInBatch (Job, PeptideCount, MatchCount, UnmatchedCount)
						VALUES (@job, @PeptideCountForJob, 0, 0)

						Set @PeptidesInBatch = @PeptidesInBatch + @PeptideCountForJob
						Set @JobsInBatch = @JobsInBatch + 1
					End					
					Else
						Set @AddnlJobAvailableCount = 0
				End
			End -- </c>
		
			-----------------------------------------------------------
			-- Process the jobs in #JobsInBatch
			--
			-- If necessary, remove entries in T_Analysis_Filter_Flags
			-- for jobs in #JobsInBatch with entries for @filterSetID
			-----------------------------------------------------------
			--
			Set @jobMatchCount = 0
			--
			SELECT @jobMatchCount = COUNT(*) 
			FROM T_Analysis_Filter_Flags INNER JOIN #JobsInBatch ON
				 T_Analysis_Filter_Flags.Job = #JobsInBatch.Job
			WHERE Filter_ID = @filterSetID
			--
			SELECT @myError = @@error, @myRowCount = @@RowCount
			--
			If @myError <> 0
			Begin
				set @message = 'Could not get analysis job flag information for jobs in #JobsInBatch'
				goto Done
			End
			
			If @jobMatchCount > 0 
			Begin
				-- Delete entries for jobs and given filter from T_Analysis_Filter_Flags
				DELETE T_Analysis_Filter_Flags
				FROM T_Analysis_Filter_Flags INNER JOIN #JobsInBatch ON
					 T_Analysis_Filter_Flags.Job = #JobsInBatch.Job
				WHERE Filter_ID = @filterSetID
				--
				SELECT @myError = @@error, @myRowCount = @@RowCount
			End

			If @filterSetID < 100
			Begin
				Set @CheckFilterProcedureName = 'CheckFilterUsingCustomCriteria'

				Set @JobList = Null
				SELECT @JobList = Coalesce(@JobList + ', ', '') + Convert(varchar(19), Job)
				FROM #JobsInBatch
				ORDER BY Job
				
				Exec CheckFilterUsingCustomCriteria @CustomFilterTableName=@CustomFilterTableName, @FilterID=@filterSetID, @JobListFilter = @JobList, @infoOnly=0, @ShowSummaryStats=0, @PostLogEntries=0, @message = @message output

				UPDATE #JobsInBatch
				SET MatchCount = UpdateQ.MatchCount,
					UnMatchedCount = PeptideCount - UpdateQ.MatchCount
				FROM #JobsInBatch
					INNER JOIN ( SELECT P.Job,
										COUNT(*) AS MatchCount
								FROM T_Peptide_Filter_Flags PFF
									INNER JOIN T_Peptides P
										ON PFF.Peptide_ID = P.Peptide_ID
									INNER JOIN #JobsInBatch JB
										ON P.Job = JB.Job
								WHERE (PFF.Filter_ID = @filterSetID)
								GROUP BY P.Job 
							 ) UpdateQ
					ON #JobsInBatch.Job = UpdateQ.Job
				--
				SELECT @myError = @@error, @myRowCount = @@RowCount
				
			End
			Else
			Begin -- <e>

				Set @CheckFilterProcedureName = 'CheckFilterForAnalysesWork'

				-----------------------------------------------------------
				-- Call CheckFilterForAnalysesWork to do the work
				-----------------------------------------------------------
				--
				Exec @myError = CheckFilterForAnalysesWork @filterSetID = @filterSetID, @message = @message output
				If @myError <> 0
					Goto Done

				-----------------------------------------------------------
				-- Calculate stats and update T_Peptide_Filter_Flags
				-----------------------------------------------------------
				--

				UPDATE #JobsInBatch
				SET MatchCount = (	SELECT COUNT(*)
									FROM #PeptideFilterResults
									WHERE #PeptideFilterResults.Pass_FilterSet = 1 AND
										#PeptideFilterResults.Job = #JobsInBatch.Job
								)
				FROM #JobsInBatch, #PeptideFilterResults
				--
				SELECT @myError = @@error, @myRowCount = @@RowCount


				UPDATE #JobsInBatch
				SET UnmatchedCount = (	SELECT COUNT(*)
										FROM #PeptideFilterResults
										WHERE #PeptideFilterResults.Pass_FilterSet = 0 AND
											#PeptideFilterResults.Job = #JobsInBatch.Job
									)
				FROM #JobsInBatch, #PeptideFilterResults
				--
				SELECT @myError = @@error, @myRowCount = @@RowCount


				If @infoOnly = 0
				Begin -- <f>
					DELETE T_Peptide_Filter_Flags
					FROM T_Peptide_Filter_Flags PFF INNER JOIN #PeptideFilterResults FR ON 
						PFF.Peptide_ID = FR.Peptide_ID
					WHERE FR.Pass_FilterSet = 0 AND 
						PFF.Filter_ID = @filterSetID
					--
					SELECT @myError = @@error, @myRowCount = @@RowCount
					--
					If @myError <> 0
					Begin
						Set @Message = 'Error deleting extra peptides from T_Peptide_Filter_Flags'
						Set @myError = 51108
						Goto Done
					End

					INSERT INTO T_Peptide_Filter_Flags (Filter_ID, Peptide_ID)
					SELECT @filterSetID AS Filter_ID, Peptide_ID
					FROM #PeptideFilterResults FR
					WHERE FR.Pass_FilterSet = 1 AND Peptide_ID NOT IN
							(	SELECT Peptide_ID
								FROM T_Peptide_Filter_Flags
								WHERE Filter_ID = @filterSetID
							)
					--
					SELECT @myError = @@error, @myRowCount = @@RowCount
					--
					If @myError <> 0
					Begin
						Set @Message = 'Error adding new peptides to T_Peptide_Filter_Flags'
						Set @myError = 51109
						Goto Done
					End

					-----------------------------------------------------------
					-- Update state of analysis job filter flag
					-----------------------------------------------------------
					--
					INSERT INTO T_Analysis_Filter_Flags (Filter_ID, Job) 
					SELECT @filterSetID, Job
					FROM #JobsInBatch
					--
					SELECT @myError = @@error, @myRowCount = @@RowCount
				
					
					-- Update the Last_Affected value (but not Process_State since 
					--  CheckAllFiltersForAvailableAnalyses will update it once all
					--  possible filters have been checked)
					UPDATE T_Analysis_Description 
					SET Last_Affected = GETDATE()
					FROM T_Analysis_Description INNER JOIN #JobsInBatch ON
						T_Analysis_Description.Job = #JobsInBatch.Job
					--
					SELECT @myError = @@error, @myRowCount = @@RowCount
					
				End -- </f>

			End -- </e>

			
			-- Post entries to T_Log_Entries for all jobs processed in this batch
			--			
			Set @intContinue = 1
			Set @LastJobPolled = 0
			
			While @intContinue = 1
			Begin -- <f>
				Set @peptideMatchCount = 0
				Set @peptideUnmatchedCount = 0
				
				SELECT	TOP 1
						@LastJobPolled = Job,
						@peptideMatchCount = IsNull(MatchCount, 0), 
						@peptideUnmatchedCount = IsNull(UnmatchedCount, 0)
				FROM #JobsInBatch
				WHERE Job > @LastJobPolled
				--
				SELECT @myError = @@error, @intContinue = @@RowCount
				
				If @intContinue = 1
				Begin
					set @message = convert(varchar(11), @peptideMatchCount) + ' peptides were matched for filter set ' + @filterSetStr
					
					if @CheckFilterProcedureName <> 'CheckFilterForAnalysesWork'
						set @message = @message + ' using ' + @CheckFilterProcedureName
					
					set @message = @message + ' for job ' + convert(varchar(11), @LastJobPolled)
					Set @message = @message + '; ' + convert(varchar(11), @peptideUnmatchedCount) + ' peptides did not pass filter'

					-- bump running count of peptides that matched the filter
					--
					set @TotalHitCount = @TotalHitCount + @peptideMatchCount
					
					-- make log entry
					--
					execute PostLogEntry 'Normal', @message, 'CheckFilterForAvailableAnalysesBulk'
				End
			End -- </f>

			-- Increment jobs processed count
			Set @numJobsProcessed = @numJobsProcessed + @JobsInBatch
			
			If @InfoOnly <> 0
			Begin
				SELECT *
				FROM #JobsInBatch
				ORDER BY Job
			End
			
		 End -- </b>
	End -- </a>


	-----------------------------------------------
	-- exit the stored procedure
	-----------------------------------------------
	-- 
Done:

	-- Post a log entry if an error exists
	if @myError <> 0
		execute PostLogEntry 'Error', @message, 'CheckFilterForAvailableAnalysesBulk'

	Return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[CheckFilterForAvailableAnalysesBulk] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[CheckFilterForAvailableAnalysesBulk] TO [MTS_DB_Lite] AS [dbo]
GO
