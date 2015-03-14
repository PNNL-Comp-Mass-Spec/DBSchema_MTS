/****** Object:  StoredProcedure [dbo].[ValidateFilesExist] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure ValidateFilesExist
/****************************************************
**
**	Desc: 
**		Validates that the specified files exist in the specified folder
**
**		Returns an error if any of the files are missing
**
**	Auth:	mem
**	Date:	11/21/2011 mem - Initial Version
**			10/10/2013 mem - Added @FirstMissingFile and @ShowDebugInfo
**			12/12/2013 mem - Added support for optional files
**
*****************************************************/
(
	@FolderPath varchar(256),
	@RequiredFileList varchar(max),
	@FileCountFound int = 0 output,
	@FileCountMissing int = 0 output,
	@message varchar(512) = '' output,
	@FirstMissingFile varchar(512) = '' output,
	@ShowDebugInfo tinyint = 0
)
AS
	Set NoCount On
	
	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(512)
	Set @CurrentLocation = 'Start'

	Declare @FolderExists int

	Declare @EntryID int
	Declare @FileName varchar(255)
	Declare @FilePath varchar(512)
	Declare @MissingFileList varchar(512) = ''
	
	Declare @Optional tinyint
	Declare @Continue tinyint
	
	Begin Try
	
		-----------------------------------------------
		-- Clear the output parameters
		-----------------------------------------------

		set @FolderPath = IsNull(@FolderPath, '')
		set @FileCountFound = 0
		set @FileCountMissing = 0
		set @message = ''
		set @FirstMissingFile = ''
		
		Set @ShowDebugInfo = IsNull(@ShowDebugInfo, 0)
			
		declare @result int

		If Len(LTrim(RTrim(@FolderPath))) = 0
		Begin
			Set @message = 'Folder not found: Empty folder path'
			Set @myError = 60010
			Goto Done
		End
		
		-----------------------------------------------
		-- Create a FileSystemObject object
		-----------------------------------------------
		
		DECLARE @FSOObject int
		DECLARE @TxSObject int
		DECLARE @hr int

		Set @CurrentLocation =  'Create Scripting.FileSystemObject'
		If @ShowDebugInfo <> 0 Print @CurrentLocation
		--
		EXEC @hr = sp_OACreate 'Scripting.FileSystemObject', @FSOObject OUT
		IF @hr <> 0
		BEGIN
			EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
			If Len(IsNull(@message, '')) = 0
				Set @message = 'Error creating FileSystemObject'
			set @myError = 60000
			goto Done
		END

		Set @CurrentLocation =  'Call FolderExists for ' + @FolderPath
		If @ShowDebugInfo <> 0 Print @CurrentLocation
		--
		EXEC @hr = sp_OAMethod  @FSOObject, 'FolderExists', @result OUT, @FolderPath
		IF @hr <> 0
		BEGIN
			EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
			If Len(IsNull(@message, '')) = 0
				Set @message = 'Error calling FolderExists for: ' + @FolderPath
			set @myError = 60001
			goto DestroyFSO
		END
		--
		If @result <> 0
		Begin -- <a>
			-- Folder exists
			Set @FolderExists = 1
			
			-- Populate a temporary table with the filenames in @RequiredFileList
			--
			CREATE TABLE #Tmp_FilesToFind (
				Entry_ID int Identity(1,1),
				FileName varchar(512),
				FileExists tinyint
			)
			
			INSERT INTO #Tmp_FilesToFind (FileName, FileExists)
			SELECT Value, 0 AS FileExists
			FROM dbo.udfParseDelimitedList(@RequiredFileList, ',')
			ORDER BY Value
			
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
				
					Set @Optional = 0
					If @FileName Like 'Optional:%'
					Begin
						Set @FileName = Replace(@FileName, 'Optional:', '')
						Set @Optional = 1
					End
						
					Set @FilePath = dbo.udfCombinePaths(@FolderPath, @FileName)					
					Set @CurrentLocation = 'Call FileExists for ' + @FilePath
					If @ShowDebugInfo <> 0 Print @CurrentLocation
					--
					EXEC @hr = sp_OAMethod  @FSOObject, 'FileExists', @result OUT, @FilePath
					IF @hr <> 0
					BEGIN
						EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
						If Len(IsNull(@message, '')) = 0
							Set @message = 'Error calling FileExists for: ' + @FilePath
						set @myError = 60002
						goto DestroyFSO
					END
					
					If @result <> 0
						Set @FileCountFound = @FileCountFound + 1
					Else
					Begin
						If @Optional = 0
						Begin
							Set @FileCountMissing = @FileCountMissing + 1
							If @FileCountMissing = 1
							Begin
								Set @MissingFileList = @FileName
								Set @FirstMissingFile = @FileName
							End
							Else
							Begin
								Set @MissingFileList = @MissingFileList + ', ' + @FileName
							End	
						End					
					End
				
				End -- </c>
		
			End -- </b>
			
			If @FileCountMissing > 0
			Begin
				
				If @FileCountMissing > 1
					Set @message = Convert(varchar(12), @FileCountMissing) + ' files not found: ' + @MissingFileList
				Else
					Set @message = '1 file not found: ' + @MissingFileList
					
				Set @myError = 60011
			End
			
		End -- </a>
		Else
		Begin
			Set @message = 'Folder not found: ' + @FolderPath
			Set @myError = 60012
		End
		
	DestroyFSO:
		-----------------------------------------------
		-- Clean up the file system object
		-----------------------------------------------

		Set @CurrentLocation =  'Destroy @FSOObject'
		--
		EXEC @hr = sp_OADestroy @FSOObject
		IF @hr <> 0
		BEGIN
			EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
			set @myError = 60006
			goto Done
		END
	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'ValidateFilesExist')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
								@ErrorNum = @myError output, @message = @message output
		Goto Done
	End Catch		
	
	-----------------------------------------------
	-- Exit
	-----------------------------------------------
Done:	
	return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[ValidateFilesExist] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[ValidateFilesExist] TO [MTS_DB_Lite] AS [dbo]
GO
