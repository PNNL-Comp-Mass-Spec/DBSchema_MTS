SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[ProcessPeptideProphetResultsOneTask]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[ProcessPeptideProphetResultsOneTask]
GO


CREATE Procedure dbo.ProcessPeptideProphetResultsOneTask
/****************************************************
**
**	Desc: Loads the Peptide Prophet result file for the given task
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	07/06/2006
**    
*****************************************************/
(
	@TaskID int,
	@NextProcessStateForJobs int = 60,
	@AutoDetermineNextProcessState tinyint = 1,		-- If non-zero, then uses T_Event_Log to determine the appropriate value for @NextProcessState (if last Process_State before state 90 was 70, then sets to 70, otherwise, sets to @NextProcessState)
	@ProcessStateLoadError int = 98,
	@DeleteResultFiles int,
	@logLevel int,
	@message varchar(255) = '' output
)
As

	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @numJobsProcessed int		-- The number of jobs processed
	declare @numJobsIncomplete int		-- The number of jobs with 1 or more null Peptide Prophet values after loading
	declare @numRowsUpdated int			-- The number of rows updated in T_Score_Discriminant
	set @numJobsProcessed = 0
	set @numJobsIncomplete = 0
	set @numRowsUpdated = 0

	declare @result int
	declare @TaskIDStr varchar(12)
	set @TaskIDStr = Convert(varchar(12), @TaskID)
	
	declare @TransferFolderPath varchar(256)
	declare @JobListFileName varchar(256)
	declare @ResultsFileName varchar(256)

	---------------------------------------------------
	-- Possibly log that we are loading Peptide Prophet results
	---------------------------------------------------
	--
	set @message = 'Load Peptide Prophet results for Task_ID ' + @TaskIDStr
	If @logLevel >= 2
		execute PostLogEntry 'Normal', @message, 'ProcessPeptideProphetResultsOneTask'

	---------------------------------------------------
	-- Update state for task to 4 = 'Results Loading'
	---------------------------------------------------
	--
	Exec @myError = SetPeptideProphetTaskState @TaskID, 4, Null, @message output

	---------------------------------------------------
	-- Lookup the results folder path and file names from T_Peptide_Prophet_Task
	---------------------------------------------------
	
	SELECT 	@TransferFolderPath = Transfer_Folder_Path,
			@JobListFileName = JobList_File_Name,
			@ResultsFileName = Results_File_Name
	FROM T_Peptide_Prophet_Task
	WHERE Task_ID = @TaskID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		goto Done
	end

	if @myRowCount = 0
	Begin
		set @message = 'Peptide prophet Task_ID ' + @TaskIDStr + ' not found in T_Peptide_Prophet_Task'
		set @myError = 40000
		Goto done
	End
	
	---------------------------------------------------
	-- Load contents of Peptide Prophet result file into T_Score_Discriminant
	-- Note that jobs are processed one-by-one, and the process_state for each job
	--  is set by LoadPeptideProphetResults
	---------------------------------------------------
	--
	If @logLevel >= 2
		execute PostLogEntry 'Normal', 'Begin LoadPeptideProphetResults', 'ProcessPeptideProphetResultsOneTask'
	EXEC @result = LoadPeptideProphetResults
										@TaskID,
										@ResultsFileName,
										@TransferFolderPath,
										@NextProcessStateForJobs,
										@AutoDetermineNextProcessState,
										@ProcessStateLoadError,
										@message  output,
										@numJobsProcessed output,
										@numJobsIncomplete output,
										@numRowsUpdated output


	if @result = 0
	begin
		-- Load successful (though @numJobsIncomplete might be non-zero)
		--
		set @message = 'Complete LoadPeptideProphetResults for Task_ID ' + @TaskIDStr + '; ' + @message
		If (@LogLevel >= 1 And @numJobsProcessed > 0) Or @logLevel >= 2
			execute PostLogEntry 'Normal', @message, 'ProcessPeptideProphetResultsOneTask'

		If @numJobsIncomplete = 0
		Begin
			-- Set state of Peptide Prophet task to state 5 = 'Update Complete'
			--
			Exec @myError = SetPeptideProphetTaskState @TaskID, 5, Null, @message output
			
			-- Delete the Peptide Prophet Result files if set to do so
			--
			If @myError = 0 And @DeleteResultFiles = 1
			Begin
				Exec DeleteFiles @TransferFolderPath, @JobListFileName, @message = @message output
				Exec DeleteFiles @TransferFolderPath, @ResultsFileName, @message = @message output
			End
		End
		Else
		Begin
			-- Set state of Peptide Prophet task to state 7 = 'Results Loading Failed'
			--
			Exec @myError = SetPeptideProphetTaskState @TaskID, 7, Null, @message output
		End
	end
	else
	begin
		-- Error in LoadPeptideProphetResults
		
		set @message = 'Complete LoadPeptideProphetResults: ' + @message + ' (error ' + convert(varchar(32), @result) + ')'
		If @logLevel >= 1
			execute PostLogEntry 'Error', @message, 'ProcessPeptideProphetResultsOneTask'

		Set @myError = @result

		-- Set state of Peptide Prophet task to state 7 = 'Results Loading Failed'
		--
		Exec SetPeptideProphetTaskState @TaskID, 7, Null, @message output

		goto Done
	end

Done:
	return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

