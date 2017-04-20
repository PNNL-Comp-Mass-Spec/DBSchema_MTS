/****** Object:  StoredProcedure [dbo].[VerifyDirectoryExists] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure [dbo].[VerifyDirectoryExists]
/****************************************************
**
**	Desc: 
**		Verifies that the given directory exists
**		Optionally creates the directory if missing (use @createIfMissing=1)
**
**		If the directory exists, @myError will be 0 and @message will be ''
**
**		If the directory does not exist and @createIfMissing is 0,
**		@myError will be 61 and @message will be 'Directory does not exist'
**
**		If the directory does not exist and @createIfMissing is 1, the procedure attempts to create it.
**		If successful, @message is 'Directory created', otherwise it is the error message and @myError is 61
**
**	Auth:	mem
**	Date:	3/22/2016 mem - Initial version
**    
*****************************************************/
(
	@directoryPath varchar(255),
	@createIfMissing tinyint = 0,
	@message varchar(255)='' output,
	@showDebugMessages tinyint = 0
)
AS
	Set nocount on
	
	Declare @myError int
	Declare @myRowCount int
	Set @myError = 0
	Set @myRowCount = 0

	Declare @result int
	
	Declare @FSOObject int
	Declare @TxSObject int
	Declare @hr int

	-----------------------------------------------
	-- Validate the inputs
	-----------------------------------------------
	--
	Set @directoryPath = IsNull(@directoryPath, '')
	Set @createIfMissing = IsNull(@createIfMissing, 1)
	Set @message = ''
	Set @showDebugMessages = IsNull(@showDebugMessages, 0)

	If @directoryPath = ''
	Begin
		Set @message = '@directoryPath cannot be empty'
		Set @myError = 62
		Goto Done
	End
	
	-----------------------------------------------
	-- Make sure that @directoryPath does not end in \
	-----------------------------------------------
	--
	While Len(@directoryPath) > 1 And @directoryPath Like '%\'
	Begin
		If @showDebugMessages > 0
			Print 'Remove trailing \ from ' + @directoryPath

		Set @directoryPath = Left(@directoryPath, Len(@directoryPath)-1)
	End
		
	-----------------------------------------------
	-- Create a FileSystemObject object
	-----------------------------------------------
	--
	If @showDebugMessages > 0
		Print 'Instantiate Scripting.FileSystemObject'
		
	Exec @hr = sp_OACreate 'Scripting.FileSystemObject', @FSOObject OUT
	If @hr <> 0
	Begin
	    Exec LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
		Set @message = IsNull(@message, 'Unknown error instantiating the FileSystemObject')
		Set @myError = 60
		If @showDebugMessages > 0 Print @message
		Goto Done
	End

	-----------------------------------------------
	-- Look for the directory
	-- FolderExists returns 0 if the directory does not exist
	-----------------------------------------------
	--
	If @showDebugMessages > 0
		Print 'Look for ' + @directoryPath

	Exec @hr = sp_OAMethod @FSOObject, 'FolderExists', @result OUT, @directoryPath
	If @hr <> 0
	Begin
	    Exec LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
		Set @message = IsNull(@message, 'Unknown error calling FolderExists, first time')
		Set @myError = 60
		If @showDebugMessages > 0 Print @message
	    Goto DestroyFSO
	End
	
	If @result > 0
	Begin
		If @showDebugMessages > 0
			Print 'Directory found'
	End
	Else
	Begin -- <a>
		-----------------------------------------------
		-- Directory does not exist
		-----------------------------------------------
		--
		If @createIfMissing = 0
		Begin
			Set @message = 'Directory does not exist'
			Set @myError = 61
			If @showDebugMessages > 0
				Print @message
		End
	    Else
	    Begin -- <b>
			If @showDebugMessages > 0
				Print 'Directory does not exist'
				
			-----------------------------------------------
			-- Need to create the directory
			-- First confirm that the parent directory exists
			-----------------------------------------------
			--
			-- Look for a backslash, starting with the 4th character
			--			
			Declare @slashIndex int = CharIndex('\', @directoryPath, 4)

			If @slashIndex = 0
			Begin
				If @showDebugMessages > 0
					Print 'Directory cannot have a parent (no \ after the 3rd character)'
			End
			Begin
				-----------------------------------------------
				-- Backslash found; confirm that the parent directory exists
				-----------------------------------------------
				--				
				Declare @parentDirectoryPath varchar(255)
				Set @parentDirectoryPath = Left(@directoryPath, Len(@directoryPath) - CHARINDEX('\', REVERSE('\' + @directoryPath)))

				If @showDebugMessages > 0
					Print 'Check for the parent directory, ' + @parentDirectoryPath
				
				Exec @hr = sp_OAMethod @FSOObject, 'FolderExists', @result OUT, @parentDirectoryPath
				If @hr <> 0
				Begin
					Exec LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
					Set @message = IsNull(@message, 'Unknown error calling FolderExists, first time')
					Set @myError = 60
					If @showDebugMessages > 0 Print @message
					Goto DestroyFSO
				End

				If @result > 0
				Begin
					If @showDebugMessages > 0
						Print 'Parent directory found'
				End
				Else
				Begin
					-----------------------------------------------
					-- Parent directory not found
					-- Recursively call this procedure to create it
					-----------------------------------------------
					--
					If @showDebugMessages > 0
						Print 'Parent directory not found; call VerifyDirectoryExist'
					
					Exec @result = VerifyDirectoryExists @parentDirectoryPath, @createIfMissing=1, @message=@message output, @showDebugMessages=@showDebugMessages
					If @result <> 0
					Begin
						Set @message = IsNull(@message, 'Unknown error creating ' + @parentDirectoryPath + ' via a recursive call to VerifyDirectoryExists')
						Set @myError = @result
						If @showDebugMessages > 0 Print @message
						Goto DestroyFSO
					End
				End
			End

			-----------------------------------------------
			-- Create the directory
			-- Note that the CreateFolder method returns the handle to a Folder object (e.g. 33488638)
			-----------------------------------------------

			If @showDebugMessages > 0
				Print 'Create directory ' + @directoryPath
						
			Exec @hr = sp_OAMethod @FSOObject, 'CreateFolder', @result OUT, @directoryPath
			If @hr <> 0
			Begin
				Exec LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
				Set @message = IsNull(@message, 'Unknown error calling CreateFolder')
				Set @myError = 60
				If @showDebugMessages > 0 Print @message
				Goto DestroyFSO
			End
		
			If @result = 0
			Begin
				Set @message = 'Directory could not be created (directory object handle not returned by the CreateFolder method)'
				If @showDebugMessages > 0 Print @message
			End
			Else
			Begin -- <c>
				-----------------------------------------------
				-- Verify that the directory was created
				-- Delay for 250 msec before checking
				-----------------------------------------------
				--				
				WAITFOR DELAY '0:0:0.250'

				If @showDebugMessages > 0 
					Print 'Verify that the directory was created'
				
				Exec @hr = sp_OAMethod @FSOObject, 'FolderExists', @result OUT, @directoryPath
				If @hr <> 0
				Begin
					Exec LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
					Set @message = IsNull(@message, 'Unknown error calling FolderExists, second time')
					Set @myError = 60
					If @showDebugMessages > 0 Print @message
					Goto DestroyFSO
				End
				--
				If @result > 0
				Begin
					Set @message = 'Directory created'
				End
				Else
				Begin
					Set @myError = 61
					Set @message = 'Directory creation error (creation appeared successful, but cannot verify)'
				End
				
				If @showDebugMessages > 0 
					Print @message
					
			End -- </c>
	   
	    End -- </b>
	End -- </a>

  
DestroyFSO:
	-----------------------------------------------
	-- Clean up the file system object
	-----------------------------------------------
	--
	Exec @hr = sp_OADestroy @FSOObject
	If @hr <> 0
	Begin
	    Exec LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
		Set @message = IsNull(@message, 'Unknown error calling sp_OADestroy')
		Set @myError = 60
		If @showDebugMessages > 0 Print @message
	End

	-----------------------------------------------
	-- Exit
	-----------------------------------------------
	
Done:	
	return @myError


GO
