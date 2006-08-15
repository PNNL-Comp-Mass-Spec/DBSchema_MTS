/****** Object:  StoredProcedure [dbo].[ResetStalePeptideProphetTasks] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.ResetStalePeptideProphetTasks
/****************************************************
**
**	Desc: 
**		Looks for tasks in T_Peptide_Prophet_Task that have been
**		  been in state 1, 2, or 4 for over @maxHoursUnchangedState hours
**
**		Resets the jobs associated with those tasks to state 90, provided
**		the jobs are in state 91 to 99 and are not part of a newer Peptide Prophet 
**		Calculation task that is in state 3, 4, or 5
**
**	Auth:	mem
**	Date:	07/03/2006
**
*****************************************************/
(
	@maxHoursUnchangedState real = 12,
	@ProcessStateReadyForPeptideProphetCalc smallint = 90,
	@LogErrors tinyint = 1					-- Set to 0 to not log errors and instead report them to the console
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	declare @message varchar(255)
	declare @CurrentTime datetime
	Set @CurrentTime = GETDATE()

	---------------------------------------------------
	-- Look for tasks that are stuck in state 1, 2, or 4 and for which Task_Start
	-- is more than 12 hours ago
	---------------------------------------------------
	
	-- First reset the jobs associated with any timed out or failed Peptide Prophet Calculation Tasks
	-- Note that this Update query and the following update query both use @CurrentTime
	-- Also note that this update query checks for jobs that are associated with a newer Peptide Prophet task
	-- that has completed successfully or is loading results
	UPDATE T_Analysis_Description
	SET Process_State = @ProcessStateReadyForPeptideProphetCalc, Last_Affected = GetDate()
	FROM T_Analysis_Description TAD INNER JOIN
		  (	SELECT PPT.Task_ID, PPJM.Job
			FROM T_Peptide_Prophet_Task PPT INNER JOIN
				T_Peptide_Prophet_Task_Job_Map PPJM ON PPT.Task_ID = PPJM.Task_ID INNER JOIN
				T_Analysis_Description TAD ON PPJM.Job = TAD.Job
			WHERE (TAD.Process_State BETWEEN 91 AND 99) AND 
				( (PPT.Processing_State IN (1, 2) AND 
				   DATEDIFF(Minute, ISNULL(PPT.Task_Start, PPT.Task_Created), @CurrentTime) > @maxHoursUnchangedState * 60)
				  OR
				  (PPT.Processing_State IN (4) AND 
				   DATEDIFF(Minute, ISNULL(PPT.Task_Finish, PPT.Task_Created), @CurrentTime) > @maxHoursUnchangedState * 60)
				)
		  )	TimeoutQ ON 
		    TimeoutQ.Job = TAD.Job LEFT OUTER JOIN
		  (	SELECT PPT.Task_ID, PPJM.Job
			FROM T_Peptide_Prophet_Task PPT INNER JOIN
				 T_Peptide_Prophet_Task_Job_Map PPJM ON PPT.Task_ID = PPJM.Task_ID
			WHERE PPT.Processing_State IN (3, 4, 5)
		  ) SuccessQ ON 
			TimeoutQ.Task_ID < SuccessQ.Task_ID AND TimeoutQ.Job = SuccessQ.Job
	WHERE (SuccessQ.Job IS NULL)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	If @myRowCount > 0
	Begin
		Set @message = 'Jobs that are associated with a stale Peptide Prophet Calculation task and have been in state 91 to 99 for over ' + Convert(varchar(11), @maxHoursUnchangedState) + ' hours were reset to state ' + Convert(varchar(11), @ProcessStateReadyForPeptideProphetCalc) + '; ' + Convert(varchar(11), @myRowCount) + ' jobs updated'
		If IsNull(@LogErrors, 1) <> 0
			Exec PostLogEntry 'Error', @message, 'ResetStalePeptideProphetTasks'
		Else
			SELECT @message AS ErrorMessage
	End

	-- Now look for Peptide Prophet Calculation Tasks that need to be set to state 6='Update Failed'
	-- Do not log anything if failed tasks are found, since we will have already logged the error for the failed jobs
	UPDATE T_Peptide_Prophet_Task
	SET Processing_State = 6
	WHERE (Processing_State IN (1, 2) AND 
		   DATEDIFF(Minute, ISNULL(Task_Start, Task_Created), @CurrentTime) > @maxHoursUnchangedState * 60)
		  OR
		  (Processing_State IN (4) AND 
		   DATEDIFF(Minute, ISNULL(Task_Finish, Task_Created), @CurrentTime) > @maxHoursUnchangedState * 60)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	return @myError


GO
