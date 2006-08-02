SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[ValidateDelimitedFile]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[ValidateDelimitedFile]
GO


CREATE Procedure dbo.ValidateDelimitedFile
/****************************************************
**
**	Desc: 
**		Uses a file system object to validate that the given
**		file exists.  Additionally, opens the file and reads
**		the first line to determine the number of columns present
**
**	Parameters:	Returns 0 if no error, error code if an error, including file not found
**
**		Auth: mem
**		Date: 10/15/2004
**    
*****************************************************/
	@filePath varchar(255),
	@lineCountToSkip int=0,					-- Set this to a positive value to skip the first @lineCountToSkip lines when determining column count
	@fileExists tinyint=0 OUTPUT,
	@columnCount int=0 OUTPUT,
	@message varchar(255)='' OUTPUT
AS
	set nocount on
	declare @myError int,
			@myRowCount int
	set @myError = 0
	set @myRowCount = 0

	declare @result int
	
	Set @lineCountToSkip = IsNull(@lineCountToSkip, 0)
	Set @fileExists = 0
	Set @columnCount = 0
	Set @message = ''

	-----------------------------------------------
	-- Create a FileSystemObject object.
	-----------------------------------------------
	--
	DECLARE @FSOObject int
	DECLARE @TextStreamObject int
	DECLARE @hr int
	--
	EXEC @hr = sp_OACreate 'Scripting.FileSystemObject', @FSOObject OUT
	IF @hr <> 0
	BEGIN
	    EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
		If Len(IsNull(@message, '')) = 0
			Set @message = 'Error creating FileSystemObject'
		set @myError = 60
		goto Done
	END
	
	-----------------------------------------------
	-- Verify that the file exists
	-----------------------------------------------
	--
	EXEC @hr = sp_OAMethod  @FSOObject, 'FileExists', @result OUT, @filePath
	IF @hr <> 0
	BEGIN
	    EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
		If Len(IsNull(@message, '')) = 0
			Set @message = 'Error calling FileExists for: ' + @filePath
		set @myError = 61
	    goto DestroyFSO
	END
	--
	If @result = 0
	begin
		set @fileExists = 0
		set @message = 'File not found: ' + @filePath
		set @myError = 62
	    goto DestroyFSO
	end
	else
		set @fileExists = 1
	
	
	-- Determine the number of columns in the file
	--
	-- Create a TextStream object.
	--
	EXEC @hr = sp_OAMethod  @FSOObject, 'OpenTextFile', @TextStreamObject OUT, @filePath
	IF @hr <> 0
	BEGIN
	    EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
		If Len(IsNull(@message, '')) = 0
			Set @message = 'Error calling OpenTextFile for ' + @filePath
		set @myError = 63
		goto Done
	END

	-- Read the first line of the file
	--
	Declare @LineIn varchar(1024)
	Declare @AtEOF int
	Declare @linesRead int
	Declare @charLoc int

	EXEC @hr = sp_OAMethod @TextStreamObject, 'AtEndOfStream', @AtEOF OUT
	IF @hr <> 0
	BEGIN
		EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
		If Len(IsNull(@message, '')) = 0
			Set @message = 'Error checking EndOfStream for ' + @filePath
			
		set @myError = 64
		goto DestroyFSO
	END

	IF @AtEOF <> 0
	Begin
		Set @LineIn = ''
		Set @columnCount = 0
	End
	Else
	Begin
		Set @linesRead = 0
		
		While @linesRead <= @lineCountToSkip And @AtEOF = 0
		Begin
			EXEC @hr = sp_OAMethod  @TextStreamObject, 'Readline', @LineIn OUT
			IF @hr <> 0
			BEGIN
				EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
				If Len(IsNull(@message, '')) = 0
					Set @message = 'Error reading first line from ' + @filePath
					
				set @myError = 65
				goto DestroyFSO
			END
			Set @linesRead = @linesRead + 1
			EXEC @hr = sp_OAMethod @TextStreamObject, 'AtEndOfStream', @AtEOF OUT
		End
				
		-- Count the number of tabs in @LineIn
		Set @columnCount = 1
		Set @charLoc = charindex(Char(9), @LineIn)
		while @charLoc > 0
		begin
			Set @columnCount = @columnCount + 1
			Set @charLoc = charindex(Char(9), @LineIn, @charLoc+1)
		end
	End
	
	-----------------------------------------------
	-- clean up file system object
	-----------------------------------------------
  
	EXEC @hr = sp_OADestroy  @TextStreamObject
	
DestroyFSO:
	-- Destroy the FileSystemObject object.
	--
	EXEC @hr = sp_OADestroy @FSOObject
	IF @hr <> 0
	BEGIN
	    EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
		If Len(IsNull(@message, '')) = 0
			Set @message = 'Error destroying FileSystemObject'
			
		set @myError = 66
		goto done
	END


Done:
	Return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

