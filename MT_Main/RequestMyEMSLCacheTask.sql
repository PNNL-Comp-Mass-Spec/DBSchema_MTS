/****** Object:  StoredProcedure [dbo].[RequestMyEMSLCacheTask] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE RequestMyEMSLCacheTask
/****************************************************
**
**	Desc:	Requests a task to cache files for a given dataset
**
**	Auth:	mem
**	Date:	12/09/2013 mem - Initial Version
**
*****************************************************/
(
	@processorName varchar(128),
	@taskAvailable tinyint = 0 output,				-- 1 if a task is available; otherwise 0,	
	@taskID int = 0 output,
	@message varchar(512) = '' output
)
As
	set nocount on

	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	---------------------------------------------------
	-- Clear the output arguments
	---------------------------------------------------

	Set @taskAvailable = 0
	Set @taskID = 0
		
	Declare @UpdateEnabled tinyint
	
	-- Validate that Peptide DB updating is enabled
	exec VerifyUpdateEnabled 'Peptide_DB_Update', 'RequestMyEMSLCacheTask', @AllowPausing = 0, @PostLogEntryIfDisabled = 0, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
	Begin
		-- Nothing to do
		Goto done
	End
	
	
	Declare @RequestTask varchar(24) = 'RequestTask'
	Begin Tran @RequestTask
	
	---------------------------------------------------
	-- Look for files that need to be cached
	-- Limit to the files for one dataset
	---------------------------------------------------
	--
	Declare @DatasetID int
	Declare @ResultsFolderName varchar(128)
	
	SELECT TOP 1 @DatasetID = CachePaths.Dataset_ID,
	             @ResultsFolderName = CachePaths.Results_Folder_Name
	FROM T_MyEMSL_Cache_Paths CachePaths
	     INNER JOIN T_MyEMSL_FileCache FileCache
	       ON CachePaths.Cache_PathID = FileCache.Cache_PathID
	WHERE FileCache.State = 1
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	If @myRowCount > 0
	Begin
		-- Create a new task
		--
		INSERT INTO T_MyEMSL_Cache_Task (Processor, Task_State, Task_Start)
		VALUES (@processorName, 2, GetDate())
		--
		
		If @@error <> 0
		Begin
			SELECT @myError = @@error
			
			Rollback tran @RequestTask
			Set @message = 'Error inserting row into T_MyEMSL_Cache_Task, errorCode ' + Convert(varchar(12), @myError)
			Goto Done
		End

		Set @taskID = SCOPE_IDENTITY()

		-- Update the files that need to be cached for this dataset and result folder
		--
		UPDATE T_MyEMSL_FileCache
		SET State = 2,
		    Task_ID = @taskID
		FROM T_MyEMSL_Cache_Paths CachePaths
		     INNER JOIN T_MyEMSL_FileCache FileCache
		       ON CachePaths.Cache_PathID = FileCache.Cache_PathID
		WHERE FileCache.State = 1 AND
		      CachePaths.Dataset_ID = @DatasetID AND
		      CachePaths.Results_Folder_Name = @ResultsFolderName
		
		Set @message = 'Assigned task ' + Convert(varchar(12), @taskID)
		
		Set @taskAvailable = 1
	End
		
	Commit Tran @RequestTask
	
	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:

	Set @message = IsNull(@message, '')
	
	If @myError <> 0
	Begin
		If @message = ''
			Set @message = 'Unknown error, code ' + Convert(varchar(12), @myError)
			
		Exec PostLogEntry 'Error', @message, 'RequestMyEMSLCacheTask'
	End
	
	Return @myError

GO
