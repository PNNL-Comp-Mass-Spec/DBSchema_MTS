/****** Object:  StoredProcedure [dbo].[CalculateCleavageStateUsingProteinSequence] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.CalculateCleavageStateUsingProteinSequence
/********************************************************
**
**	Desc: 
**		Populates the Cleavage_State and Terminus_State columns
**		in T_Peptide_to_Protein_Map.  Uses the protein sequence
**		data in T_Proteins to properly compute the cleavage state
**		for the given peptide in the given protein
**
**	Return values: 0:  success, otherwise, error code
**
**	Auth:	mem
**	Date:	11/03/2009
**
*********************************************************/
(
	@JobList varchar(max),						-- List of jobs to process; will re-compute the cleavage state and terminus state for all peptides in these jobs, even if values already exist
	@NextProcessState int = 0,					-- If non-zero, then processed jobs will get their states updated to this value upon successful calculation of cleavage and terminus states
	@numJobsProcessed int = 0 output,
	@message varchar(255) = '' output
)
AS

	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Declare @Job int
	Declare @JobCount int
	
	Declare @Continue tinyint
	
/*	
	
	declare @PeptideCountForJob int
	declare @JobAvailableCount int
	declare @AddnlJobAvailableCount int

	declare @TerminusUpdateCount int
	declare @CleavageStateUpdateCount int

	Set @numJobsProcessed = 0
	Set @TerminusUpdateCount = 0
	Set @CleavageStateUpdateCount = 0
	
	declare @S varchar(1024)
*/

	declare @lastProgressUpdate datetime
	Set @lastProgressUpdate = GetDate()

	---------------------------------------------------
	-- Validate the input parameters
	---------------------------------------------------
	--
	Set @JobList = LTrim(RTrim(IsNull(@JobList, '')))
	Set @NextProcessState = IsNull(@NextProcessState, 0)
	Set @numJobsProcessed = 0
	Set @message = ''

	If @JobList = ''
	Begin
		Set @message = 'Error: job listfilter not defined'
		Set @myError = 51100
		Goto Done
	End

	-----------------------------------------------------------
	-- Create the temporary tables to hold the jobs to process
	-----------------------------------------------------------
	CREATE TABLE #Tmp_JobsToProcess_CS (
		Job int NOT NULL,
		PeptideCount int NULL
	)

	CREATE CLUSTERED INDEX #IX_Tmp_JobsToProcess_CS ON #Tmp_JobsToProcess_CS (Job)


	-----------------------------------------------------------
	-- Get list of analyses that need to be processed
	-- If @JobFilter = 0, then process all jobs, otherwise, only process given job
	-----------------------------------------------------------
	--
	INSERT INTO #Tmp_JobsToProcess_CS ( Job )
	SELECT DISTINCT Value AS Job
	FROM dbo.udfParseDelimitedIntegerList ( @JobList, ',' )
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	Set @JobCount = @myRowCount
	--
	If @myError <> 0
	Begin
		set @message = 'Error populating #Tmp_JobsToProcess_CS with the jobs to process'
		set @myError = 51101
		goto Done
	End
	
	If @JobCount = 0
	Begin
		set @message = 'Valid jobs not found in @JobList; unable to continue'
		set @myError = 51102
		goto Done
	End	


	SELECT @Job = MIN(Job)-1
	FROM #Tmp_JobsToProcess_CS
	
	Set @Continue = 1
	While @Continue = 1
	Begin
		SELECT TOP 1 @Job = Job
		FROM #Tmp_JobsToProcess_CS
		WHERE Job > @Job
		ORDER BY Job
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myRowCount = 0
			Set @Continue = 0
		Else
		Begin
				-- ToDo: Compute cleavage state for jobs in #Tmp_JobsToProcess_CS


			If @NextProcessState <> 0
				UPDATE T_Analysis_Description
				SET Process_State = @NextProcessState
				WHERE Job = @Job

		End
	End
	
