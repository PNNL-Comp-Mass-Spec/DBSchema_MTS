SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[SetPeakMatchingTaskComplete]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[SetPeakMatchingTaskComplete]
GO



CREATE Procedure dbo.SetPeakMatchingTaskComplete
/****************************************************
**
**	Desc: 
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**		Auth: grk
**		Date: 4/16/2003   
**
**		Updated: 6/23/2003 by mem
**				 8/06/2003 by mem
**
*****************************************************/
	@taskID int,
	@mtdbName varchar (128),
	@errorCode int = 0,
	@warningCode int = 0,
	@MDID int = NULL,				-- MD_ID value in T_Match_Making_Description, if any
	@message varchar(512) output
As
	set nocount on

	declare @myError int
	set @myError = 0

	declare @myRowCount int
	set @myRowCount = 0
	
	set @message = ''

	declare @taskState int

	---------------------------------------------------
	-- resolve task ID to state
	---------------------------------------------------
	--
	set @taskState = 0
	--
	SELECT @taskState = Processing_State
	FROM T_Peak_Matching_Task
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
	-- check task state for "in progress"
	---------------------------------------------------
	if @taskState <> 2
	begin
		set @myError = 51250
		set @message = 'State not correct'
		goto done
	end

	---------------------------------------------------
	-- Update state 
	---------------------------------------------------
	
	if @errorCode = 0
			set @taskState = 3 -- success
	else
			set @taskState = 4 -- failure

	UPDATE T_Peak_Matching_Task
	SET 
		Processing_State = @taskState, 
		Processing_Error_Code = @errorCode, 
		Processing_Warning_Code = @warningCode, 
		PM_Finish = GETDATE(),
		MD_ID = @MDID
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
	
	if @errorCode <> 0
	Begin
		Set @message = 'Peak matching task ' + convert(varchar(19), @taskID) + ' generated error code ' + convert(varchar(19), @errorCode)
		Exec PostLogEntry 'Error', @message, 'PeakMatching'
		Set @message = ''
	End
	
	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	return @myError




GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[SetPeakMatchingTaskComplete]  TO [DMS_SP_User]
GO

