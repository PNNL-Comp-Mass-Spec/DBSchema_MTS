/****** Object:  StoredProcedure [dbo].[RequestGANETUpdateTask] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.RequestGANETUpdateTask
/****************************************************
**
**	Desc: 
**		Looks for jobs in T_Analysis_Description with a
**      Process_State = @ProcessStateMatch (default 40)
**
**      If found, create NET Update task and populate with
**		batch of available jobs; set @TaskAvailable to 1
**		and return the relevant information in the output arguments
**
**      If no jobs are available or an error occurs, then @message 
**		will contain explanatory text.
**
**	Auth:	grk
**	Date:	08/26/2003
**			04/08/2004 mem - Removed references to T_GANET_Update_Parameters
**			04/09/2004 mem - Removed @maxIterations and @maxHours parameters
**			07/05/2004 mem - Modified procedure for use in Peptide DB
**			09/09/2004 mem - Removed call to SetProcessState
**			09/23/2004 mem - Now checking for tasks in states 44, 45, 47, or 48 with Last_Affected over 12 hours old; bumping back to Process_State 40 if found
**			01/22/2005 mem - Now setting Process_State = 43 if a job is in state 40 and does not have associated scan time data
**			01/24/2005 mem - Now checking for jobs in state 43 that now have a SIC job available; if found, the state is reset back to 40 and a message is posted to the log
**			04/08/2005 mem - Changed GANET export call to use ExportGANETData
**			05/30/2005 mem - Updated to process batches of jobs using T_NET_Update_Task rather than one job at a time
**						   - Added parameters @ResultsFolderPath and @BatchSize
**			12/11/2005 mem - Updated to support XTandem results
**			07/03/2006 mem - Updated to use T_Analysis_Description.RowCount_Loaded to quickly determine the number of peptides loaded for each job
**			10/10/2008 mem - Added support for Inspect results (type IN_Peptide_Hit)
**
*****************************************************/
(
	@processorName varchar(128),
	@outFileFolderPath varchar(256) = '',			-- Path to folder containing source data; if blank, then will look up path in MT_Main
	@TaskID int output,								-- The job to process; if processing several jobs at once, then the first job number in the batch
	@taskAvailable tinyint output,
	@outFileName varchar(256) output,				-- Source file name
	@inFileName varchar(256) output,				-- Results file name
	@predFileName varchar(256) output,				-- Predict NETs results file name
	@message varchar(512) output,
	@ProcessStateMatch int = 40,
	@NextProcessState int = 45,
	@GANETProcessingTimeoutState int = 44,
	@ResultsFolderPath varchar(256) = '',			-- Path to folder containing the results; if blank, then will look up path in MT_Main
	@BatchSize int = 0,								-- If non-zero, then this value overrides the one present in T_Process_Config, entry NET_Update_Batch_Size
	@MaxPeptideCount int = 0						-- If non-zero, then this value overrides the one present in T_Process_Config, entry NET_Update_Max_Peptide_Count
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
	set @outFileName = ''
	set @inFileName = ''
	set @predFileName = ''
	set @message = ''

	declare @MatchCount int
	declare @S varchar(1024)

	-----------------------------------------------
	-- Populate a temporary table with the list of known Result Types appropriate for NET alignment
	-----------------------------------------------
	CREATE TABLE #T_ResultTypeList (
		ResultType varchar(64)
	)
	
	INSERT INTO #T_ResultTypeList (ResultType) Values ('Peptide_Hit')
	INSERT INTO #T_ResultTypeList (ResultType) Values ('XT_Peptide_Hit')
	INSERT INTO #T_ResultTypeList (ResultType) Values ('IN_Peptide_Hit')
	
		
	---------------------------------------------------
	-- Look for jobs that are timed out (State 44) and for which Last_Affected
	-- is more than 60 minutes ago; reset to state @ProcessStateMatch
	---------------------------------------------------
	--
	UPDATE T_Analysis_Description
	SET Process_State = @ProcessStateMatch
	WHERE Process_State = @GANETProcessingTimeoutState AND
		  DateDiff(Minute, Last_Affected, GetDate()) > 60
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	If @myRowCount > 0
	Begin
		Set @message = 'Jobs that were timed out (state ' + Convert(varchar(11), @GANETProcessingTimeoutState) + ') were reset to state ' + Convert(varchar(11), @ProcessStateMatch) + '; ' + Convert(varchar(11), @myRowCount) + ' updated'
		Exec PostLogEntry 'Error', @message, 'RequestGANETUpdateTask'
	End


	---------------------------------------------------
	-- Check for and reset stale NET update tasks
	---------------------------------------------------
	--
	Declare @CurrentTime datetime
	Declare @maxHoursUnchangedState int
	Set @maxHoursUnchangedState = 12

	Exec ResetStaleNETUpdateTasks @maxHoursUnchangedState, @ProcessStateMatch
	
	---------------------------------------------------
	-- Look for any jobs in state @ProcessStateMatch that
	-- do not have associated scan time information;
	-- If found, update their state to 43
	---------------------------------------------------
	--
	UPDATE T_Analysis_Description
	SET Process_State = 43, Last_Affected = GetDate()
	WHERE Job IN
        (	SELECT TAD.Job
			FROM T_Dataset_Stats_Scans DSS INNER JOIN
				 V_SIC_Job_to_PeptideHit_Map JobMap ON DSS.Job = JobMap.SIC_Job
					RIGHT OUTER JOIN T_Analysis_Description TAD ON 
				 JobMap.Job = TAD.Job
			WHERE (TAD.Process_State = @ProcessStateMatch)
			GROUP BY TAD.Job
			HAVING COUNT(DSS.Job) = 0
		)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		Set @message = 'Error looking for jobs that are missing scan stats info'
		Exec PostLogEntry 'Error', @message, 'RequestGANETUpdateTask'
		goto done
	end

	if @myRowCount > 0
	begin
		Set @message = 'Jobs were found that did not have associated ScanTime entries in T_Dataset_Stats_Scans; their states have been set to 43 (Updated ' + Convert(varchar(9), @myRowCount) + ' jobs)'
		Exec PostLogEntry 'Error', @message, 'RequestGANETUpdateTask'
	end


	---------------------------------------------------
	-- Look for any jobs in state 43 that
	-- now do have associated scan time information;
	-- If found, reset their state to @ProcessStateMatch
	---------------------------------------------------
	--
	UPDATE T_Analysis_Description
	SET Process_State = @ProcessStateMatch, Last_Affected = GetDate()
	WHERE Job IN
		(	SELECT TAD.Job
			FROM T_Dataset_Stats_Scans DSS INNER JOIN
				V_SIC_Job_to_PeptideHit_Map JobMap ON DSS.Job = JobMap.SIC_Job
					INNER JOIN T_Analysis_Description TAD ON 
				JobMap.Job = TAD.Job
			WHERE (TAD.Process_State = 43)
			GROUP BY TAD.Job
			HAVING COUNT(DSS.Job) > 0
		)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myRowCount > 0
	begin
		Set @message = 'Jobs that were in state 43 were reset to state ' + Convert(varchar(11), @ProcessStateMatch) + ' since a SIC job now exists; ' + Convert(varchar(11), @myRowCount) + ' updated'
		Exec PostLogEntry 'Normal', @message, 'RequestGANETUpdateTask'
	end
	
	
	---------------------------------------------------
	-- Start transaction
	---------------------------------------------------
	--
	declare @transName varchar(32)
	set @transName = 'RequestGANETUpateTask'
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
	-- Create a new NET Update task
	---------------------------------------------------
	
	INSERT INTO T_NET_Update_Task (Processing_State, Task_Created, Task_AssignedProcessorName)
	VALUES (1, GetDate(), @processorName)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount, @TaskID = Scope_Identity()
	--
	if @myError <> 0
	begin
		rollback transaction @transName
		set @message = 'Error adding new task to T_NET_Update_Task'
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
	Set @S = @S + ' INSERT INTO T_NET_Update_Task_Job_Map (Task_ID, Job)'
	Set @S = @S + ' SELECT ' + Convert(varchar(9), @TaskID) + ' AS Task_ID, A.Job'
	Set @S = @S + ' FROM ('
	Set @S = @S +   ' SELECT TOP ' + Convert(varchar(9), @BatchSize) + ' TAD.Job, IsNull(TAD.RowCount_Loaded,0) AS PeptideCount'
	Set @S = @S +   ' FROM T_Analysis_Description TAD WITH (HoldLock) INNER JOIN'
 	Set @S = @S +        ' #T_ResultTypeList RTL ON TAD.ResultType = RTL.ResultType'
	Set @S = @S +   ' WHERE TAD.Process_State = ' + Convert(varchar(9), @ProcessStateMatch)
	Set @S = @S +   ' ORDER BY TAD.Job'
	Set @S = @S +   ' ) A INNER JOIN ('
	Set @S = @S +   ' SELECT TOP ' + Convert(varchar(9), @BatchSize) + ' TAD.Job, IsNull(TAD.RowCount_Loaded,0) AS PeptideCount'
	Set @S = @S +   ' FROM T_Analysis_Description TAD INNER JOIN'
 	Set @S = @S +        ' #T_ResultTypeList RTL ON TAD.ResultType = RTL.ResultType'
	Set @S = @S +   ' WHERE TAD.Process_State =  ' + Convert(varchar(9), @ProcessStateMatch)
	Set @S = @S +   ' ORDER BY TAD.Job'
	Set @S = @S +   ' ) B ON B.Job <= A.Job'
	Set @S = @S + ' GROUP BY A.Job'
	Set @S = @S + ' HAVING SUM(B.PeptideCount) < ' + Convert(varchar(12), @MaxPeptideCount)
	Set @S = @S + ' ORDER BY A.Job ASC'
	--	
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
		Set @S = @S + ' INSERT INTO T_NET_Update_Task_Job_Map (Task_ID, Job)'
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
		 T_NET_Update_Task_Job_Map TJM ON TAD.Job = TJM.Job
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

	Exec @myError = ExportGANETData @TaskID,
									@outFileFolderPath, 
									@ResultsFolderPath,
									@outFileName = @outFileName OUTPUT, 
									@inFileName = @inFileName OUTPUT, 
									@predFileName = @predFileName OUTPUT, 
									@message = @message OUTPUT
	--
	if @myError = 0
	begin
		-- Advance Task_ID to state 2 = 'Update In Progress'
		Exec SetGANETUpdateTaskState @TaskID, 2, Null, @message output
	end
	else
	begin
		If Len(IsNull(@message, '')) = 0
			Set @message = 'Error calling ExportGANETData for TaskID ' + Convert(varchar(9), @TaskID)
		
		-- Error calling ExportGANETData
		-- Post an error log entry
		Exec PostLogEntry 'Error', @message, 'RequestGANETUpdateTask'

		-- Now update Task_ID to State 6 and rollback state of jobs to @GANETProcessingTimeoutState
		Exec SetGANETUpdateTaskState @TaskID, 6, @GANETProcessingTimeoutState, @message output
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
GRANT VIEW DEFINITION ON [dbo].[RequestGANETUpdateTask] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[RequestGANETUpdateTask] TO [MTS_DB_Lite]
GO
GRANT EXECUTE ON [dbo].[RequestGANETUpdateTask] TO [pnl\MTSProc]
GO
