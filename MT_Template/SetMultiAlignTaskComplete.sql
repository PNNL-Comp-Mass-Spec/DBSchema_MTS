/****** Object:  StoredProcedure [dbo].[SetMultiAlignTaskComplete] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.SetMultiAlignTaskComplete
/****************************************************
**
**	Desc:	Sets the state of a MultiAlign task to
**			3=Success or 4=Failure
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	01/05/2008
**
*****************************************************/
(
	@taskID int,
	@errorCode int = 0,
	@warningCode int = 0,
	@AnalysisResultsID int = NULL,				-- Reserved for future use
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

	declare @TaskText varchar(64)
	Set @TaskText = 'MultiAlign task ' + Convert(varchar(19), @taskID)

	---------------------------------------------------
	-- Resolve task ID to state
	---------------------------------------------------
	--
	set @taskState = 0
	--
	SELECT @taskState = Processing_State
	FROM T_MultiAlign_Task
	WHERE Task_ID = @taskID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 or @myRowCount <> 1
	begin
		set @myError = 51220
		set @message = 'Could not get information for ' + @TaskText
		goto done
	end

	---------------------------------------------------
	-- Check task state for "in progress"
	---------------------------------------------------
	if @taskState <> 2
	begin
		set @myError = 51221
		set @message = 'State not correct for ' + @TaskText + '; state is ' + convert(varchar(12), @taskState) + ' but expecting state 2'
		goto done
	end

	---------------------------------------------------
	-- Update state 
	---------------------------------------------------
	
	if IsNull(@errorCode, 0) = 0
		set @taskState = 3 -- success
	else
		set @taskState = 4 -- failure

	UPDATE T_MultiAlign_Task
	SET Processing_State = @taskState, 
		Processing_Error_Code = IsNull(@errorCode, Processing_Error_Code),
		Processing_Warning_Code = IsNull(@warningCode, Processing_Warning_Code),
		Task_Finish = GETDATE(),
		Analysis_Results_ID = @AnalysisResultsID
	WHERE Task_ID = @taskID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 or @myRowCount <> 1
	begin
		set @message = 'Update operation failed for ' + @TaskText
		set @myError = 51222
		goto done
	end
	
	if IsNull(@errorCode, 0) <> 0
	Begin
		Set @message = @TaskText + ' generated error code ' + convert(varchar(19), @errorCode)
		Exec PostLogEntry 'Error', @message, 'SetMultiAlignTaskComplete'
		Set @message = ''
	End
	
	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:

	If @myError <> 0
	Begin
		Exec PostLogEntry 'Error', @message, 'SetMultiAlignTaskComplete', 4
	End

	return @myError


GO
GRANT EXECUTE ON [dbo].[SetMultiAlignTaskComplete] TO [DMS_SP_User]
GO
GRANT VIEW DEFINITION ON [dbo].[SetMultiAlignTaskComplete] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[SetMultiAlignTaskComplete] TO [MTS_DB_Lite]
GO
GRANT EXECUTE ON [dbo].[SetMultiAlignTaskComplete] TO [pnl\MTSProc]
GO
