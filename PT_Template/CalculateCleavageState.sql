/****** Object:  StoredProcedure [dbo].[CalculateCleavageState] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure CalculateCleavageState
/********************************************************
**
**	Desc: 
**		Populates the Cleavage_State and Terminus_State columns
**		in T_Peptide_to_Protein_Map
**
**		This procedure is normally intended to process one job at a time (given by @JobFilter)
**		However, it can also process all jobs in the database (if @JobFilter = 0)
**
**	Return values: 0:  success, otherwise, error code
**
**	Auth:	mem
**	Date:	03/27/2005
**			01/06/2012 mem - Updated to use T_Peptides.Job
**
*********************************************************/
(
	@JobFilter int = 0,							-- Optional, single job to process; if 0, then process all peptides with null Cleavage_State or Terminus_State values
	@reprocess tinyint = 0,						-- If non-zero, then will recompute cleavage state for all peptides; if @JobFilter is non-zero, then only reprocess peptides for given job
	@logLevel int = 1,							-- If greater than 0, then messages (both success and error) will be posted to the log
	@message varchar(255) = '' output,
	@numJobsToProcess int = 1000000,
	@numJobsProcessed int = 0 output
)
AS

	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
			
	Set @message = ''
	Set @JobFilter = IsNull(@JobFilter, 0)
	
	Declare @JobStr varchar(12)
	Set @JobStr = Convert(varchar(12), @JobFilter)

	declare @Job int
	declare @PeptideCountForJob int
	declare @JobAvailableCount int
	declare @AddnlJobAvailableCount int

	declare @TerminusUpdateCount int
	declare @CleavageStateUpdateCount int

	declare @PeptidesInBatch int
	declare @JobsInBatch int

	declare @MaxPeptidesPerBatch int
	Set @MaxPeptidesPerBatch = 1000000

	Set @numJobsProcessed = 0
	Set @TerminusUpdateCount = 0
	Set @CleavageStateUpdateCount = 0
	
	declare @S varchar(1024)

	declare @lastProgressUpdate datetime
	Set @lastProgressUpdate = GetDate()


	-----------------------------------------------------------
	-- Create the temporary tables to hold the jobs to process
	-----------------------------------------------------------
	CREATE TABLE #JobsToProcess (
		Job int,
		PeptideCount int
	)

	CREATE TABLE #JobsInBatch (
			Job int,
			PeptideCount int
	)


	-----------------------------------------------------------
	-- Get list of analyses that need to be processed
	-- If @JobFilter = 0, then process all jobs, otherwise, only process given job
	-----------------------------------------------------------
	--
	If @JobFilter <> 0
		INSERT INTO #JobsToProcess
		SELECT Job, IsNull(COUNT(Peptide_ID), 0) AS PeptideCount
		FROM T_Peptides
		WHERE T_Peptides.Job = @JobFilter
		GROUP BY Job
	Else
		INSERT INTO #JobsToProcess
		SELECT Job, IsNull(COUNT(Peptide_ID), 0) AS PeptideCount
		FROM T_Peptides
		GROUP BY Job
		ORDER BY Job
	--
	SELECT @myError = @@error, @JobAvailableCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Error populating #JobsToProcess with the jobs to process'
		set @myError = 51105
		goto Done
	end

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
			Set @S = @S + '  P.Job = #JobsInBatch.Job'
				
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
			Set @S = @S + '  END'
			Set @S = @S + ' FROM T_Peptide_to_Protein_Map INNER JOIN T_Peptides P ON'
			Set @S = @S + '  T_Peptide_to_Protein_Map.Peptide_ID = P.Peptide_ID'
			Set @S = @S + ' INNER JOIN #JobsInBatch ON'
			Set @S = @S + '  P.Job = #JobsInBatch.Job'

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
					execute PostLogEntry 'Progress', @message, 'CalculateCleavageState'
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
			execute PostLogEntry 'Normal', @message, 'CalculateCleavageState'
					
	End


	-----------------------------------------------
	-- exit the stored procedure
	-----------------------------------------------
	-- 
Done:

	-- Post a log entry if an error exists
	If @myError <> 0 
	Begin
		If @JobFilter <> 0
		Set @Message = @Message + ' for job ' + @JobStr

		If @logLevel > 0
			execute PostLogEntry 'Error', @message, 'CalculateCleavageState'
	End

	Return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[CalculateCleavageState] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[CalculateCleavageState] TO [MTS_DB_Lite] AS [dbo]
GO
