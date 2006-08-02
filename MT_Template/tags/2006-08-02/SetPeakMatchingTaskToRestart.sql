SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[SetPeakMatchingTaskToRestart]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[SetPeakMatchingTaskToRestart]
GO


CREATE Procedure dbo.SetPeakMatchingTaskToRestart
/****************************************************
**
**	Desc:	Resets a Peak matching task to state 1, though
**			only updates the task if its current state is 1 or 2
**
**			Useful if Viper has an error and needs to exit, but
**			we want another copy of Viper to analyze the task
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	06/14/2006
**
*****************************************************/
(
	@taskID int,
	@message varchar(512) output
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0
	
	set @message = ''

	declare @taskState int
	declare @AssignedProcessorName varchar(128)
	declare @MatchCount int
	
	declare @MessageBase varchar(256)
	declare @PMTaskText varchar(64)
	Set @PMTaskText = 'Peak matching task ' + Convert(varchar(19), @taskID)
	
	---------------------------------------------------
	-- Resolve task ID to state
	---------------------------------------------------
	--
	set @taskState = 0
	set @AssignedProcessorName = ''
	--
	SELECT	@taskState = Processing_State,
			@AssignedProcessorName = PM_AssignedProcessorName
	FROM T_Peak_Matching_Task
	WHERE Task_ID = @taskID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 or @myRowCount <> 1
	begin
		set @myError = 51220
		set @message = 'Could not get information for ' + @PMTaskText
		goto done
	end

	---------------------------------------------------
	-- Check task state for "in progress" or "new"
	---------------------------------------------------
	
	If @taskState = 1
	Begin
		-- Task already in the correct state
		Goto Done
	End
	
	If @taskState <> 2
	begin
		set @myError = 51221
		set @message = 'State not correct for ' + @PMTaskText + '; state is ' + convert(varchar(12), @taskState) + ' but expecting state 2'
		goto done
	end

	---------------------------------------------------
	-- Post a warning or Error to the log, then reset the state to 1
	-- However, if 2 warnings have already been posted to the log for
	-- this peak matching task within the last 4 hours, then set the state to 4
	---------------------------------------------------

	Set @MessageBase = 'Reset processing state to 1 for ' + @PMTaskText
	
	SELECT @MatchCount = COUNT(*)
	FROM T_Log_Entries
	WHERE (Posted_By = 'SetPeakMatchingTaskToRestart') AND 
		  (DATEDIFF(hour, Posting_Time, GetDate()) <= 4) AND
		  (Message LIKE @MessageBase + '%')
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	If @MatchCount >= 2
	Begin
		Set @message = @PMTaskText + ' has been reset twice in the last 4 hours; setting state to 4'
		Exec PostLogEntry 'Error', @message, 'SetPeakMatchingTaskToRestart'

		UPDATE T_Peak_Matching_Task
		SET Processing_State = 4,
			Processing_Error_Code = 8192,
			Processing_Warning_Code = 0
		WHERE Task_ID = @taskID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	End
	Else
	Begin
		Set @message = @MessageBase + ' since processor ' + @AssignedProcessorName + ' had a fatal error'
		Exec PostLogEntry 'Warning', @message, 'SetPeakMatchingTaskToRestart'
		Set @taskState = 1		

		UPDATE T_Peak_Matching_Task
		SET Processing_State = 1,
			PM_Start = Null,
			PM_Finish = Null,
			PM_AssignedProcessorName = ''
		WHERE Task_ID = @taskID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	End

	if @myError <> 0 or @myRowCount <> 1
	begin
		set @message = 'Update operation failed for ' + @PMTaskText
		set @myError = 51222
		goto done
	end
	
	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:

	If @myError <> 0
	Begin
		Exec PostLogEntry 'Error', @message, 'SetPeakMatchingTaskToRestart', 4
	End
	
	return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[SetPeakMatchingTaskToRestart]  TO [DMS_SP_User]
GO

