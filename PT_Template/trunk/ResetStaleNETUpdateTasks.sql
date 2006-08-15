/****** Object:  StoredProcedure [dbo].[ResetStaleNETUpdateTasks] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.ResetStaleNETUpdateTasks
/****************************************************
**
**	Desc: 
**		Looks for NET Update tasks in T_NET_Update_Task
**		that have been in state 1, 2, or 4 for over @maxHoursUnchangedState hours
**
**		Resets the jobs associated with those tasks to state 40, provided
**		the jobs are in state 41 to 49 and are not part of a newer NET Update task
**		that is in state 3, 4, or 5
**
**		Auth:	mem
**		Date:	05/30/2005
**				10/27/2005 mem - Now checking for stale NET tasks in state 4 in addition to states 1 and 2
**
*****************************************************/
(
	@maxHoursUnchangedState real = 12,
	@ProcessStateReadyForNETRegression smallint = 40,
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
	-- Look for tasks that are stuck in state 2 and for which Task_Start
	-- is more than 12 hours ago
	---------------------------------------------------
	
	-- First reset the jobs associated with any timed out or failed NET Update Tasks
	-- Note that this Update query and the following update query both use @CurrentTime
	-- Also note that this update query checks for jobs that are associated with a newer NET Update task
	-- that has completed successfully or is loading results
	UPDATE T_Analysis_Description
	SET Process_State = @ProcessStateReadyForNETRegression, Last_Affected = GetDate()
	FROM T_Analysis_Description TAD INNER JOIN
		  (	SELECT UT.Task_ID, TJM.Job
			FROM T_NET_Update_Task UT INNER JOIN
				T_NET_Update_Task_Job_Map TJM ON UT.Task_ID = TJM.Task_ID INNER JOIN
				T_Analysis_Description TAD ON TJM.Job = TAD.Job
			WHERE (TAD.Process_State BETWEEN 41 AND 49) AND 
				( (UT.Processing_State IN (1, 2) AND 
				   DATEDIFF(Minute, ISNULL(UT.Task_Start, UT.Task_Created), @CurrentTime) > @maxHoursUnchangedState * 60)
				  OR
				  (UT.Processing_State IN (4) AND 
				   DATEDIFF(Minute, ISNULL(UT.Task_Finish, UT.Task_Created), @CurrentTime) > @maxHoursUnchangedState * 60)
				)
		  )	TimeoutQ ON 
		    TimeoutQ.Job = TAD.Job LEFT OUTER JOIN
		  (	SELECT UT.Task_ID, TJM.Job
			FROM T_NET_Update_Task UT INNER JOIN
				 T_NET_Update_Task_Job_Map TJM ON UT.Task_ID = TJM.Task_ID
			WHERE UT.Processing_State IN (3, 4, 5)
		  ) SuccessQ ON 
			TimeoutQ.Task_ID < SuccessQ.Task_ID AND TimeoutQ.Job = SuccessQ.Job
	WHERE (SuccessQ.Job IS NULL)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	If @myRowCount > 0
	Begin
		Set @message = 'Jobs that are associated with a stale NET update task and have been in state 41 to 49 for over ' + Convert(varchar(11), @maxHoursUnchangedState) + ' hours were reset to state ' + Convert(varchar(11), @ProcessStateReadyForNETRegression) + '; ' + Convert(varchar(11), @myRowCount) + ' jobs updated'
		If IsNull(@LogErrors, 1) <> 0
			Exec PostLogEntry 'Error', @message, 'ResetStaleNETUpdateTasks'
		Else
			SELECT @message AS ErrorMessage
	End

	-- Now look for NET Update Tasks that need to be set to state 6='Update Failed'
	-- Do not log anything if failed tasks are found, since we will have already logged the error for the failed jobs
	UPDATE T_NET_Update_Task
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
