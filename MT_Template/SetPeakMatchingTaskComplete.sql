/****** Object:  StoredProcedure [dbo].[SetPeakMatchingTaskComplete] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.SetPeakMatchingTaskComplete
/****************************************************
**
**	Desc:	Sets the state of a peak matching task to
**			3=Success or 4=Failure
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	grk
**	Date:	04/16/2003   
**			06/23/2003 mem
**			08/06/2003 mem
**			06/14/2006 mem - Expanded error handling and removed parameter @mtdbName
**			01/05/2008 mem - Now ignoring @errorCode and/or @warningCode if they are Null
**
*****************************************************/
(
	@taskID int,
	@errorCode int = 0,
	@warningCode int = 0,
	@MDID int = NULL,				-- MD_ID value in T_Match_Making_Description, if any
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

	declare @PMTaskText varchar(64)
	Set @PMTaskText = 'Peak matching task ' + Convert(varchar(19), @taskID)

	---------------------------------------------------
	-- Resolve task ID to state
	---------------------------------------------------
	--
	set @taskState = 0
	--
	SELECT @taskState = Processing_State
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
	-- Check task state for "in progress"
	---------------------------------------------------
	if @taskState <> 2
	begin
		set @myError = 51221
		set @message = 'State not correct for ' + @PMTaskText + '; state is ' + convert(varchar(12), @taskState) + ' but expecting state 2'
		goto done
	end

	---------------------------------------------------
	-- Update state 
	---------------------------------------------------
	
	if IsNull(@errorCode, 0) = 0
		set @taskState = 3 -- success
	else
		set @taskState = 4 -- failure

	UPDATE T_Peak_Matching_Task
	SET Processing_State = @taskState, 
		Processing_Error_Code = IsNull(@errorCode, Processing_Error_Code), 
		Processing_Warning_Code = IsNull(@warningCode, Processing_Warning_Code), 
		PM_Finish = GETDATE(),
		MD_ID = @MDID
	WHERE Task_ID = @taskID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 or @myRowCount <> 1
	begin
		set @message = 'Update operation failed for ' + @PMTaskText
		set @myError = 51222
		goto done
	end
	
	if IsNull(@errorCode, 0) <> 0
	Begin
		Set @message = @PMTaskText + ' generated error code ' + convert(varchar(19), @errorCode)
		Exec PostLogEntry 'Error', @message, 'SetPeakMatchingTaskComplete'
		Set @message = ''
	End
	
	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:

	If @myError <> 0
	Begin
		Exec PostLogEntry 'Error', @message, 'SetPeakMatchingTaskComplete', 4
	End

	return @myError


GO
GRANT EXECUTE ON [dbo].[SetPeakMatchingTaskComplete] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[SetPeakMatchingTaskComplete] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[SetPeakMatchingTaskComplete] TO [MTS_DB_Lite] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[SetPeakMatchingTaskComplete] TO [pnl\MTSProc] AS [dbo]
GO
