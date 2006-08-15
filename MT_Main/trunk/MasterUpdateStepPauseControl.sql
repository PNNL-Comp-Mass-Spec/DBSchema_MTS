/****** Object:  StoredProcedure [dbo].[MasterUpdateStepPauseControl] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.MasterUpdateStepPauseControl
/****************************************************
** 
**	Desc:	Pauses or unpauses entries defined in T_Process_Step_Control
**			Ignores entries with execution_state values of 0
**		
**
**	Return values: 0: success, otherwise, error code
** 
**	Parameters:
**
**	Auth:	mem
**	Date:	03/11/2006
**    
*****************************************************/
(
	@Pause tinyint = 0,								-- Set to 1 to pause, 0 to unpause; ignored if @Enable = 0
	@ProcessingStepNameFilter varchar(64) = '',		-- Optional filter
	@PostLogEntry tinyint = 1,
	@message varchar(255) = '' output
)
As
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	declare @ExecutionStateMatch int
	declare @NewExecutionState int
	
	Set @ProcessingStepNameFilter = IsNull(@ProcessingStepNameFilter, '')
	
	If IsNull(@Pause, 255) < 255
	Begin
		If @Pause = 0
		Begin
			Set @ExecutionStateMatch = 2
			Set @NewExecutionState = 1
		End
		Else
		Begin
			Set @ExecutionStateMatch = 1
			Set @NewExecutionState = 2
		End
		
		UPDATE T_Process_Step_Control
		SET Execution_State = @NewExecutionState
		WHERE Execution_State = @ExecutionStateMatch AND
			  (@ProcessingStepNameFilter = '' OR Processing_Step_Name = @ProcessingStepNameFilter)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @myRowCount = 0
		Begin
			set @message = 'No tasks were found with state ' + Convert(varchar(9), @ExecutionStateMatch)
			If @ProcessingStepNameFilter <> ''
				Set @message = @message + ' for Processing Step ' + @ProcessingStepNameFilter
		End
		Else
		Begin
			If @Pause = 0
				Set @message = 'Unpaused ' 
			Else
				Set @message = 'Paused ' 
	
			Set @message = @message + Convert(varchar(9), @myrowCount) + ' Master Update tasks'
			
			If @PostLogEntry <> 0
				execute PostLogEntry 'Normal', @message, 'MasterUpdateStepPauseControl'
		End

	End
	
Done:
	return @myError

GO
