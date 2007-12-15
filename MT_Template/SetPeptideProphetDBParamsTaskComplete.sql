/****** Object:  StoredProcedure [dbo].[SetPeptideProphetDBParamsTaskComplete] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.SetPeptideProphetDBParamsTaskComplete
/****************************************************
**
**	Desc: Sets a peptide prophet DB params update task as complete or failed
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**		Auth: mem
**		Date: 11/09/2007
**
*****************************************************/
(
	@taskID int,
	@completionCode int = 0, -- 0->Success, 1->UpdateFailed
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
	declare @newTaskState int

	---------------------------------------------------
	-- resolve task ID to state
	---------------------------------------------------
	--
	set @taskState = 0
	--
	SELECT @taskState = Processing_State
	FROM T_Peptide_Prophet_DB_Update_Task
	WHERE (Task_ID = @taskID)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 or @myRowCount <> 1
	begin
		set @myError = 51220
		set @message = 'Could not get information for task'
		goto done
	end

	---------------------------------------------------
	-- check task state
	---------------------------------------------------

	if @completionCode = 0 and @taskState = 2
		begin
				set @newTaskState = 3 -- Update Complete
		end
	else
	if @completionCode = 1 and @taskState = 2
		begin
				set @newTaskState = 4 -- update failed
		end
	else
		begin
			set @myError = 51250
			set @message = 'State transition not correct'
			goto done
		end

	---------------------------------------------------
	-- Update state 
	---------------------------------------------------
	
	UPDATE T_Peptide_Prophet_DB_Update_Task
	SET Processing_State = @newTaskState, 
		Task_Finish = GETDATE()
	WHERE     (Task_ID = @taskID)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 or @myRowCount <> 1
	begin
		set @message = 'Update operation failed'
		set @myError = 99
		goto done
	end
	
	if @myError <> 0
	Begin
		Set @message = 'Peptide Prophet DB Params update task ' + convert(varchar(19), @taskID) + ' generated error code ' + convert(varchar(19), @myError)
		Exec PostLogEntry 'Error', @message, 'SetPeptideProphetDBParamsTaskComplete'
		Set @message = ''
	End
	
	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	return @myError


GO
