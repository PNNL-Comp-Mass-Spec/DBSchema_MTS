/****** Object:  StoredProcedure [dbo].[CheckStaleTasks] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.CheckStaleTasks
/****************************************************
** 
**		Desc: 
**			Looks for Peak Matching tasks and GANET Update tasks
**			stuck in the processing state for over @maxHoursProcessing hours
**
**		Return values: 0: success, otherwise, error code
** 
**		Parameters:
**
**		Auth: mem
**		Date: 04/11/2005
**    
*****************************************************/
(
	@maxHoursProcessing int = 24,
	@message varchar(255) = '' output
)
As
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @intContinue tinyint
	declare @taskID int
	
	declare @logMessage varchar(255)
	
	declare @ProcessorName varchar(128)
	declare @PMStart datetime
	
	set @message = ''

	--------------------------------------------------------------
	-- Create a temporary table to hold the stale tasks
	--------------------------------------------------------------
	CREATE TABLE #StaleTasks (
		Task_ID int NOT NULL
	) 
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	If @myError <> 0
	Begin
		Set @message = 'Could not Create temporary table #StaleTasks'
		goto Done
	End

	
	--------------------------------------------------------------
	-- Populate #StaleTasks with any stale Peak Matching tasks
	--------------------------------------------------------------
	--
	INSERT INTO #StaleTasks (Task_ID)
	SELECT	Task_ID
	FROM	T_Peak_Matching_Task
	WHERE	Processing_State = 2 AND 
			DateDiff(Minute, PM_Created, GetDate()) > @maxHoursProcessing * 60 AND
			DateDiff(Minute, PM_Start, GetDate()) > @maxHoursProcessing * 60
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	If @myRowCount > 0
	Begin

		--------------------------------------------------------------
		-- Post a log entry for each task stuck in state 2
		--------------------------------------------------------------

		Set @intContinue = 1
		Set @taskID = -1
		
		While @intContinue = 1
		Begin
		
			--------------------------------------------------------------
			-- Grab the next task
			--------------------------------------------------------------
			
			SELECT TOP 1 @TaskID = P.Task_ID, 
						 @ProcessorName = IsNull(P.PM_AssignedProcessorName, 'Unknown'),
						 @PMStart = P.PM_Start
			FROM	T_Peak_Matching_Task AS P INNER JOIN #StaleTasks ON
					P.Task_ID = #StaleTasks.Task_ID
			WHERE	P.Task_ID > @TaskID
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
		
		
			IF @myRowCount = 0
				Set @intContinue = 0
			Else
			Begin
				Set @logMessage = 'Peak matching task ' + Convert(varchar(11), @TaskID) + ' has been in state 2 for over ' + Convert(varchar(11), @maxHoursProcessing) + ' hours (began processing ''' + Convert(varchar(25), @PMStart) + ''' on processor ' + @ProcessorName + '); the task has been reset to state 1'
				execute PostLogEntry 'Error', @logMessage, 'CheckStaleTasks'
			End
		End

		--------------------------------------------------------------
		-- Reset Processing_State to 1 for all tasks in #StaleTasks
		--------------------------------------------------------------

		UPDATE	T_Peak_Matching_Task
		SET		Processing_State = 1, PM_Start = Null, PM_AssignedProcessorName = NULL
		FROM	T_Peak_Matching_Task INNER JOIN #StaleTasks ON
				T_Peak_Matching_Task.Task_ID = #StaleTasks.Task_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		Set @message = 'Reset processing state to 1 for ' + Convert(varchar(11), @myRowCount) + ' peak matching tasks'
	End


	
	--------------------------------------------------------------
	-- Populate #StaleTasks with any stale GANET Update tasks
	--------------------------------------------------------------
	--
	TRUNCATE TABLE #StaleTasks
	
	INSERT INTO #StaleTasks (Task_ID)
	SELECT	Task_ID
	FROM	T_GANET_Update_Task
	WHERE	Processing_State IN (2,7) AND 
			DateDiff(Minute, Task_Created, GetDate()) > @maxHoursProcessing * 60 AND
			DateDiff(Minute, Task_Start, GetDate()) > @maxHoursProcessing * 60
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	If @myRowCount > 0
	Begin

		--------------------------------------------------------------
		-- Post a log entry for each task stuck in states 2 or 7
		--------------------------------------------------------------

		Set @intContinue = 1
		Set @taskID = -1
		
		While @intContinue = 1
		Begin
		
			--------------------------------------------------------------
			-- Grab the next task
			--------------------------------------------------------------
			
			SELECT TOP 1 @TaskID = G.Task_ID, 
						 @ProcessorName = IsNull(G.Task_AssignedProcessorName, 'Unknown'),
						 @PMStart = G.Task_Start
			FROM	T_GANET_Update_Task AS G INNER JOIN #StaleTasks ON
					G.Task_ID = #StaleTasks.Task_ID
			WHERE	G.Task_ID > @TaskID
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
		
		
			IF @myRowCount = 0
				Set @intContinue = 0
			Else
			Begin
				Set @logMessage = 'GANET Update task ' + Convert(varchar(11), @TaskID) + ' has been in state 2 or 7 for over ' + Convert(varchar(11), @maxHoursProcessing) + ' hours (began processing ''' + Convert(varchar(25), @PMStart) + ''' on processor ' + @ProcessorName + '); the task has been reset to state 1'
				execute PostLogEntry 'Error', @logMessage, 'CheckStaleTasks'
			End
		End

		--------------------------------------------------------------
		-- Reset Processing_State to 1 for all tasks in #StaleTasks
		--------------------------------------------------------------

		UPDATE	T_GANET_Update_Task
		SET		Processing_State = 1, Task_Start = Null, Task_AssignedProcessorName = NULL
		FROM	T_GANET_Update_Task INNER JOIN #StaleTasks ON
				T_GANET_Update_Task.Task_ID = #StaleTasks.Task_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If Len(@message) > 0
			Set @message = @message + '; '

		Set @message = 'Reset processing state to 1 for ' + Convert(varchar(11), @myRowCount) + ' GANET Update tasks'
	End

	
Done:
	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[CheckStaleTasks] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[CheckStaleTasks] TO [MTS_DB_Lite]
GO
