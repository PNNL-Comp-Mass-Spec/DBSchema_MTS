/****** Object:  StoredProcedure [dbo].[UpdateSequenceModsForAvailableAnalyses] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.UpdateSequenceModsForAvailableAnalyses
/****************************************************
**
**	Desc: 
**		Updates peptide sequence modifications for
**		all the peptides for the all the analyses with
**		Process_State = @ProcessStateMatch
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	grk
**	Date:	11/2/2001
**			03/25/2004 mem - Changed "no analyses were available" to be status Normal instead of Error
**		    04/16/2004 mem - Switched from using a cursor to using a while loop
**			08/07/2004 mem - Changed to use of Process_State field for choosing next job
**			09/04/2004 mem - Added additional call to PostLogEntry
**			09/09/2004 mem - Tweaked the while loop logic
**			02/10/2005 mem - Now looking for jobs with one or more peptides mapped to Seq_ID 0
**			02/11/2005 mem - Switched to using UpdateSequenceModsForOneAnalysisBulk
**			11/10/2005 mem - Updated default value for @ProcessStateMatch to 25
**			01/16/2006 mem - Now calling ProcessCandidateSequencesForOneAnalysis if a job has entries in T_Seq_Candidates
**			03/11/2006 mem - Now calling VerifyUpdateEnabled
**			06/08/2006 mem - Now checking for 'Error calling GetOrganismDBFileInfo%' in the error string returned by the processing SPs
**			06/09/2006 mem - Added 6 hour delay for resetting jobs that have 1 or more peptides with Seq_ID values = 0
**			11/30/2006 mem - Updated to record a Warning in PostLogEntry for Deadlock errors
**    
*****************************************************/
(
	@ProcessStateMatch int = 25,
	@NextProcessState int = 30,
	@numJobsToProcess int = 50000,
	@numJobsProcessed int=0 OUTPUT
)
AS
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	declare @jobAvailable int
	set @jobAvailable = 0

	declare @firstJobFound int
	set @firstJobFound = 0
	
	declare @UpdateEnabled tinyint
	declare @message varchar(255)
	set @message = ''
	
	declare @Job int
	declare @JobMatch int
	
	declare @count int
	set @count = 0

	----------------------------------------------
	-- Look for jobs that have 1 or more peptides with Seq_ID values = 0
	----------------------------------------------
	--
	CREATE TABLE #TmpJobsToReset (
		Job int NOT NULL,
		Last_Reset_Time datetime NULL
	)
	
	INSERT INTO #TmpJobsToReset (Job)
	SELECT Job
	FROM T_Analysis_Description
	WHERE Process_State >= @NextProcessState AND
		  Job IN (	SELECT Analysis_ID
					FROM T_Peptides
					WHERE (Seq_ID = 0)
					GROUP BY Analysis_ID
					HAVING COUNT(Peptide_ID) > 0
				 )
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0 
	begin
		set @message = 'Error looking for jobs with one or more Seq_ID values = 0'
		goto done
	end

	If @myRowCount > 0
	Begin
		-- Jobs found; possibly reset their state state to @ProcessStateMatch and post an entry to the log
		-- Examine T_Event_Log to determine the last time the job's state was changed from @NextProcessState to @ProcessStateMatch
		UPDATE #TmpJobsToReset
		SET Last_Reset_Time = EL.Entered
		FROM #TmpJobsToReset JTR INNER JOIN 
			 T_Event_Log EL ON JTR.Job = EL.Target_ID AND EL.Target_Type = 1
		WHERE Target_State = @ProcessStateMatch AND
			  Prev_Target_State = @NextProcessState
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		-- For jobs whose state was last changed at least 6 hours ago (or never changed at all), 
		-- update their state to @ProcessStateMatch
		UPDATE T_Analysis_Description
		SET Process_State = @ProcessStateMatch
		FROM T_Analysis_Description TAD INNER JOIN
			 #TmpJobsToReset JTR ON TAD.Job = JTR.Job
		WHERE DateDiff(hour, IsNull(JTR.Last_Reset_Time, GetDate()-10), GetDate()) >= 6
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		if @myError <> 0 
		begin
			set @message = 'Error resetting the Process_State value for jobs with one or more Seq_ID values = 0'
			goto done
		end

		if @myRowCount > 0
		begin
			set @message = 'Found ' + convert(varchar(9), @myRowCount) + ' job(s) containing one or more peptides mapped to a Seq_ID value of 0; job state has been reset to ' + convert(varchar(9), @ProcessStateMatch)
			execute PostLogEntry 'Error', @message, 'UpdateSequenceModsForAvailableAnalyses'
			set @message = ''
		end
	End

	----------------------------------------------
	-- Loop through T_Analysis_Description, processing jobs with Process_State = @ProcessStatematch
	----------------------------------------------
	Set @Job = 0
	set @jobAvailable = 1
	set @numJobsProcessed = 0
	
	While @jobAvailable > 0 and @myError = 0 and @numJobsProcessed < @numJobsToProcess
	Begin -- <a>
		-- Look up the next available job
		SELECT	TOP 1 @Job = Job
		FROM	T_Analysis_Description
		WHERE	Process_State = @ProcessStateMatch AND Job > @Job
		ORDER BY Job
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		if @myError <> 0 
		begin
			set @message = 'Error while reading next job from T_Analysis_Description'
			goto done
		end

		If @myRowCount <> 1
			Set @jobAvailable = 0
		Else
		Begin -- <b>
			-- Job is available to process
			
			if @firstJobFound = 0
			begin
				-- Write entry to T_Log_Entries for the first job processed
				set @message = 'Starting sequence mods processing for job ' + convert(varchar(11), @job)
				execute PostLogEntry 'Normal', @message, 'UpdateSequenceModsForAvailableAnalyses'
				set @message = ''
				set @firstJobFound = 1
			end

			-- See if this job has any entries in T_Seq_Candidates
			If @Job <> 0
				Set @JobMatch = 0
			Else
				Set @JobMatch = -1
				
			SELECT TOP 1 @JobMatch = Job
			FROM T_Seq_Candidates
			WHERE Job = @Job
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error

			If @JobMatch = @Job
				-- Process sequences using the T_Seq_Candidate tables
				exec @myError = ProcessCandidateSequencesForOneAnalysis
										@NextProcessState,
										@job,
										@count output,
										@message output
			Else
				-- Process the sequences one row at a time
				exec @myError = UpdateSequenceModsForOneAnalysisBulk
										@NextProcessState,
										@job,
										@count output,
										@message output

			If @myError = 0
			Begin
				execute PostLogEntry 'Normal', @message, 'UpdateSequenceModsForAvailableAnalyses'
				set @numJobsProcessed = @numJobsProcessed + 1
			End
			Else
			Begin
				-- Do not call PostLogEntry if the error involved calling GetOrganismDBFileInfo or if it starts with 'Error caught'
				If Not @message Like 'Error calling GetOrganismDBFileInfo%' And Not @message Like 'Error caught%'
					execute PostLogEntry 'Error', @message, 'UpdateSequenceModsForAvailableAnalyses'
			End
		End -- </b>

		-- Validate that updating is enabled, abort if not enabled
		exec VerifyUpdateEnabled @CallingFunctionDescription = 'UpdateSequenceModsForAvailableAnalyses', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
		If @UpdateEnabled = 0
			Goto Done

	End -- </a>

	If @numJobsProcessed = 0
		set @message = 'no analyses were available'

Done:
	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[UpdateSequenceModsForAvailableAnalyses] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[UpdateSequenceModsForAvailableAnalyses] TO [MTS_DB_Lite]
GO
