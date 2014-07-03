/****** Object:  StoredProcedure [dbo].[SetGANETUpdateTaskState] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.SetGANETUpdateTaskState
/****************************************************
**
**	Desc: 
**		Updates the state of the given NET Update Task
**		If appropriate, updates the states of the jobs associated with the NET update task
**
**		The calling procedure must create table #Tmp_NET_Update_Jobs
**		The table does not have to be populated; jobs associated with 
**		  NET update task @TaskID that are not in #Tmp_NET_Update_Jobs will still get processed
**
**			CREATE TABLE #Tmp_NET_Update_Jobs (
**				Job int not null,
**				RegressionInfoLoaded tinyint not null,
**				ObservedNETsLoaded tinyint not null
**			)
**
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**		Auth: mem
**		Date:	05/30/2005
**				10/27/2005 mem - Now updating Task_Finish for state 4 in addition to states 3 and 5
**				03/25/2013 mem - Now examining temporary table #Tmp_NET_Update_Jobs when updating job states
**
*****************************************************/
(
	@TaskID int,
	@NextTaskState int,
	@NextProcessStateForJobs int = 44,			-- Only used if @NextTaskState is 5, 6, or 7; typically 50 if @NextTaskState is 5; otherwise typically 44
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

	declare @UpdateJobStates tinyint = 0

	
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
		-- Update Task_Finish if the state is 3 ('Results Ready') or 5 ('Update Complete')
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
			If @NextTaskState IN (3, 4, 5)
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
		Set @NextProcessStateForJobs = IsNull(@NextProcessStateForJobs, 44)
		
		DECLARE @tblNewJobStates table (
			Job int not null,
			State int not null
		)
		
		-- Add jobs that did not successfully complete regression
		--
		INSERT INTO @tblNewJobStates (Job, State)
		SELECT Job,
		       44 AS State
		FROM #Tmp_NET_Update_Jobs
		WHERE RegressionInfoLoaded = 0 OR
		      ObservedNETsLoaded = 0
		
		-- Add jobs that either did complete regression, or are not in #Tmp_NET_Update_Jobs
		--
		INSERT INTO @tblNewJobStates (Job, State)
		SELECT JM.Job,
		       @NextProcessStateForJobs AS State
		FROM T_Analysis_Description TAD
		     INNER JOIN T_NET_Update_Task_Job_Map JM
		       ON TAD.Job = JM.Job
		     LEFT OUTER JOIN @tblNewJobStates Target
		       ON JM.Job = Target.Job
		WHERE JM.Task_ID = @TaskID AND
		      Target.Job IS NULL
		
		-- Update the job states
		-- Increment Regression_Failure_Count for any failed jbos
		UPDATE T_Analysis_Description
		SET Process_State = Src.State,
		    Regression_Failure_Count = Regression_Failure_Count + CASE WHEN Src.State = 44 THEN 1 ELSE 0 END,
		    Last_Affected = GETDATE()
		FROM T_Analysis_Description TAD
		     INNER JOIN @tblNewJobStates Src
		       ON TAD.Job = Src.Job
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
GRANT VIEW DEFINITION ON [dbo].[SetGANETUpdateTaskState] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[SetGANETUpdateTaskState] TO [MTS_DB_Lite] AS [dbo]
GO
