/****** Object:  StoredProcedure [dbo].[CacheMyEMSLFile] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure CacheMyEMSLFile
/****************************************************
**
**	Desc: 
**		Queues a file for caching from MyEMSL
**		Will either add the file to T_MyEMSL_FileCache or update the state to 1 if purged
**		If the file is in the table and in state 2, but Cache_Start is over 2 hours old, then the state will get changed back to 1
**		If the file is in the table and in state 3, then sets @Available to 1
**
**	Return values: 0 if no error; otherwise error code
**
**	Auth:	mem
**	Date:	10/11/2013 mem - Initial version
**			12/09/2013 mem - Now setting @CacheState to 4 (error) if the file is in the download queue for over 48 hours
**    
*****************************************************/
(
	@Job int,
	@Filename varchar(255),				-- Use * for "all files"
	@CacheState tinyint=0 OUTPUT,		-- Cache state
	@Available tinyint=0 OUTPUT,		-- Will be set to 1 if the file has been successfully cached and is now ready for use
	@LocalCacheFolderPath varchar(255) output,		-- Local path to which the files will be cached; does not include the dataset name or results folder name
	@LocalResultsFolderPath varchar(512) output,	-- Local path to the folder with the actual cached files
	@message varchar(255)='' OUTPUT
)
AS

	set nocount on

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	---------------------------------------------------
	-- Validate the inputs
	---------------------------------------------------

	Set @Job = IsNull(@Job, 0)
	Set @Filename = IsNull(@Filename, '')
	Set @CacheState = 0
	Set @Available = 0
	Set @LocalCacheFolderPath = ''
	Set @LocalResultsFolderPath = ''	
	Set @message = ''

	---------------------------------------------------
	-- Make sure the job is valid and that the job does exist in MyEMSL
	---------------------------------------------------

	Declare @MyEMSLState tinyint = 0
	Declare @DatasetStoragePath varchar(255)
	Declare @DatasetID int
	Declare @DatasetFolder varchar(128)
	Declare @ResultsFolder varchar(128)
	
	SELECT @MyEMSLState = MyEMSLState,
	       @DatasetID = DatasetID,
	       @DatasetStoragePath = StoragePathServer,
	       @DatasetFolder = DatasetFolder,
	       @ResultsFolder = ResultsFolder
	FROM T_DMS_Analysis_Job_Info_Cached 
	WHERE Job = @Job	
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	If @myRowCount = 0
	Begin
		Set @message = 'Job ' + Convert(varchar(12), @Job) + ' not found in T_DMS_Analysis_Job_Info_Cached'
		Exec PostLogEntry 'Error', @message, 'CacheMyEMSLFile', @duplicateEntryHoldoffHours=1
		Set @myerror = 5000
		Goto Done
	End
	
	If IsNull(@MyEMSLState, 0) = 0
	Begin
		Set @message = 'Job ' + Convert(varchar(12), @Job) + ' has MyEMSLState = 0; cannot cache'
		Exec PostLogEntry 'Error', @message, 'CacheMyEMSLFile', @duplicateEntryHoldoffHours=1
		Set @myerror = 5001
		Goto Done
	End
	
	---------------------------------------------------
	-- Construct the cache folder path
	---------------------------------------------------
	
	Declare @CacheFolderPath varchar(512)
	
	SELECT @CacheFolderPath = Server_Path
	FROM T_Folder_Paths
	WHERE ([Function] = 'MyEMSL Cache Folder')
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	If @myRowCount = 0
	Begin
		Set @message = 'MyEMSL Cache Folder not defined in T_Folder_Paths'
		Exec PostLogEntry 'Error', @message, 'CacheMyEMSLFile', @duplicateEntryHoldoffHours=1
		Set @myerror = 5002
		Goto Done
	End
	
	-- @DatasetStoragePath should look like: \\proto-7\VOrbiETD04\2013_4\
	-- Remove the server name from @DatasetStoragePath to define @ParentPath
	
	Declare @ParentPath varchar(255)
	
	Declare @CharLoc int
	Set @CharLoc = CharIndex('\', @DatasetStoragePath, 3)

	If @CharLoc > 1
		Set @ParentPath = Substring(@DatasetStoragePath, @CharLoc, Len(@DatasetStoragePath) - @CharLoc)
	Else
	Begin
		-- This code shouldn't be reached
		
		Set @ParentPath = @DatasetStoragePath
		
		-- Remove any leading slashes
		If @ParentPath Like '\%'
			Set @ParentPath = SubString(@ParentPath, 2, Len(@ParentPath) - 1)
			
		If @ParentPath Like '\%'
			Set @ParentPath = SubString(@ParentPath, 2, Len(@ParentPath) - 1)
	End

	Set @LocalCacheFolderPath = dbo.udfCombinePaths(@CacheFolderPath, @ParentPath)

	Set @LocalResultsFolderPath = dbo.udfCombinePaths(dbo.udfCombinePaths(@LocalCacheFolderPath, @DatasetFolder), @ResultsFolder)

	---------------------------------------------------
	-- Start a transaction
	---------------------------------------------------
	
	Declare @AddUpdateTran varchar(64) = 'Add/update FileCache'	
	Begin Tran @AddUpdateTran

	---------------------------------------------------
	-- Look for the cache folder in T_MyEMSL_Cache_Paths
	-- Add it if missing
	---------------------------------------------------
		
	Declare @CachePathID int
	
	SELECT @CachePathID = Cache_PathID
	FROM T_MyEMSL_Cache_Paths
	WHERE Dataset_ID = @DatasetID AND
	      Results_Folder_Name = @ResultsFolder
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	If @myRowCount = 0
	Begin

		-- Path needs to be added
		INSERT INTO T_MyEMSL_Cache_Paths (Dataset_ID, Parent_Path, Results_Folder_Name)
		VALUES (@DatasetID, @ParentPath, @ResultsFolder)
		
		Set @CachePathID = SCOPE_IDENTITY()			
	End

	---------------------------------------------------
	-- Look for the file to cache in T_MyEMSL_FileCache
	-- Add it if missing
	---------------------------------------------------
	
	Declare @EntryID int
	Declare @CacheStart datetime
	Declare @QueuedForDownload datetime

	SELECT TOP 1 @EntryID = FC.Entry_ID,
	             @CacheState = FC.State,
	             @CacheStart = CT.Task_Start,
	             @QueuedForDownload = FC.Queued
	FROM T_MyEMSL_FileCache FC
	     LEFT OUTER JOIN T_MyEMSL_Cache_Task CT
	       ON FC.Task_ID = CT.Task_ID
	WHERE (FC.Job = @Job) AND
	      (FC.Filename = @Filename) AND
	      (FC.Cache_PathID = @CachePathID)
	ORDER BY Entry_ID DESC
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	If @myRowCount > 0
	Begin

		---------------------------------------------------
		-- Already present in T_MyEMSL_FileCache
		---------------------------------------------------
		
		If DateDiff(hour, @QueuedForDownload, GetDate()) > 48
		Begin
			-- File has been in the download queue for over 2 days
			-- 
			Set @CacheState = 4
				
			UPDATE T_MyEMSL_FileCache
			SET State = @CacheState
			WHERE Entry_ID = @EntryID				
				
			Set @message = 'File ' + @Filename + ' for job ' + Convert(varchar(12), @Job) + ' has been in the MyEMSL download queue for over 48 hours'
			Exec PostLogEntry 'Error', @message, 'CacheMyEMSLFile'
		End
		Else
		Begin
			If @CacheState = 1
				Set @message = 'File is already scheduled to be cached'
			
			If @CacheState = 2
				Set @message = 'File is currently being cached'
				
			If (@CacheState = 2 And DATEDIFF(minute, @CacheStart, GETDATE()) > 120) OR (@CacheState = 4)
			Begin
				-- Either stale (in state 2 for over 2 hours) or failed (state 4)
				
				If @CacheState = 4
					Set @message = 'Reset cache state to 1 for failed file'
				Else
					Set @message = 'Reset cache state to 1 for stale file'
				
				Set @message = @message + '; entry ' + Convert(varchar(12), @EntryID) + ', job ' + Convert(varchar(12), @Job)
				
				Set @CacheState = 1
				
				UPDATE T_MyEMSL_FileCache
				SET State = @CacheState
				WHERE Entry_ID = @EntryID
				
				Exec PostLogEntry 'Error', @message, 'CacheMyEMSLFile'
			End
		End
		
		If @CacheState = 3
		Begin
			Set @message = 'File is cached and ready for use'
			Set @Available = 1
		End
		
		If @CacheState = 5
		Begin
			-- File was previously cached then subsequently purged; reset back to state 1
			--			
			Set @CacheState = 1
			
			UPDATE T_MyEMSL_FileCache
			SET State = @CacheState, 
			    Queued = GetDate()     -- Reset the Queued date
			WHERE Entry_ID = @EntryID
			
			Set @message = 'Reset cache state to 1 for purged file; entry ' + Convert(varchar(12), @EntryID) + ', job ' + Convert(varchar(12), @Job)
			Exec PostLogEntry 'Normal', @message, 'CacheMyEMSLFile'
			
		End
	End
	Else
	Begin

		---------------------------------------------------
		-- Add to T_MyEMSL_FileCache
		---------------------------------------------------

		Set @CacheState = 1
		
		INSERT INTO T_MyEMSL_FileCache (Job, Filename, State, Cache_PathID, Queued)
		VALUES (@Job, @Filename, @CacheState, @CachePathID, GetDate())
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	
		Set @message = 'Added file to cache table'
	
	End
	
	---------------------------------------------------
	-- Commit the transaction
	---------------------------------------------------
	
	Commit Tran @AddUpdateTran
	
Done:
	Return @myError

GO
