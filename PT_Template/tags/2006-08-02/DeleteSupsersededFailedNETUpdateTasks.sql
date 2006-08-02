SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[DeleteSupsersededFailedNETUpdateTasks]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[DeleteSupsersededFailedNETUpdateTasks]
GO


CREATE Procedure dbo.DeleteSupsersededFailedNETUpdateTasks
/****************************************************
**
**	Desc: 
**		Looks for NET update tasks that are failed, but
**		for which all of the mapped analysis jobs are in state 70
**
**	Parameters:
**
**		Auth:	mem
**		Date:	06/10/2005
**
*****************************************************/
(
	@message varchar(255) = '' output
)
AS
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	set @message = ''

	declare @MatchCount int
	
	-----------------------------------------------
	-- First delete entries from T_NET_Update_Task_Job_Map that
	-- are associated with a failed NET update task for which
	-- all of the associated jobs are in state 70
	-----------------------------------------------
	--
	DELETE FROM T_NET_Update_Task_Job_Map
	WHERE Task_ID IN (
				SELECT T_NET_Update_Task.Task_ID
				FROM T_NET_Update_Task INNER JOIN
					T_NET_Update_Task_Job_Map ON 
					T_NET_Update_Task.Task_ID = T_NET_Update_Task_Job_Map.Task_ID
					INNER JOIN
					T_Analysis_Description ON 
					T_NET_Update_Task_Job_Map.Job = T_Analysis_Description.Job
				WHERE (T_NET_Update_Task.Processing_State = 6)
				GROUP BY T_NET_Update_Task.Task_ID
				HAVING MIN(T_Analysis_Description.Process_State) = 70 AND MAX(T_Analysis_Description.Process_State) = 70
			)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Error deleting entries from T_NET_Update_Task_Job_Map for failed NET update tasks'
		set @myError = 51000
		goto Done
	end

	-----------------------------------------------
	-- Count the number of failed NET update tasks that
	-- now have no entries in T_NET_Update_Task_Job_Map
	-----------------------------------------------
	Set @MatchCount = 0
	SELECT @MatchCount = COUNT(T_NET_Update_Task.Task_ID)
	FROM T_NET_Update_Task LEFT OUTER JOIN
		T_NET_Update_Task_Job_Map ON 
		T_NET_Update_Task.Task_ID = T_NET_Update_Task_Job_Map.Task_ID
	WHERE T_NET_Update_Task.Processing_State = 6
	GROUP BY T_NET_Update_Task.Task_ID
	HAVING COUNT(T_NET_Update_Task_Job_Map.Job) = 0


	If @MatchCount > 0
	Begin
		-----------------------------------------------
		-- Now delete the failed NET update tasks
		-----------------------------------------------
		--
		DELETE FROM T_NET_Update_Task
		WHERE Task_ID IN (
					SELECT T_NET_Update_Task.Task_ID
					FROM T_NET_Update_Task LEFT OUTER JOIN
						T_NET_Update_Task_Job_Map ON 
						T_NET_Update_Task.Task_ID = T_NET_Update_Task_Job_Map.Task_ID
					WHERE T_NET_Update_Task.Processing_State = 6
					GROUP BY T_NET_Update_Task.Task_ID
					HAVING COUNT(T_NET_Update_Task_Job_Map.Job) = 0
				)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0
		begin
			set @message = 'Error deleting failed NET update tasks from T_NET_Update_Task'
			set @myError = 51000
			goto Done
		end
		
		Set @message = 'Deleted failed NET update tasks from T_NET_Update_Task; only deleted if all jobs are in state 70; number deleted = ' + convert(varchar(12), @MatchCount)
		
		Exec PostLogEntry 'normal', @message, 'DeleteSupsersededFailedNETUpdateTasks'
	End
	Else
		Set @message = 'No NET update tasks were found to delete'

	-----------------------------------------------
	-- Exit
	-----------------------------------------------
Done:	
	print @message
	
	return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

