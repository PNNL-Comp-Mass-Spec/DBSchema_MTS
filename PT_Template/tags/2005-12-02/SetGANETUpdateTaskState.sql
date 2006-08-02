SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[SetGANETUpdateTaskState]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[SetGANETUpdateTaskState]
GO


CREATE PROCEDURE dbo.SetGANETUpdateTaskState
/****************************************************
**
**	Desc: Updates the state of the given NET Update Task
**		  If appropriate, updates the states of the jobs associated
**		  with the NET update task
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**		Auth: mem
**		Date:	05/30/2005
**				10/27/2005 mem - Now updating Task_Finish for state 4 in addition to states 3 and 5
**
*****************************************************/
	@TaskID int,
	@NextTaskState int,
	@NextProcessStateForJobs int = 44,			-- Only used if @NextTaskState is 5, 6, or 7; typically 50 if @NextTaskState is 5; otherwise typically 44
	@message varchar(512)='' output
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	set @message = ''

	declare @TaskIDStr as varchar(11)
	set @TaskIDStr = convert(varchar(11), @TaskID)

	declare @UpdateJobStates tinyint
	Set @UpdateJobStates = 0

	
	If @NextTaskState = 6 or @NextTaskState = 7
	Begin
		---------------------------------------------------
		-- NET Update Failed
		-- Post an entry to the log, update the Task state to @NextTaskState,
		-- and update the Associated jobs to state 44
		---------------------------------------------------

		UPDATE T_NET_Update_Task
		SET Processing_State = @NextTaskState, Task_Finish = GetDate()
		WHERE Task_ID = @TaskID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		Set @UpdateJobStates = 1
		Set @NextProcessStateForJobs = 44
		
		Set @message = 'NET update failed for Task_ID ' + @TaskIDStr
		Exec PostLogEntry 'Error', @message, 'SetGANETUpdateTaskState'
		Set @message = ''
	End
	Else
	Begin
		---------------------------------------------------
		-- NET Update moving on to next state
		-- Update Task_Finish if the state is 3 = 'Results Ready' or 5 = 'Update Complete'
		---------------------------------------------------
		
		If @NextTaskState = 2
		Begin
			-- Update the state and the Start time
			UPDATE T_NET_Update_Task
			SET Processing_State = @NextTaskState, Task_Start = GetDate()
			WHERE Task_ID = @TaskID
		End
		Else
		Begin		
			-- Update the state and possibly the Finish time
			If @NextTaskState = 3 OR @NextTaskState = 4 OR @NextTaskState = 5
				UPDATE T_NET_Update_Task
				SET Processing_State = @NextTaskState, Task_Finish = GetDate()
				WHERE Task_ID = @TaskID
			Else
				UPDATE T_NET_Update_Task
				SET Processing_State = @NextTaskState
				WHERE Task_ID = @TaskID
		End
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @NextTaskState = 3 OR @NextTaskstate = 5
			Set @UpdateJobStates = 1
	End
	

	If @UpdateJobStates = 1
	Begin
		If @NextProcessStateForJobs Is Null
			Set @NextProcessStateForJobs = 44
			
		UPDATE T_Analysis_Description 
		SET Process_State = @NextProcessStateForJobs, Last_Affected = GETDATE()
		FROM T_Analysis_Description INNER JOIN T_NET_Update_Task_Job_Map ON
			T_Analysis_Description.Job = T_NET_Update_Task_Job_Map.Job
		WHERE T_NET_Update_Task_Job_Map.Task_ID = @TaskID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	End
	
	if @myError <> 0
	Begin
		Set @message = 'NET update generated error code ' + convert(varchar(19), @myError) + ' for Task_ID ' + @TaskIDStr
		Exec PostLogEntry 'Error', @message, 'SetGANETUpdateTaskState'
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

