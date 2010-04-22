/****** Object:  StoredProcedure [dbo].[ProcessPeptideProphetTasks] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.ProcessPeptideProphetTasks
/****************************************************
** 
**	Desc: Loads Peptide Prophet result files for available tasks
**
**	Return values: 0: success, otherwise, error code
** 
**	Parameters:
**
**	Auth:	mem
**	Date:	07/06/2006
**			07/28/2006 mem - Updated to allow Task_ID values of 0
**    
*****************************************************/
(
	@NextProcessState int = 60,
	@message varchar(255) = '' output,
	@numJobsToProcess int = 50000,
	@AutoDetermineNextProcessState tinyint = 1,		-- If non-zero, then uses T_Event_Log to determine the appropriate value for @NextProcessState (if last Process_State before state 90 was 70, then sets to 70, otherwise, sets to @NextProcessState)
	@ProcessStateLoadError int = 98
)
As
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	declare @cmd varchar(255)

	declare @result int
	declare @logLevel int
	declare @DeletePeptideProphetResultFiles int
	declare @JobsInTask int
	declare @UpdateEnabled tinyint
	
	set @result = 0
	set @logLevel = 1		-- Default to normal logging
	set @DeletePeptideProphetResultFiles = 0
	
	--------------------------------------------------------------
	-- Lookup the LogLevel state
	-- 0=Off, 1=Normal, 2=Verbose, 3=Debug
	--------------------------------------------------------------
	--
	set @result = @logLevel
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'LogLevel')
	Set @logLevel = @result

	set @message = 'Begin Loading of Peptide Prophet results for ' + DB_NAME()
	If @logLevel >= 2
		execute PostLogEntry 'Normal', @message, 'ProcessPeptideProphetResults'

	--------------------------------------------------------------
	-- Lookup whether or not we're deleting the Peptide Prophet results files
	--------------------------------------------------------------
	--
	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'DeletePeptideProphetFiles')
	if @result <> 0
		Set @DeletePeptideProphetResultFiles = 1

	--------------------------------------------------------------
	-- Process any Peptide Prophet Tasks in state 3 = 'Results Ready'
	--------------------------------------------------------------

	declare @Continue tinyint
	declare @TaskID int,
			@numTasksProcessed int,
			@numJobsProcessed int
	
	set @TaskID = -1
	set @numTasksProcessed = 0
	set @numJobsProcessed = 0
	
	set @Continue = 1
	while @Continue = 1 And @numJobsProcessed < @numJobsToProcess
	begin
		---------------------------------------------------
		-- find an available Peptide Prophet Task
		---------------------------------------------------
		
		SELECT TOP 1 @TaskID = Task_ID
		FROM T_Peptide_Prophet_Task WITH (HoldLock)
		WHERE Processing_State = 3 And Task_ID > @TaskID
		ORDER BY Task_ID ASC
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0
		begin
			set @message = 'Error trying to find viable record'
			goto done
		end
		
		---------------------------------------------------
		-- Exit loop if no task found
		---------------------------------------------------

		if @myRowCount = 0
			Set @Continue = 0
		else
		begin
			---------------------------------------------------
			-- Process the Peptide Prophet Task
			---------------------------------------------------

			Set @JobsInTask = 0
			SELECT @JobsInTask = COUNT(Job)
			FROM T_Peptide_Prophet_Task_Job_Map
			WHERE Task_ID = @TaskID

			exec @result = ProcessPeptideProphetResultsOneTask
													@TaskID, 
													@NextProcessState,
													@AutoDetermineNextProcessState,
													@ProcessStateLoadError,
													@DeletePeptideProphetResultFiles, 
													@logLevel,
													@message = @message OUTPUT
			
			set @numJobsProcessed = @numJobsProcessed + IsNull(@JobsInTask,0)
			set @numTasksProcessed = @numTasksProcessed + 1
			
			If @result <> 0
				Set @Continue = 0
		end

		-- Validate that updating is enabled, abort if not enabled
		exec VerifyUpdateEnabled @CallingFunctionDescription = 'ProcessPeptideProphetResults', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
		If @UpdateEnabled = 0
			Goto Done

	end


	--------------------------------------------------------------
	-- Normal Exit
	--------------------------------------------------------------

	set @message = 'End Loading of Peptide Prophet results; Processed ' + Convert(varchar(12), @numJobsProcessed) + ' job'
	if @numJobsProcessed <> 1
		set @message = @message + 's'
	
	set @message = @message + ' in ' + convert(varchar(12), @numTasksProcessed) + ' task'
	if @numTasksProcessed <> 1
		set @message = @message + 's'
		
	if @myError <> 0
		Set @message = @message + ' (Error Code = ' + convert(varchar(12), @myError) + ')'
	
Done:
	If (@logLevel >=1 AND @myError <> 0)
		execute PostLogEntry 'Error', @message, 'ProcessPeptideProphetResults'
	Else
	If @logLevel >= 2
		execute PostLogEntry 'Normal', @message, 'ProcessPeptideProphetResults'

	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[ProcessPeptideProphetTasks] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[ProcessPeptideProphetTasks] TO [MTS_DB_Lite] AS [dbo]
GO
