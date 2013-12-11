/****** Object:  StoredProcedure [dbo].[SetMyEMSLCacheTaskComplete] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create PROCEDURE SetMyEMSLCacheTaskComplete
/****************************************************
**
**	Desc:	Sets a MyEMSL task as complete or failed
**
**	Auth:	mem
**	Date:	12/09/2013 mem - Initial Version
**
*****************************************************/
(
	@processorName varchar(128),
	@taskID int,
	@CompletionCode int,
	@CompletionMessage varchar(255),
	@message varchar(512) = '' output
)
As
	set nocount on

	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	---------------------------------------------------
	-- Validate the task info
	---------------------------------------------------
	--
	Declare @TaskState tinyint
	
	SELECT @TaskState = Task_State
	FROM T_MyEMSL_Cache_Task 
	WHERE Task_ID = @taskID
	--	
	SELECT @myError = @@error, @myRowCount = @@rowcount

	If @myRowCount = 0
	Begin
		Set @message = 'Task ' + Convert(varchar(12), @taskID) + ' not found in T_MyEMSL_Cache_Task for processor ' + @processorName
		Set @myError = 52000
		Goto Done
	End
	
	If @TaskState <> 2
	Begin
		Set @message = 'Task ' + Convert(varchar(12), @taskID) + ' has state ' + Convert(varchar(8), @TaskState) + '; cannot set task complete for processor ' + @processorName
		Set @myError = 52001
		Goto Done
	End
	
	Declare @UpdateTran varchar(24) = 'SetTaskComplete'
	Begin Tran @UpdateTran
	
	Declare @NewTaskState tinyint = 3
	
	If @CompletionCode <> 0
		Set @NewTaskState = 4
	                 
	---------------------------------------------------
	-- Set the task complete
	---------------------------------------------------
	--
	UPDATE T_MyEMSL_Cache_Task
	SET Task_State = @NewTaskState,
	    Task_Complete = GetDate(),
	    Completion_Code = @CompletionCode,
	    Completion_Message = @CompletionMessage
	WHERE Task_ID = @TaskID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	UPDATE T_MyEMSL_FileCache
	SET State = @NewTaskState
	WHERE Task_ID = @TaskID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

		
	Commit Tran @UpdateTran
	
	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:

	If @myError <> 0
		Exec PostLogEntry 'Error', @message, 'SetMyEMSLCacheTaskComplete'
		
		
	Return @myError

GO