/*
	-- loop through the available jobs, and process them in groups
	--
	while @JobAvailableCount > 0 and @myError = 0 And @numJobsProcessed < @numJobsToProcess
	begin -- <a>
		-- Populate #JobsInBatch with jobs from #JobsToProcess,
		-- limiting the list to at most @MaxPeptidesPerBatch peptides
		SELECT TOP 1 @job = Job, @PeptideCountForJob = PeptideCount
		FROM #JobsToProcess
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

		if @JobAvailableCount > 0
		begin -- <b>
			-- Delete this job from #JobsToProcess
			DELETE FROM #JobsToProcess WHERE Job = @Job
		
			-- Reset #JobsInBatch
			TRUNCATE TABLE #JobsInBatch
			
			INSERT INTO #JobsInBatch (Job, PeptideCount)
			VALUES (@job, @PeptideCountForJob)

			Set @PeptidesInBatch = @PeptideCountForJob
			Set @JobsInBatch = 1
			Set @AddnlJobAvailableCount = 1
			
			-- Add additional jobs to #JobsInBatch
			while @PeptidesInBatch < @MaxPeptidesPerBatch AND @AddnlJobAvailableCount > 0 AND @numJobsProcessed + @JobsInBatch < @numJobsToProcess
			begin -- <c>
				SELECT TOP 1 @job = Job, @PeptideCountForJob = PeptideCount
				FROM #JobsToProcess
				ORDER BY Job
				--
				SELECT @myError = @@error, @AddnlJobAvailableCount = @@rowcount
			
				If @AddnlJobAvailableCount = 1
				Begin
					If @PeptidesInBatch + @PeptideCountForJob < @MaxPeptidesPerBatch
					Begin
						-- Delete this job from #JobsToProcess
						DELETE FROM #JobsToProcess WHERE Job = @Job
					
						INSERT INTO #JobsInBatch (Job, PeptideCount)
						VALUES (@job, @PeptideCountForJob)

						Set @PeptidesInBatch = @PeptidesInBatch + @PeptideCountForJob
						Set @JobsInBatch = @JobsInBatch + 1
					
					End					
					Else
						Set @AddnlJobAvailableCount = 0
				End
			end -- </c>
		
			----------------------------------------
			-- Process the jobs in #JobsInBatch
			----------------------------------------

			--------------------------------------------------
			-- Populate the Terminus_State field
			-- If @reprocess = 0, then only process entries with a Null Terminus_State value
			--------------------------------------------------

			Set @S = ''
			Set @S = @S + ' UPDATE T_Peptide_to_Protein_Map'
			Set @S = @S + ' SET Terminus_State = '
			Set @S = @S + '  CASE WHEN P.Peptide LIKE ''-.%.-'' THEN 3'
			Set @S = @S + '  WHEN P.Peptide LIKE ''-.%'' THEN 1'
			Set @S = @S + '  WHEN P.Peptide LIKE ''%.-'' THEN 2'
			Set @S = @S + '  ELSE 0'
			Set @S = @S + '  END'
			Set @S = @S + ' FROM T_Peptide_to_Protein_Map INNER JOIN T_Peptides P ON'
			Set @S = @S + '  T_Peptide_to_Protein_Map.Peptide_ID = P.Peptide_ID'
			Set @S = @S + '  INNER JOIN #JobsInBatch ON'
			Set @S = @S + '  P.Analysis_ID = #JobsInBatch.Job'
				
			If @reprocess = 0
				Set @S = @S + ' WHERE Terminus_State Is Null'
			
			Exec (@S)
			--
			SELECT @myError = @@error, @myRowCount = @@RowCount
			--
			If (@myError <> 0) 
			Begin
				Set @message = 'Error setting Terminus_State values'
				Set @myError = 101
				Goto Done
			End
			Else
				Set @TerminusUpdateCount = @TerminusUpdateCount + @myRowCount
			

			--------------------------------------------------
			-- Now compute the Cleavage_State values
			-- If @reprocess = 0, then only process entries with a Null Cleavage_State value
			-- Note that the Proline rule is honored, in that we do not allow KP or RP at the cleavage site
			-- Furthermore, N-terminus and C-terminus peptides can only be fully tryptic or non-tryptic, never partially tryptic
			--------------------------------------------------

			Set @S = ''
			Set @S = @S + ' UPDATE T_Peptide_to_Protein_Map'
			Set @S = @S + ' SET Cleavage_State = '
			Set @S = @S + '  CASE  WHEN P.Peptide LIKE ''[KR].%[KR].[^P]'' AND P.Peptide NOT LIKE ''_.P%'' THEN 2'		-- Fully tryptic
			Set @S = @S + '  WHEN P.Peptide LIKE ''[KR].%[KR][^A-Z].[^P]'' AND P.Peptide NOT LIKE ''_.P%'' THEN 2'		-- Fully tryptic, allowing modified K or R
			Set @S = @S + '  WHEN P.Peptide LIKE ''-.%[KR].[^P]'' THEN 2'				-- Fully tryptic at the N-terminus
			Set @S = @S + '  WHEN P.Peptide LIKE ''-.%[KR][^A-Z].[^P]'' THEN 2'			-- Fully tryptic at the N-terminus, allowing modified K or R
			Set @S = @S + '  WHEN P.Peptide LIKE ''[KR].[^P]%.-'' THEN 2'				-- Fully tryptic at C-terminus
			Set @S = @S + '  WHEN P.Peptide LIKE ''-.%.-'' THEN 2'						-- Label sequences spanning the entire protein as fully tryptic
			Set @S = @S + '  WHEN P.Peptide LIKE ''[KR].[^P]%.%'' THEN 1'				-- Partially tryptic
			Set @S = @S + '  WHEN P.Peptide LIKE ''%.%[KR].[^P-]'' THEN 1'				-- Partially tryptic
			Set @S = @S + '  WHEN P.Peptide LIKE ''%.%[KR][^A-Z].[^P-]'' THEN 1'		-- Partially tryptic, allowing modified K or R
			Set @S = @S + '  ELSE 0'
			Set @S = @S + ' END'
			Set @S = @S + ' FROM T_Peptide_to_Protein_Map INNER JOIN T_Peptides P ON'
			Set @S = @S + '  T_Peptide_to_Protein_Map.Peptide_ID = P.Peptide_ID'
			Set @S = @S + ' INNER JOIN #JobsInBatch ON'
			Set @S = @S + '  P.Analysis_ID = #JobsInBatch.Job'

			If @reprocess = 0
				Set @S = @S + ' WHERE Cleavage_State Is Null'

			Exec (@S)
			--
			SELECT @myError = @@error, @myRowCount = @@RowCount
			--
			If (@myError <> 0) 
			Begin
				Set @message = 'Error setting Cleavage_State values'
				Set @myError = 102
				Goto Done
			End
			Else
				Set @CleavageStateUpdateCount = @CleavageStateUpdateCount + @myRowCount

			
			-- Increment jobs processed count
			Set @numJobsProcessed = @numJobsProcessed + @JobsInBatch

			if @logLevel >= 1
			Begin
				if DateDiff(second, @lastProgressUpdate, GetDate()) >= 300
				Begin
					set @message = '...Processing: ' + convert(varchar(11), @numJobsProcessed) + ' jobs completed'
					execute PostLogEntry 'Progress', @message, 'CalculateCleavageStateUsingProteinSequence'
					set @message = ''
					set @lastProgressUpdate = GetDate()
				End
			End			
			
			
		end -- </b>
	end -- </a>


	If @TerminusUpdateCount > 0
		Set @message = 'Updated Terminus_State for ' + Convert(varchar(9), @TerminusUpdateCount) + ' peptides'

	If @CleavageStateUpdateCount > 0
	Begin
		If Len(@message) > 0
			Set @Message = @Message + '; '
			
		Set @Message = @Message + 'Updated Cleavage_State for ' + Convert(varchar(9), @CleavageStateUpdateCount) + ' peptides'
	End

	--------------------------------------------------
	-- Post a message to the log if any changes were made and
	-- @LogLevel is > 0
	--------------------------------------------------

	If Len(@Message) > 0
	Begin
		If @JobFilter <> 0
			Set @Message = @Message + ' for job ' + @JobStr
		Else
			Set @Message = @Message + ' for ' + convert(varchar(9), @numJobsProcessed) + ' jobs'
			
		If @logLevel > 0
			execute PostLogEntry 'Normal', @message, 'CalculateCleavageStateUsingProteinSequence'
					
	End
*/

	-----------------------------------------------
	-- exit the stored procedure
	-----------------------------------------------
	-- 
Done:

	-- Post a log entry if an error exists
	If @myError <> 0 
	Begin
		execute PostLogEntry 'Error', @message, 'CalculateCleavageStateUsingProteinSequence'
	End

	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[CalculateCleavageStateUsingProteinSequence] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[CalculateCleavageStateUsingProteinSequence] TO [MTS_DB_Lite] AS [dbo]
GO
