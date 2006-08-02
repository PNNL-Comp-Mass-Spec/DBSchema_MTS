SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[SetPeptideProphetTaskState]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[SetPeptideProphetTaskState]
GO


CREATE PROCEDURE dbo.SetPeptideProphetTaskState
/****************************************************
**
**	Desc: Updates the state of the given Peptide Prophet Task
**		  If appropriate, updates the states of the jobs associated
**		  with the Peptide Prophet task
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	07/06/2006
**
*****************************************************/
(
	@TaskID int,
	@NextTaskState int,
	@NextProcessStateForJobs int = 94,			-- Only used if @NextTaskState is 3 or 6; typically 96 if @NextTaskState=3 and 94 if @NextTaskState=6
	@message varchar(512)='' output
)
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
		-- Peptide Prophet task Failed or problem occurred during loading
		-- Update the Task state to @NextTaskState, but only post an entry to the log if @NextTaskState = 6
		-- If @NextTaskState = 6, then update the associated jobs to state @NextProcessStateForJobs
		-- If @NextTaskState = 7, then do not update the associate job tasks since they should have
		--  already been updated on an individual basis by the calling procedure
		---------------------------------------------------

		UPDATE T_Peptide_Prophet_Task
		SET Processing_State = @NextTaskState, Task_Finish = GetDate()
		WHERE Task_ID = @TaskID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @NextProcessStateForJobs Is Null
			Set @NextProcessStateForJobs = 94

		If @NextTaskState = 6
		Begin
			Set @UpdateJobStates = 1

			Set @message = 'Peptide Prophet Task failed for Task_ID ' + @TaskIDStr
			Exec PostLogEntry 'Error', @message, 'SetPeptideProphetTaskState'
			Set @message = ''
		End
	End
	Else
	Begin
		---------------------------------------------------
		-- Peptide Prophet moving on to next state
		-- Update Task_Finish if the state is 3 = 'Results Ready' or 5 = 'Update Complete'
		---------------------------------------------------
		
		If @NextTaskState = 2
		Begin
			-- Update the state and the Start time
			UPDATE T_Peptide_Prophet_Task
			SET Processing_State = @NextTaskState, Task_Start = GetDate()
			WHERE Task_ID = @TaskID
		End
		Else
		Begin		
			-- Update the state and possibly the Finish time
			If @NextTaskState = 3 OR @NextTaskState = 4 OR @NextTaskState = 5
				UPDATE T_Peptide_Prophet_Task
				SET Processing_State = @NextTaskState, Task_Finish = GetDate()
				WHERE Task_ID = @TaskID
			Else
				UPDATE T_Peptide_Prophet_Task
				SET Processing_State = @NextTaskState
				WHERE Task_ID = @TaskID
		End
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @NextProcessStateForJobs Is Null
			Set @NextProcessStateForJobs = 96

		If @NextTaskState = 3
			Set @UpdateJobStates = 1
	End


	If @UpdateJobStates = 1
	Begin
		UPDATE T_Analysis_Description 
		SET Process_State = @NextProcessStateForJobs, Last_Affected = GETDATE()
		FROM T_Analysis_Description TAD INNER JOIN 
			 T_Peptide_Prophet_Task_Job_Map PPJM ON TAD.Job = PPJM.Job
		WHERE PPJM.Task_ID = @TaskID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	End
	
	if @myError <> 0
	Begin
		Set @message = 'Peptide Prophet Task generated error code ' + convert(varchar(19), @myError) + ' for Task_ID ' + @TaskIDStr
		Exec PostLogEntry 'Error', @message, 'SetPeptideProphetTaskState'
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

