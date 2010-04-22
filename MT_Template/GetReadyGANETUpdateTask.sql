/****** Object:  StoredProcedure [dbo].[GetReadyGANETUpdateTask] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.GetReadyGANETUpdateTask

/****************************************************
**
**	Desc: 
**		Looks for a task in T_GANET_Update_Task with a
**    Processing_State value = 3 (results ready).
**		If found, taskID is returned non-zero.
**
**		Auth: grk
**		Date: 8/28/2003
**			  11/26/2003 grk -- added GANET task state 7
**
*****************************************************/
	@taskID int output,
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
	set @message = ''
	

	---------------------------------------------------
	-- find a task matching the input request
	-- only grab the taskID at this time
	---------------------------------------------------

	SELECT TOP 1 
		@taskID = Task_ID
	FROM T_GANET_Update_Task WITH (HoldLock)
	WHERE Processing_State = 3
	ORDER BY Task_ID DESC
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Error trying to find viable record'
		goto done
	end
	
	---------------------------------------------------
	-- bail if no task found
	---------------------------------------------------

	if @taskID = 0
	begin
		set @message = 'Could not find viable record'
		goto done
	end

	---------------------------------------------------
	-- set state for task
	---------------------------------------------------

	exec @myError = SetGANETUpdateTaskComplete @taskID, 0, @message output
	--
	SELECT @myError = @@error
	--
	if @myError <> 0
	begin
		goto done
	end

	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[GetReadyGANETUpdateTask] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetReadyGANETUpdateTask] TO [MTS_DB_Lite] AS [dbo]
GO
