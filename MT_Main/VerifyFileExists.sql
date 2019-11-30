/****** Object:  StoredProcedure [dbo].[VerifyFileExists] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure [dbo].[VerifyFileExists]
/****************************************************
**
**	Desc: 
**		Verifies that the given file exisits
**
**		If the file exists, @myError will be 0 and @message will be ''
**
**		If the file does not exist, @myError will be 60 and @message will be 'File does not exist'
**
**	Auth:	grk
**	Date:	06/07/2004 grk - Initial version
**			03/22/2016 mem - Updated formatting to match VerifyDirectoryExists
**    
*****************************************************/
(
	@filePath varchar(255),
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
	Set @filePath = IsNull(@filePath, '')
	Set @message = ''
	Set @showDebugMessages = IsNull(@showDebugMessages, 0)
	
	If @filePath = ''
	Begin
		Set @message = '@filePath cannot be empty'
		Set @myError = 60
		If @showDebugMessages > 0 Print @message
		Goto Done
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
	-- Look for the file
	-- FileExists returns 0 if the file does not exist
	-----------------------------------------------
	--
	If @showDebugMessages > 0
		Print 'Look for ' + @filePath

	Exec @hr = sp_OAMethod  @FSOObject, 'FileExists', @result OUT, @filePath
	If @hr <> 0
	Begin
	    Exec LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
		Set @message = IsNull(@message, 'Unknown error calling FileExists, first time')
		Set @myError = 60
		If @showDebugMessages > 0 Print @message
	    Goto DestroyFSO
	End

	If @result > 0
	Begin
		If @showDebugMessages > 0
			Print 'File found'
	End
	Else
	Begin
		Set @message = 'File does not exist'
		Set @myError = 60
		If @showDebugMessages > 0 Print @message
	End
  
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
GRANT VIEW DEFINITION ON [dbo].[VerifyFileExists] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[VerifyFileExists] TO [MTS_DB_Lite] AS [dbo]
GO
