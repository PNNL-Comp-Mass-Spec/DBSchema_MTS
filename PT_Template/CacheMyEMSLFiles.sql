/****** Object:  StoredProcedure [dbo].[CacheMyEMSLFiles] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE CacheMyEMSLFiles
/****************************************************
**
**	Desc: Adds the specified job (and optionally files) to the MyEMSL Download Queue
**
**	Input Parameters:
**		@Job: Job number to cache
**		@RequiredFileList: Comma-separated list of filenames
**		@InfoOnly
**
**	Output Parameters
**		@CacheState: Cache state:
**			-- State 0 means the Job is not in MyEMSL
**			-- State 1 means the Job was added to the download queue (or was already in the download queue)
**			-- State 2 means the Job's files are currently being cached
**			-- State 3 means the specified files have been cached locally and are ready to use
**			-- State 4 means there was an error caching the files locally (either a download error occurred, or over 48 hours has elapsed since the job's files were added to the queue)
**		@LocalCacheFolderPath: local path to which the files will be cached; does not include the dataset name or results folder name
**		@LocalResultsFolderPath: local path to the folder with the actual cached files
**		@message
**
**	Auth:	mem
**	Date:	10/10/2013 mem - Initial Version
**			12/10/2013 mem - Now checking for an error code returned by CacheMyEMSLFile
**
*****************************************************/
(
	@Job int,
	@RequiredFileList varchar(max),					-- Comma separated list of files; cannot be blank, but can be * for "all files"
	@CacheState tinyint output,
	@LocalCacheFolderPath varchar(255) output,		-- Local path to which the files will be cached; does not include the dataset name or results folder name
	@LocalResultsFolderPath varchar(512) output,	-- Local path to the folder with the actual cached files
	@message varchar(512)='' output,
	@InfoOnly tinyint = 0
)
AS
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Declare @CacheStateForFile tinyint
	Declare @Available tinyint
	Declare @FileCountAvailable int = 0
	Declare @FilesToCache int = 0
	Declare @Continue int
	Declare @EntryID int
	Declare @FileName varchar(255)
	
	----------------------------------------------
	-- Validate the inputs and initialize the outputs
	----------------------------------------------
	
	Set @Job = IsNull(@Job, 0)
	Set @RequiredFileList = IsNull(@RequiredFileList, '')
	Set @CacheState = 0
	Set @LocalCacheFolderPath = ''
	Set @LocalResultsFolderPath = ''
	Set @message = ''
	Set @InfoOnly = IsNull(@InfoOnly, 0)

	----------------------------------------------
	-- Populate a temporary table with the filenames in @RequiredFileList
	----------------------------------------------
	
	CREATE TABLE #Tmp_FilesToFind (
		Entry_ID int Identity(1,1),
		FileName varchar(512),
		CacheState tinyint
	)
		
	INSERT INTO #Tmp_FilesToFind (FileName, CacheState)
	SELECT Value, 0 AS CacheState
	FROM dbo.udfParseDelimitedList(@RequiredFileList, ',')
	ORDER BY Value
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	
	Set @FilesToCache = @myRowCount
	
	----------------------------------------------
	-- Parse each file in #Tmp_FilesToFind
	----------------------------------------------	
		
	Set @Continue = 1
	Set @EntryID = 0
	
	While @Continue = 1
	Begin -- <b>
		SELECT TOP 1 @EntryID = Entry_ID,
				     @FileName = FileName
		FROM #Tmp_FilesToFind
		WHERE Entry_ID > @EntryID
		ORDER BY Entry_ID
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		
		If @myRowCount = 0
			Set @Continue = 0
		Else
		Begin -- <c>
									
			-- Check on the status of this file in the download cache
			--
			exec @myError = MT_Main.dbo.CacheMyEMSLFile @Job, @FileName, 
						@CacheState = @CacheStateForFile output, 
						@Available=@Available output, 
						@LocalCacheFolderPath = @LocalCacheFolderPath output,
						@LocalResultsFolderPath = @LocalResultsFolderPath output,
						@message=@message output
			
			If @myError <> 0
			Begin
				Exec PostLogEntry 'Error', @message, 'CacheMyEMSLFiles', @duplicateEntryHoldoffHours=6
				Goto Done
			End
				
			If @CacheState = 0
				Set @CacheState = @CacheStateForFile
			Else
			Begin
				If @CacheStateForFile = 4
					Set @CacheState = 4
				
				If @CacheState = 1 And @CacheStateForFile = 2
					Set @CacheState = 2
				
				If @Available > 0
					Set @FileCountAvailable = @FileCountAvailable + 1
				
			End
			
		
		End -- </c>

	End -- </b>
	
	Set @message = ''
	Declare @MsgType varchar(24) = ''

	If @FileCountAvailable = @FilesToCache
	Begin
		Set @CacheState = 3
		Set @message = 'Job ' + Convert(varchar(12), @Job) + ' has successfully had its files downloaded from MyEMSL and cached locally'
		Set @MsgType = 'Normal'
	End
	Else
	Begin
		Set @LocalCacheFolderPath = ''
		Set @LocalResultsFolderPath = ''
	End

	If @CacheState = 1
	Begin
		Set @message = 'Job ' + Convert(varchar(12), @Job) + ' was added to the MyEMSL download queue' -- (or was already present)
		Set @MsgType = 'Debug'
	End
	
	If @CacheState = 4
	Begin
		Set @message = 'Job ' + Convert(varchar(12), @Job) + ' encountered an error when downloading files from MyEMSL'
		Set @MsgType = 'Error'
	End	
	
	If @MsgType <> ''
	Begin
		
		If @InfoOnly = 0
			Exec PostLogEntry @MsgType, @message, 'CacheMyEMSLFiles', @duplicateEntryHoldoffHours=6
		Else
			Print @message
	End
	
	
Done:
	return @myError

GO
