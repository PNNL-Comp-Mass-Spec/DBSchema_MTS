/****** Object:  StoredProcedure [dbo].[SetGANETUpdateTaskComplete] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.SetGANETUpdateTaskComplete
/****************************************************
**
**	Desc: 
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth: 	grk
**	Date: 	08/26/2003   
**			11/26/2003 grk - added GANET task state 7
**			11/09/2007 mem - Updated procedure name sent to PostLogEntry
**
**
*****************************************************/
(
	@taskID int,
	@completionCode int = 0, -- 0->Success, 1->UpdateFailed, 2->ResultsFailed
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
	FROM T_GANET_Update_Task
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
				set @newTaskState = 3 -- results ready
		end
	else
	if @completionCode = 0 and @taskState = 3
		begin
				set @newTaskState = 7 -- update complete
		end
	else
	if @completionCode = 0 and @taskState = 7
		begin
				set @newTaskState = 4 -- update complete
		end
	else
	if @completionCode = 1 and @taskState = 2
		begin
				set @newTaskState = 5 -- update failed
		end
	else
	if @completionCode = 2 and @taskState = 7
		begin
				set @newTaskState = 6 -- Results failed
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
	
	UPDATE T_GANET_Update_Task
	SET 
		Processing_State = @newTaskState, 
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
		Set @message = 'GANET update task ' + convert(varchar(19), @taskID) + ' generated error code ' + convert(varchar(19), @myError)
		Exec PostLogEntry 'Error', @message, 'SetGANETUpdateTaskComplete'
		Set @message = ''
	End
	
	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[SetGANETUpdateTaskComplete] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[SetGANETUpdateTaskComplete] TO [MTS_DB_Lite]
GO
GRANT EXECUTE ON [dbo].[SetGANETUpdateTaskComplete] TO [pnl\MTSProc]
GO
