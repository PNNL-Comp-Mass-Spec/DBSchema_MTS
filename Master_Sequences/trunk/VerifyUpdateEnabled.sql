/****** Object:  StoredProcedure [dbo].[VerifyUpdateEnabled] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.VerifyUpdateEnabled
/****************************************************
** 
**	Desc: 
**		Checks whether @StepName is Enabled in MT_Main.dbo.T_Process_Step_Control
**		If it is not Enabled, then sets @UpdateEnabled to 0
**		 and optionally posts a warning message to the log
**		If the step is paused and @AllowPausing = 1, then enters an infinite loop, 
**		 checking for a change in Execution_State every 20 seconds
**		If the step is paused and @AllowPausing = 0, then does not pause, but
**		 sets @UpdateEnabled to 0
**
**	Return values: 0: success, otherwise, error code
** 
**	Parameters:
**
**	Auth:	mem
**	Date:	03/10/2006
**			03/11/2006 mem - Now populating the Last_Query fields and added support for pausing
**			03/12/2006 mem - Altered behavior to set @UpdateEnabled to 0 if @StepName is not in T_Process_Step_Control
**			03/13/2006 mem - Added support for Execution_State 3 (Pause with manual unpause)
**			03/14/2006 mem - Now updating Pause_Length_Minutes in MT_Main.dbo.T_Current_Activity if any pausing occurs and Update_State = 2
**    
*****************************************************/
(
	@StepName varchar(64) = 'Master_Sequences_Update',
	@CallingFunctionDescription varchar(128) = 'Unknown',
	@AllowPausing tinyint = 0,							-- Set to 1 to allow pausing if Execution_State is 2 or 3
	@PostLogEntryIfDisabled tinyint = 1,
	@MinimumHealthUpdateIntervalSeconds int = 5,		-- Minimum interval between updating the Last_Query fields
	@UpdateEnabled tinyint = 0 output,
	@message varchar(255) = '' output
)
As
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	set @message = ''
	set @MinimumHealthUpdateIntervalSeconds = IsNull(@MinimumHealthUpdateIntervalSeconds, 5)

	-- Make sure @CallingFunctionDescription is not null, and prepend it with the database name
	set @CallingFunctionDescription = IsNull(@CallingFunctionDescription, 'Unknown')

	Declare @MaximumPauseLengthHours int
	Declare @SleepTimeSeconds int
	Declare @SleepTime datetime
	
	Set @MaximumPauseLengthHours = 48
	Set @SleepTimeSeconds = 20
	Set @SleepTime = Convert(datetime, @SleepTimeSeconds/86400.0)
	
	Declare @CallingDBAndDescription varchar(255)
	set @CallingDBAndDescription = DB_Name() + ': ' + @CallingFunctionDescription

	Declare @ExecutionState int		-- 0 = Disabled, 1 = Enabled, 2 = Paused with auto unpause, 3 = Pause with manual unpause
	Declare @PauseStartLogged tinyint
	Declare @LastUpdateTime datetime
	Declare @PauseStartTime datetime
	Declare @PauseAborted tinyint
	
	Set @UpdateEnabled = 0
	Set @PauseStartLogged = 0
	Set @PauseAborted = 0
	Set @LastUpdateTime = GetDate()-1

	Declare @PauseLengthMinutes real
	Declare @PauseLengthMinutesAtStart real
	Declare @LastCurrentActivityUpdateTime datetime
	Set @PauseLengthMinutes = 0
	Set @PauseLengthMinutesAtStart = 0
	Set @LastCurrentActivityUpdateTime = @LastUpdateTime
	
	Set @ExecutionState = 2
	While (@ExecutionState = 2 OR @ExecutionState = 3) AND @myError = 0
	Begin -- <a>
		SELECT @ExecutionState = Execution_State, @StepName = Processing_Step_Name
		FROM MT_Main.dbo.T_Process_Step_Control
		WHERE Processing_Step_Name = @StepName
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @myRowCount = 0 OR @myError <> 0
		Begin -- <b1>
			-- Error or entry not found in MT_Main.dbo.T_Process_Step_Control
			-- Assume the step is disabled and post an error to the log, but limit to one posting every hour
			If @myError = 0
			Begin
				Set @message = 'Processing step ' + @StepName + ' was not found in MT_Main.dbo.T_Process_Step_Control'
				Set @myError = 20000
			End
			Else
			Begin
				Set @message = 'Error examining state of processing step ' + @StepName + ' in MT_Main.dbo.T_Process_Step_Control'
			End

			EXEC PostLogEntry 'Error', @message, 'VerifyUpdateEnabled', 1

			Set @ExecutionState = 0
		End -- </b1>
		Else
		Begin -- <b2>
			If (@ExecutionState = 2 OR @ExecutionState = 3) AND @AllowPausing = 0
				Set @ExecutionState = 0

			-- Update the Last_Query information in T_Process_Step_Control
			If (@ExecutionState = 2 OR @ExecutionState = 3)
			Begin -- <c1>
				-- Execution is paused
				-- Post a log entry if this is the first loop
				If @PauseStartLogged = 0
				Begin
					Set @message = 'Pausing processing step ' + @StepName + ' (called by ' + @CallingFunctionDescription + ')'
					EXEC PostLogEntry 'Normal', @message, 'VerifyUpdateEnabled'
					Set @message = ''
					
					Set @PauseStartTime = GetDate()
					Set @PauseStartLogged = 1

					-- Populate @PauseLengthMinutesAtStart
					SELECT @PauseLengthMinutesAtStart = Pause_Length_Minutes
					FROM MT_Main.dbo.T_Current_Activity
					WHERE Database_Name = DB_Name() AND Update_State = 2
					--
					SELECT @myError = @@error, @myRowCount = @@rowcount
					
					If @myRowCount < 1
						Set @PauseLengthMinutesAtStart = 0
				End
						
				-- Only update the Last_Query fields in MT_Main every 10 minutes when paused
				If DateDiff(minute, @LastUpdateTime, GetDate()) >= 10
				Begin
					UPDATE MT_Main.dbo.T_Process_Step_Control
					SET Last_Query_Date = GetDate(), 
						Last_Query_Description = @CallingDBAndDescription,
						Last_Query_Update_Count = Last_Query_Update_Count + 1,
						Pause_Location = @CallingDBAndDescription
					WHERE Processing_Step_Name = @StepName
					--
					SELECT @myError = @@error, @myRowCount = @@rowcount
					
					Set @LastUpdateTime = GetDate()
				End

				-- Update Pause_Length_Minutes in T_Current_Activity every 2 minutes when paused
				If DateDiff(minute, @LastCurrentActivityUpdateTime, GetDate()) >= 2
				Begin
					Set @PauseLengthMinutes = DateDiff(minute, @PauseStartTime, GetDate())
					If @PauseLengthMinutes < 1440
						Set @PauseLengthMinutes = DateDiff(second, @PauseStartTime, GetDate()) / 60.0
					
					UPDATE MT_Main.dbo.T_Current_Activity
					SET Pause_Length_Minutes = @PauseLengthMinutesAtStart + @PauseLengthMinutes
					WHERE Database_Name = DB_Name() AND Update_State = 2
					--
					SELECT @myError = @@error, @myRowCount = @@rowcount
				
					Set @LastCurrentActivityUpdateTime = GetDate()
				End
								
				-- Check for too much time elapsed since @PauseStartTime
				Set @PauseLengthMinutes = DateDiff(minute, @PauseStartTime, GetDate())
				If @PauseLengthMinutes / 60.0 >= @MaximumPauseLengthHours
				Begin
					-- This SP has been looping for @MaximumPauseLengthHours
					-- Disable this processing step in T_Process_Step_Control and stop looping
					UPDATE MT_Main.dbo.T_Process_Step_Control
					SET Execution_State = 0
					WHERE Processing_Step_Name = @StepName
					--
					SELECT @myError = @@error, @myRowCount = @@rowcount
					
					Set @message = 'Processing step ' + @StepName + ' has been paused for ' + Convert(varchar(9), @MaximumPauseLengthHours) + ' hours; updated Execution_State to 0 for this step and aborting the pause (called by ' + @CallingFunctionDescription + ')'
					
					EXEC PostLogEntry 'Error', @message, 'VerifyUpdateEnabled'
					
					Set @ExecutionState = 0
					Set @PauseAborted = 1
				End

				If (@ExecutionState = 2 OR @ExecutionState = 3)
				Begin
					-- Pause for @SleepTimeSeconds
					WaitFor Delay @SleepTime
				End

			End -- </c1>
			Else
			Begin -- <c2>
				-- Execution is not paused
				-- Limit the updates to occur at least @MinimumHealthUpdateIntervalSeconds apart 
				--  to keep the DB transaction logs from growing too large
				-- Note: The purpose of the CASE statement in the Where clause is to prevent overflow
				--  errors when computing the difference between Last_Query_Date and the current time
				UPDATE MT_Main.dbo.T_Process_Step_Control
				SET Last_Query_Date = GetDate(), 
					Last_Query_Description = @CallingDBAndDescription,
					Last_Query_Update_Count = Last_Query_Update_Count + 1
				WHERE Processing_Step_Name = @StepName AND 
					  CASE WHEN IsNull(Last_Query_Date, GetDate()-1) <= GetDate()-1 THEN @MinimumHealthUpdateIntervalSeconds
					  ELSE DateDiff(second, Last_Query_Date, GetDate()) 
					  END >= @MinimumHealthUpdateIntervalSeconds
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
			End -- </c2>
		End -- </b2>
	End -- </a>

	If @PauseStartLogged = 1
	Begin
		-- Clear Pause_Location in MT_Main.dbo.T_Process_Step_Control
		UPDATE MT_Main.dbo.T_Process_Step_Control
		SET Pause_Location = ''
		WHERE Processing_Step_Name = @StepName
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		-- Store the final value for Pause_Length_Minutes in MT_Main.dbo.T_Current_Activity
		Set @PauseLengthMinutes = DateDiff(minute, @PauseStartTime, GetDate())
		If @PauseLengthMinutes < 1440
			Set @PauseLengthMinutes = DateDiff(second, @PauseStartTime, GetDate()) / 60.0
		
		UPDATE MT_Main.dbo.T_Current_Activity
		SET Pause_Length_Minutes = @PauseLengthMinutesAtStart + @PauseLengthMinutes
		WHERE Database_Name = DB_Name() AND Update_State = 2
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		-- Post a message to T_Log_Entries
		If @PauseAborted = 0
		Begin
			Set @message = 'Resuming processing step ' + @StepName
			EXEC PostLogEntry 'Normal', @message, 'VerifyUpdateEnabled'
			Set @message = ''
		End
	End
		
	If @ExecutionState = 1
		Set @UpdateEnabled = 1
			
	If @UpdateEnabled = 0 AND @PauseAborted = 0 AND @myError = 0
	Begin
		Set @message = 'Processing step ' + @StepName + ' is disabled in MT_Main; aborting processing (called by ' + @CallingFunctionDescription + ')'

		If @PostLogEntryIfDisabled = 1
		Begin
			-- Post a warning to the log, but limit to one posting every hour
			EXEC PostLogEntry 'Warning', @message, 'VerifyUpdateEnabled', 1
		End
	End
	
Done:
	return @myError


GO
GRANT EXECUTE ON [dbo].[VerifyUpdateEnabled] TO [DMS_SP_User]
GO
