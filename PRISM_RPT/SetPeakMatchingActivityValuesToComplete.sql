/****** Object:  StoredProcedure [dbo].[SetPeakMatchingActivityValuesToComplete] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.SetPeakMatchingActivityValuesToComplete
/****************************************************
**
**	Desc: Updates T_Peak_Matching_Activity and T_Analysis_Job for the given task
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	06/14/2006
**			01/03/2008 mem - Now using T_Analysis_Job to track assigned tasks
**			
*****************************************************/
(
	@taskID int,
	@serverName varchar(128),
	@mtdbName varchar (128),
	@JobID int = NULL,				-- Job number in T_Analysis_Job
	@JobStateID int = 3
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	declare @AssignedProcessor varchar(128)
	declare @TimeCompleted as datetime
	declare @message varchar(512)
	
	Set @JobID = IsNull(@JobID, 0)

	---------------------------------------------------
	-- Cache the current time and lookup the cached History ID value
	---------------------------------------------------
	Set @TimeCompleted = GetDate()
	
	If @JobID <> 0
	Begin
		-- Look for @JobID in T_Analysis_Job to determine the Processor Name
		SELECT TOP 1 @AssignedProcessor = Assigned_Processor_Name
		FROM T_Peak_Matching_Activity
		WHERE Job_ID = @JobID
		ORDER BY Task_Start DESC
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myRowCount = 0
		Begin
			Set @message = 'No match found in T_Peak_Matching_Activity for Job ID ' + Convert(varchar(12), @JobID) + ' (Task ' + Convert(varchar(12), @taskID) + ' in DB ' + @mtdbName + ' on server ' + @serverName + '); unable to mark the task as "Complete"'
			Exec PostLogEntry 'Error', @message, 'SetPeakMatchingActivityValuesToComplete'
			Goto Done
		End

	End
	Else
	Begin
		---------------------------------------------------
		-- Find the processor name that most recently processed
		-- task @taskID in DB @mtdbName 
		---------------------------------------------------

		SELECT TOP 1 @AssignedProcessor = Assigned_Processor_Name
		FROM T_Peak_Matching_Activity
		WHERE Server_Name = @serverName AND Database_Name = @mtdbName AND Task_ID = @taskID
		ORDER BY Task_Start DESC
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myRowCount = 0
		Begin
			Set @message = 'No match found in T_Peak_Matching_Activity for Task ' + Convert(varchar(12), @taskID) + ' in DB ' + @mtdbName + ' on server ' + @serverName + '; unable to mark the task as "Complete"'
			Exec PostLogEntry 'Error', @message, 'SetPeakMatchingActivityValuesToComplete'
			Goto Done
		End
			

		---------------------------------------------------
		-- Lookup the cached Job ID
		---------------------------------------------------
		
		Set @JobID = 0
		SELECT	@JobID = Job_ID
		FROM T_Peak_Matching_Activity
		WHERE Assigned_Processor_Name = @AssignedProcessor
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	End
	
	---------------------------------------------------
	-- Update T_Peak_Matching_Activity with the current time
	-- Set Working = 0 and increment TasksCompleted
	---------------------------------------------------

	UPDATE T_Peak_Matching_Activity
	SET Working = 0, Task_Finish = @TimeCompleted,
		Tasks_Completed = Tasks_Completed + 1
	WHERE Assigned_Processor_Name = @AssignedProcessor
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	---------------------------------------------------
	-- Update T_Analysis_Job with the current time
	---------------------------------------------------

	If IsNull(@JobID, 0) > 0
	Begin
		UPDATE T_Analysis_Job
		SET Job_Finish = @TimeCompleted,
			State_ID = @JobStateID
		WHERE Job_ID = @JobID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	End


	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	return @myError


GO
GRANT EXECUTE ON [dbo].[SetPeakMatchingActivityValuesToComplete] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[SetPeakMatchingActivityValuesToComplete] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[SetPeakMatchingActivityValuesToComplete] TO [MTS_DB_Lite] AS [dbo]
GO
