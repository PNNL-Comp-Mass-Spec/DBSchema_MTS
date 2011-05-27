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
**			10/13/2010 mem - Now looking up the AMT Count FDR stats using V_PM_Results_FDR_Stats and then storing the values in T_Analysis_Job
**			10/14/2010 mem - Added parameter @DebugMode
**			
*****************************************************/
(
	@taskID int,
	@serverName varchar(128),
	@mtdbName varchar (128),
	@JobID int = NULL,				-- Job number in T_Analysis_Job
	@JobStateID int = 3,
	@DebugMode tinyint = 0
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	declare @AssignedProcessor varchar(128)
	declare @TimeCompleted as datetime
	declare @message varchar(4000)
	
	declare @WorkingServerPrefix varchar(128)
	declare @S nvarchar(1024)
	declare @SqlParams nvarchar(1024)
	
	declare @AMTCount1pctFDR int = 0,
            @AMTCount5pctFDR int = 0,
            @AMTCount10pctFDR int = 0,
            @AMTCount25pctFDR int = 0,
            @AMTCount50pctFDR int = 0


	---------------------------------------------------
	-- Validate the inputs
	---------------------------------------------------	
	Set @JobID = IsNull(@JobID, 0)
	Set @DebugMode = IsNull(@DebugMode, 0)

	---------------------------------------------------
	-- Cache the current time and lookup the cached History ID value
	---------------------------------------------------
	Set @TimeCompleted = GetDate()
	
	If @JobID <> 0
	Begin

		Set @message = 'Look for @JobID in T_Analysis_Job for job ' + convert(varchar(12), @JobID)
		If @DebugMode <> 0
			Exec PostLogEntry 'Debug', @message, 'SetPeakMatchingActivityValuesToComplete'

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

		Set @message = 'Lookup processor name using T_Peak_Matching_Activity; Task_ID = ' + Convert(varchar(12), @taskID)
		If @DebugMode <> 0
			Exec PostLogEntry 'Debug', @message, 'SetPeakMatchingActivityValuesToComplete'

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


	Set @message = 'Update T_Peak_Matching_Activity for processor ' + @AssignedProcessor
	If @DebugMode <> 0
		Exec PostLogEntry 'Debug', @message, 'SetPeakMatchingActivityValuesToComplete'

	
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
	-- Lookup the AMT Count FDR values for this peak matching task
	---------------------------------------------------

	Set @message = 'Prepare SQL for extracting AMT_Count FDR values'
	If @DebugMode <> 0
		Exec PostLogEntry 'Debug', @message, 'SetPeakMatchingActivityValuesToComplete'
	
	-- Construct the working server prefix
	If Lower(@@ServerName) = Lower(@serverName)
		Set @WorkingServerPrefix = ''
	Else
		Set @WorkingServerPrefix = @serverName + '.'
	
	Set @S = ''
	Set @S = @S + ' SELECT '
	Set @S = @S +    ' @AMTCount1pctFDR = AMT_Count_1pct_FDR,'
	Set @S = @S +    ' @AMTCount5pctFDR = AMT_Count_5pct_FDR,'
	Set @S = @S +    ' @AMTCount10pctFDR = AMT_Count_10pct_FDR,'
	Set @S = @S +    ' @AMTCount25pctFDR = AMT_Count_25pct_FDR,'
	Set @S = @S +    ' @AMTCount50pctFDR = AMT_Count_50pct_FDR'
	Set @S = @S + ' FROM ' + @WorkingServerPrefix + '[' + @mtdbname + '].dbo.V_PM_Results_FDR_Stats'
	Set @S = @S + ' WHERE Task_ID = ' + Convert(varchar(12), @taskID)
	
	Set @SqlParams = '@AMTCount1pctFDR int output, @AMTCount5pctFDR int output, @AMTCount10pctFDR int output, @AMTCount25pctFDR int output, @AMTCount50pctFDR int output'

	
	Set @message = 'Sql to execute: ' + @S
	If @DebugMode <> 0
		Exec PostLogEntry 'Debug', @message, 'SetPeakMatchingActivityValuesToComplete'

	Set @message = 'SqlParams: ' + @SqlParams
	If @DebugMode <> 0
		Exec PostLogEntry 'Debug', @message, 'SetPeakMatchingActivityValuesToComplete'

	
	exec sp_executeSql @S, @SqlParams,  @AMTCount1pctFDR output,
										@AMTCount5pctFDR output,
										@AMTCount10pctFDR output,
										@AMTCount25pctFDR output,
										@AMTCount50pctFDR output
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	Set @message = 'Executed Sql; @AMTCount1pctFDR=' + IsNull(Convert(varchar(12), @AMTCount1pctFDR), 'NULL')
	Set @message = @message +  '; @AMTCount5pctFDR=' + IsNull(Convert(varchar(12), @AMTCount5pctFDR), 'NULL')
	Set @message = @message +  '; @AMTCount10pctFDR=' + IsNull(Convert(varchar(12), @AMTCount10pctFDR), 'NULL')
	Set @message = @message +  '; @AMTCount25pctFDR=' + IsNull(Convert(varchar(12), @AMTCount25pctFDR), 'NULL')
	Set @message = @message +  '; @AMTCount50pctFDR=' + IsNull(Convert(varchar(12), @AMTCount50pctFDR), 'NULL')

	If @DebugMode <> 0
		Exec PostLogEntry 'Debug', @message, 'SetPeakMatchingActivityValuesToComplete'

	If @myError <> 0
	Begin
		Set @message = 'Error looking up AMT Count FDR values for Task ' + Convert(varchar(12), @taskID) + ' using "' + @WorkingServerPrefix + '[' + @mtdbname + '].dbo.V_PM_Results_FDR_Stats"'
		Exec PostLogEntry 'Error', @message, 'SetPeakMatchingActivityValuesToComplete'
		set @message = ''
	End
	
	---------------------------------------------------
	-- Update T_Analysis_Job with the current time
	---------------------------------------------------

	If IsNull(@JobID, 0) > 0
	Begin
		UPDATE T_Analysis_Job
		SET Job_Finish = @TimeCompleted,
		    State_ID = @JobStateID,
		    AMT_Count_1pct_FDR = @AMTCount1pctFDR,
		    AMT_Count_5pct_FDR = @AMTCount5pctFDR,
		    AMT_Count_10pct_FDR = @AMTCount10pctFDR,
		    AMT_Count_25pct_FDR = @AMTCount25pctFDR,
		    AMT_Count_50pct_FDR = @AMTCount50pctFDR
		WHERE Job_ID = @JobID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @myError <> 0
		Begin
			Set @message = 'Error updating T_Analysis_Job for Job ' + Convert(varchar(12), @JobID)
			Exec PostLogEntry 'Error', @message, 'SetPeakMatchingActivityValuesToComplete'
		End
		Else
		Begin
			Set @message = 'Updated T_Analysis_Job for Job ' + Convert(varchar(12), @JobID)
			If @DebugMode <> 0
				Exec PostLogEntry 'Debug', @message, 'SetPeakMatchingActivityValuesToComplete'
		End

	End
	Else
	Begin
		Set @message = '@JobID is Null or 0; cannot update T_Analysis_Job'
		Exec PostLogEntry 'Debug', @message, 'SetPeakMatchingActivityValuesToComplete'
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
