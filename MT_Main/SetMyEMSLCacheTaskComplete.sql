/****** Object:  StoredProcedure [dbo].[SetMyEMSLCacheTaskComplete] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE SetMyEMSLCacheTaskComplete
/****************************************************
**
**	Desc:	Sets a MyEMSL task as complete or failed
**
**	Auth:	mem
**	Date:	12/09/2013 mem - Initial Version
**			12/11/2013 mem - Added @CachedFileIDs
**			12/12/2013 mem - Added support for Optional files
**
*****************************************************/
(
	@processorName varchar(128),
	@taskID int,
	@CompletionCode int,
	@CompletionMessage varchar(255),
	@CachedFileIDs varchar(max),			-- Comma-separated list of the Entry_ID values for the files that were successfully cached
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


	---------------------------------------------------
	-- Populate a temporary table with the IDs in @EntryIDsCached
	---------------------------------------------------
	
	CREATE TABLE #Tmp_CachedFileIDs (
		Entry_ID int NOT NULL
	)
	
	INSERT INTO #Tmp_CachedFileIDs (Entry_ID)
	SELECT Value
	FROM dbo.udfParseDelimitedIntegerList(@CachedFileIDs, ',')
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	---------------------------------------------------
	-- Start a transaction
	---------------------------------------------------
	
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
	SET State = 3
	WHERE Task_ID = @TaskID AND Entry_ID IN (Select Entry_ID FROM #Tmp_CachedFileIDs)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	UPDATE T_MyEMSL_FileCache
	SET State = CASE
	                WHEN Optional = 0 THEN 4	-- Failed
	                ELSE 6						-- Skipped
	            END
	WHERE Task_ID = @TaskID AND
	      NOT Entry_ID IN ( SELECT Entry_ID
	                        FROM #Tmp_CachedFileIDs )
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
GRANT VIEW DEFINITION ON [dbo].[SetMyEMSLCacheTaskComplete] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[SetMyEMSLCacheTaskComplete] TO [MTS_DB_Lite] AS [dbo]
GO
