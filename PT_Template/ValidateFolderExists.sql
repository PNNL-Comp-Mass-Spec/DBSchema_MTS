/****** Object:  StoredProcedure [dbo].[ValidateFolderExists] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.ValidateFolderExists
/****************************************************
**
**	Desc: 
**		Validates that the folder exists
**		If @CreateIfMissing <> 0, then tries to create the folder if missing
**
**		Returns an error if the folder does not exist (or could not be created)
**
**		Note that this procedure will only try to create the final folder in the path
**		For example, if the path is \\MyServer\MyShare\Folder1\Folder2\ then it will
**		 only try to create folder Folder2
**
**	Parameters:
**
**	Auth:	mem
**	Date:	07/18/2006
**			03/17/2007 mem - Added Try/Catch error handling
**
*****************************************************/
(
	@FolderPath varchar(256),
	@CreateIfMissing tinyint = 1,
	@FolderExists tinyint = 0 OUTPUT,
	@FolderCreated tinyint = 0 OUTPUT,
	@message varchar(255) = '' OUTPUT
)
AS
	Set NoCount On
	
	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Begin Try
	
		-----------------------------------------------
		-- Clear the output parameters
		-----------------------------------------------

		set @FolderPath = IsNull(@FolderPath, '')
		set @FolderExists = 0
		set @FolderCreated = 0
		set @message = ''
		
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
		Begin
			Set @FolderExists = 1
		End
		Else
		Begin
			If @CreateIfMissing = 0
			Begin
				set @myError = 60002
				set @message = 'Folder not found: ' + @FolderPath
			End
			Else
			Begin
				-- Folder not found; try to create it
				
				Set @CurrentLocation =  'Create folder ' + @FolderPath
				--
				EXEC @hr = sp_OAMethod  @FSOObject, 'CreateFolder', @result OUT, @FolderPath
				IF @hr <> 0
				BEGIN
					EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
					If Len(IsNull(@message, '')) = 0
						Set @message = 'Error creating missing folder: ' + @FolderPath
					set @myError = 60003
					goto DestroyFSO
				END

				-- Creation appears successful; verify that the folder now exists

				Set @CurrentLocation =  'Verify newly created folder ' + @FolderPath
				--
				EXEC @hr = sp_OAMethod  @FSOObject, 'FolderExists', @result OUT, @FolderPath
				IF @hr <> 0
				BEGIN
					EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
					If Len(IsNull(@message, '')) = 0
						Set @message = 'Error calling FolderExists for: ' + @FolderPath
					set @myError = 60004
					goto DestroyFSO
				END
				--
				If @result <> 0
				Begin
					Set @FolderExists = 1
					Set @FolderCreated = 1
				End
				Else
				Begin
					set @myError = 60005
					set @message = 'Tried to create folder since missing, but creation failed (' + @FolderPath + ')'
				End
			End
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
			goto done
		END
	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'ValidateFolderExists')
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
GRANT VIEW DEFINITION ON [dbo].[ValidateFolderExists] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[ValidateFolderExists] TO [MTS_DB_Lite] AS [dbo]
GO
