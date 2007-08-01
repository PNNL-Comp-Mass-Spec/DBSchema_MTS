/****** Object:  StoredProcedure [dbo].[RequestGANETUpdateTask] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.RequestGANETUpdateTask
/****************************************************
**
**	Desc: 
**		Looks for a task in T_GANET_Update_Task with a
**      Processing_State value = 1
**      If found, task is assigned to caller, 
**      @TaskAvailable is set to 1, and the task 
**      information is returned in the output arguments
**      If not found or error, then @message will contain
**      explanatory text.
**
**		Auth: grk
**		Date: 08/26/2003
**			  04/08/2004 mem - Removed references to T_GANET_Update_Parameters
**			  04/09/2004 mem - Removed @maxIterations and @maxHours parameters
**			  09/23/2004 mem - Now checking for tasks stuck in states 2 or 7
**			  04/11/2005 mem - Removed checking for stuck tasks since this is now accomplished with CheckStaleTasks, which is called during Master Update
**
*****************************************************/
	@processorName varchar(128),
	@taskID int output,
	@taskAvailable tinyint output,
	@message varchar(512) output
As
	set nocount on

	declare @myError int
	set @myError = 0

	declare @myRowCount int
	set @myRowCount = 0
	
	set @message = ''
		
	---------------------------------------------------
	-- clear the output arguments
	---------------------------------------------------
	set @taskID = 0
	set @TaskAvailable = 0
	set @message = ''
	
	---------------------------------------------------
	-- Start transaction
	---------------------------------------------------
	--
	declare @transName varchar(32)
	set @transName = 'RequestGANETUpateTask'
	begin transaction @transName

	---------------------------------------------------
	-- find a task matching the input request
	-- only grab the taskID at this time
	---------------------------------------------------

	SELECT TOP 1 
		@taskID = Task_ID
	FROM T_GANET_Update_Task WITH (HoldLock)
	WHERE Processing_State = 1
	ORDER BY Task_ID DESC
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		rollback transaction @transName
		set @message = 'Error trying to find viable record'
		goto done
	end
	
	---------------------------------------------------
	-- bail if no task found
	---------------------------------------------------

	if @taskID = 0
	begin
		rollback transaction @transName
		set @message = 'Could not find viable record'
		goto done
	end


	---------------------------------------------------
	-- set state and path for task
	---------------------------------------------------

	UPDATE T_GANET_Update_Task
	SET 
		Processing_State = 2, 
		Task_Start = GETDATE(),
		Task_AssignedProcessorName = @ProcessorName
	WHERE (Task_ID = @taskID)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		rollback transaction @transName
		set @message = 'Update operation failed'
		goto done
	end
	
	---------------------------------------------------
	-- commit transaction
	---------------------------------------------------
	commit transaction @transName

	---------------------------------------------------
	-- If we get to this point, then all went fine
	-- Update TaskAvailable
	---------------------------------------------------
	Set @TaskAvailable = 1

	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	return @myError


GO
