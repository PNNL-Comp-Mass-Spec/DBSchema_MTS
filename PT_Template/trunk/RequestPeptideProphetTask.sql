SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[RequestPeptideProphetTask]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[RequestPeptideProphetTask]
GO


CREATE PROCEDURE dbo.RequestPeptideProphetTask
/****************************************************
**
**	Desc: 
**		Looks for jobs in T_Analysis_Description with a
**      Process_State = @ProcessStateMatch (default 90)
**
**      If found, create peptide Prophet task and populate with
**		batch of available jobs; set @TaskAvailable to 1
**		and return the relevant information in the output arguments
**
**      If no jobs are available or an error occurs, then @message 
**		will contain explanatory text.
**
**	Auth:	mem
**	Date:	07/05/2006
**
*****************************************************/
(
	@processorName varchar(128),
	@ClientPerspective tinyint = 1,					-- 0 means running SP from local server; 1 means running SP from client
	@ProcessStateMatch int = 90,
	@NextProcessState int = 95,
	@ProcessingTimeoutState int = 94,
	@BatchSize int = 0,								-- If non-zero, then this value overrides the one present in T_Process_Config, entry NET_Update_Batch_Size
	@MaxPeptideCount int = 0,						-- If non-zero, then this value overrides the one present in T_Process_Config, entry NET_Update_Max_Peptide_Count

	@TaskID int output,								-- Task_ID of entry in T_Peptide_Prophet_Task
	@taskAvailable tinyint output,
	@TransferFolderPath varchar(256) = '' output,	-- Path to folder containing source data; if blank, then will look up path in MT_Main
	@JobListFileName varchar(256) = '' output,
	@ResultsFileName varchar(256) = '' output,			
	@message varchar(512) output
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0
	
	set @message = ''
		
	---------------------------------------------------
	-- clear the output arguments
	---------------------------------------------------
	set @TaskID = 0
	set @TaskAvailable = 0
	set @JobListFileName = ''
	set @ResultsFileName = ''
	set @message = ''

	declare @MatchCount int
	declare @S varchar(1024)

	-----------------------------------------------
	-- Populate a temporary table with the list of known Result Types appropriate for peptide prophet calculation
	-----------------------------------------------
	CREATE TABLE #T_ResultTypeList (
		ResultType varchar(64)
	)
	
	INSERT INTO #T_ResultTypeList (ResultType) Values ('Peptide_Hit')
	
		
	---------------------------------------------------
	-- Look for jobs that are timed out (State 94) and for which Last_Affected
	-- is more than 60 minutes ago; reset to state @ProcessStateMatch
	---------------------------------------------------
	--
	UPDATE T_Analysis_Description
	SET Process_State = @ProcessStateMatch
	WHERE Process_State = @ProcessingTimeoutState AND
		  DateDiff(Minute, Last_Affected, GetDate()) > 60
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	If @myRowCount > 0
	Begin
		Set @message = 'Jobs that were timed out (state ' + Convert(varchar(11), @ProcessingTimeoutState) + ') were reset to state ' + Convert(varchar(11), @ProcessStateMatch) + '; ' + Convert(varchar(11), @myRowCount) + ' updated'
		Exec PostLogEntry 'Error', @message, 'RequestPeptideProphetTask'
	End


	---------------------------------------------------
	-- Check for and reset stale Peptide Prophet Calculation tasks
	---------------------------------------------------
	--
	Declare @CurrentTime datetime
	Declare @maxHoursUnchangedState int
	Set @maxHoursUnchangedState = 12

	Exec ResetStalePeptideProphetTasks @maxHoursUnchangedState, @ProcessStateMatch

	
	---------------------------------------------------
	-- Start transaction
	---------------------------------------------------
	--
	declare @transName varchar(32)
	set @transName = 'RequestPeptideProphetTask'
	begin transaction @transName

	---------------------------------------------------
	-- See if one or more jobs are in state @ProcessStateMatch
	---------------------------------------------------

	SELECT @MatchCount = Count(TAD.Job)
	FROM T_Analysis_Description TAD INNER JOIN
		 #T_ResultTypeList RTL ON TAD.ResultType = RTL.ResultType
	WHERE TAD.Process_State = @ProcessStateMatch
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		rollback transaction @transName
		set @message = 'Error trying to count number of available jobs'
		goto done
	end

	---------------------------------------------------
	-- bail if no jobs were found
	---------------------------------------------------

	if @MatchCount = 0
	begin
		rollback transaction @transName
		set @message = 'Could not find viable record'
		goto done
	end

	---------------------------------------------------
	-- Create a new Peptide Prophet Calculation task
	---------------------------------------------------
	
	INSERT INTO T_Peptide_Prophet_Task (Processing_State, Task_Created, Task_AssignedProcessorName)
	VALUES (1, GetDate(), @processorName)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount, @TaskID = Scope_Identity()
	--
	if @myError <> 0
	begin
		rollback transaction @transName
		set @message = 'Error adding new task to T_Peptide_Prophet_Task'
		goto done
	end
	
	---------------------------------------------------
	-- Lookup the value for @BatchSize
	---------------------------------------------------
	
	If IsNull(@BatchSize, 0) <= 0
	Begin
		Set @BatchSize = 0
		SELECT TOP 1 @BatchSize = Value
		FROM T_Process_Config
		WHERE [Name] = 'NET_Update_Batch_Size'
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		-- Default to a batch size of 100 if an error occurs
		If @MyRowCount = 0 Or @myError <> 0
			Set @Batchsize = 100
		Else
			If IsNull(@BatchSize, 0) <= 0
				Set @BatchSize = 100
	End
	
	---------------------------------------------------
	-- Lookup the value for @MaxPeptideCount
	---------------------------------------------------
	
	If IsNull(@MaxPeptideCount, 0) <= 0
	Begin
		Set @MaxPeptideCount = 0
		SELECT TOP 1 @MaxPeptideCount = Value
		FROM T_Process_Config
		WHERE [Name] = 'NET_Update_Max_Peptide_Count'
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		-- Default to a max peptide count of 200000 if an error occurs
		If @MyRowCount = 0 Or @myError <> 0
			Set @MaxPeptideCount = 200000
		Else
			If IsNull(@MaxPeptideCount, 0) <= 0
				Set @MaxPeptideCount = 200000
	End
	
	If @BatchSize < 1
		Set @BatchSize = 1
	If @MaxPeptideCount < 1
		Set @MaxPeptideCount = 1
	
	---------------------------------------------------
	-- Find up to @BatchSize jobs in state @ProcessStateMatch
	-- Limit the number of entries to @MaxPeptideCount peptides (though, require a minimum of one job)
	-- Only grab the Job numbers at this time
	---------------------------------------------------

	Set @S = ''
	Set @S = @S + ' INSERT INTO T_Peptide_Prophet_Task_Job_Map (Task_ID, Job)'
	Set @S = @S + ' SELECT ' + Convert(varchar(9), @TaskID) + ' AS Task_ID, A.Job'
	Set @S = @S + ' FROM ('
	Set @S = @S +   ' SELECT TOP ' + Convert(varchar(9), @BatchSize) + ' TAD.Job, IsNull(TAD.RowCount_Loaded,0) AS PeptideCount'
	Set @S = @S +   ' FROM T_Analysis_Description TAD WITH (HoldLock) INNER JOIN'
 	Set @S = @S +       ' #T_ResultTypeList RTL ON TAD.ResultType = RTL.ResultType'
	Set @S = @S +   ' WHERE TAD.Process_State = ' + Convert(varchar(9), @ProcessStateMatch)
	Set @S = @S +   ' ORDER BY TAD.Job'
	Set @S = @S +   ' ) A INNER JOIN ('
	Set @S = @S +   ' SELECT TOP ' + Convert(varchar(9), @BatchSize) + ' TAD.Job, IsNull(TAD.RowCount_Loaded,0) AS PeptideCount'
	Set @S = @S +   ' FROM T_Analysis_Description TAD INNER JOIN'
 	Set @S = @S +       ' #T_ResultTypeList RTL ON TAD.ResultType = RTL.ResultType'
	Set @S = @S +   ' WHERE TAD.Process_State =  ' + Convert(varchar(9), @ProcessStateMatch)
	Set @S = @S +   ' ORDER BY TAD.Job'
	Set @S = @S +   ' ) B ON B.Job <= A.Job'
	Set @S = @S + ' GROUP BY A.Job'
	Set @S = @S + ' HAVING SUM(B.PeptideCount) < ' + Convert(varchar(12), @MaxPeptideCount)
	Set @S = @S + ' ORDER BY A.Job ASC'
	--	
	print @S
	Exec (@S)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		rollback transaction @transName
		set @message = 'Error trying to find viable record(s)'
		goto done
	end

	If @myRowCount = 0
	Begin
		-- The @MaxPeptideCount filter filtered out all of the jobs
		-- Repeat the insert and only insert one job into the task

		Set @S = ''
		Set @S = @S + ' INSERT INTO T_Peptide_Prophet_Task_Job_Map (Task_ID, Job)'
		Set @S = @S + ' SELECT TOP 1 ' +  Convert(varchar(9), @TaskID) + ' AS Task_ID, Job'
		Set @S = @S + ' FROM T_Analysis_Description WITH (HoldLock)'
		Set @S = @S + ' WHERE Process_State = ' + Convert(varchar(9), @ProcessStateMatch)
		Set @S = @S + ' ORDER BY Job ASC'
		
		Exec (@S)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0
		begin
			rollback transaction @transName
			set @message = 'Error trying to find viable record(s)'
			goto done
		end

	End
	
	---------------------------------------------------
	-- set state and last_affected for the selected jobs
	---------------------------------------------------
	--
	UPDATE T_Analysis_Description
	SET Process_State = @NextProcessState, Last_Affected = GETDATE()
	FROM T_Analysis_Description TAD INNER JOIN 
		 T_Peptide_Prophet_Task_Job_Map TJM ON TAD.Job = TJM.Job
	WHERE TJM.Task_ID = @TaskID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		rollback transaction @transName
		set @message = 'Update operation failed'
		goto done
	end

	---------------------------------------------------
	-- commit transaction
	---------------------------------------------------
	commit transaction @transName


	---------------------------------------------------
	-- Write the output files
	---------------------------------------------------

	Exec @myError = ExportPeptideProphetJobList 
									@TaskID,
									@ClientPerspective,
									@TransferFolderPath, 
									@JobListFileName = @JobListFileName OUTPUT, 
									@ResultsFileName = @ResultsFileName OUTPUT, 
									@message = @message OUTPUT
	--
	if @myError = 0
	begin
		-- Advance Task_ID to state 2 = 'Update In Progress'
		Exec SetPeptideProphetTaskState @TaskID, 2, Null, @message output
	end
	else
	begin
		If Len(IsNull(@message, '')) = 0
			Set @message = 'Error calling ExportPeptideProphetJobList for TaskID ' + Convert(varchar(9), @TaskID)
		
		-- Error calling ExportPeptideProphetJobList
		-- Post an error log entry
		Exec PostLogEntry 'Error', @message, 'RequestPeptideProphetTask'

		-- Now update Task_ID to State 6 and rollback state of jobs to @ProcessingTimeoutState
		Exec SetPeptideProphetTaskState @TaskID, 6, @ProcessingTimeoutState, @message output
		goto done
	end
	
	---------------------------------------------------
	-- If we get to this point, then all went fine
	-- Update TaskAvailable
	---------------------------------------------------
	Set @TaskAvailable = 1

	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

