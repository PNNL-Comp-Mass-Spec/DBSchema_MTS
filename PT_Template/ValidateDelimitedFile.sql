/****** Object:  StoredProcedure [dbo].[ValidateDelimitedFile] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
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
**	Auth:	mem
**	Date:	10/15/2004
**			06/04/2006 mem - Added option to auto-determine the number of lines to skip by examining the column given by @ColumnToUseForNumericCheck
**						   - Updated @LineCountToSkip to return the number of lines determined to skip
**						   - Increased @filePath from varchar(255) to varchar(512)
**    
*****************************************************/
(
	@FilePath varchar(512),
	@LineCountToSkip int=0 OUTPUT,			-- Set this to a negative number to auto-determine the number of lines to skip based on @ColumnToUseForNumericCheck; set to a positive value to skip the first @LineCountToSkip lines when determining column count
	@FileExists tinyint=0 OUTPUT,
	@ColumnCount int=0 OUTPUT,
	@message varchar(255)='' OUTPUT,
	@ColumnToUseForNumericCheck smallint=1		-- Only used when @LineCountToSkip is negative; set to 1 to check the first column
)
AS
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	declare @result int
	
	Set @LineCountToSkip = IsNull(@LineCountToSkip, -1)
	Set @FileExists = 0
	Set @ColumnCount = 0
	Set @message = ''
	
	Set @ColumnToUseForNumericCheck = IsNull(@ColumnToUseForNumericCheck, 1)
	If @ColumnToUseForNumericCheck < 1
		Set @ColumnToUseForNumericCheck = 1

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
	EXEC @hr = sp_OAMethod  @FSOObject, 'FileExists', @result OUT, @FilePath
	IF @hr <> 0
	BEGIN
	    EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
		If Len(IsNull(@message, '')) = 0
			Set @message = 'Error calling FileExists for: ' + @FilePath
		set @myError = 61
	    goto DestroyFSO
	END
	--
	If @result = 0
	begin
		set @FileExists = 0
		set @message = 'File not found: ' + @FilePath
		set @myError = 62
	    goto DestroyFSO
	end
	else
		set @FileExists = 1
	
	
	-- Determine the number of columns in the file
	--
	-- Create a TextStream object.
	--
	EXEC @hr = sp_OAMethod  @FSOObject, 'OpenTextFile', @TextStreamObject OUT, @FilePath
	IF @hr <> 0
	BEGIN
	    EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
		If Len(IsNull(@message, '')) = 0
			Set @message = 'Error calling OpenTextFile for ' + @FilePath
		set @myError = 63
		goto Done
	END

	Declare @LineIn varchar(2048)
	Declare @AtEOF int
	Declare @LinesRead int
	Set @LinesRead = 0
	
	Declare @charLoc int
	Declare @continue tinyint
	Declare @KeyColumnIsNumeric tinyint
	Declare @LastCharLoc int
	Declare @ColumnValue varchar(2048)

	-- See if we're at the end of the file
	--
	EXEC @hr = sp_OAMethod @TextStreamObject, 'AtEndOfStream', @AtEOF OUT
	IF @hr <> 0
	BEGIN
		EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
		If Len(IsNull(@message, '')) = 0
			Set @message = 'Error checking EndOfStream for ' + @FilePath
			
		set @myError = 64
		goto DestroyFSO
	END

	IF @AtEOF <> 0
	Begin
		Set @LineIn = ''
		Set @ColumnCount = 0
	End
	Else
	Begin -- <a>
		-- Read the lines from the file until the column count has been determined
		--
		Set @continue = 1
		While @continue = 1 And @AtEOF = 0
		Begin -- <b>
			EXEC @hr = sp_OAMethod  @TextStreamObject, 'Readline', @LineIn OUT
			IF @hr <> 0
			BEGIN
				EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
				If Len(IsNull(@message, '')) = 0
					Set @message = 'Error reading first line from ' + @FilePath
					
				set @myError = 65
				goto DestroyFSO
			END
			
			EXEC @hr = sp_OAMethod @TextStreamObject, 'AtEndOfStream', @AtEOF OUT

			Set @LinesRead = @LinesRead + 1

			If Len(@LineIn) > 0
			Begin -- <c>
				-- Count the number of tabs in @LineIn
				-- In addition, if @LineCountToSkip is less than 0, then check whether column @ColumnToUseForNumericCheck is numeric
				Set @ColumnCount = 1
				Set @KeyColumnIsNumeric = 255		-- Note: 255 is a sentinel value, used below to check whether the key column was not found
				Set @LastCharLoc = 0
				Set @charLoc = charindex(Char(9), @LineIn)
				While @charLoc > 0
				Begin -- <d>
					If @LineCountToSkip < 0 And @ColumnCount = @ColumnToUseForNumericCheck
					Begin
						Set @ColumnValue = SubString(@LineIn, @LastCharLoc+1, @charLoc - @LastCharLoc - 1)
						
						If IsNumeric(@ColumnValue) <> 0
							Set @KeyColumnIsNumeric = 1
						Else
							Set @KeyColumnIsNumeric = 0
					End
					
					Set @ColumnCount = @ColumnCount + 1
					Set @LastCharLoc = @charLoc
					Set @charLoc = charindex(Char(9), @LineIn, @charLoc+1)
				End -- </d>

				If @LineCountToSkip < 0 and @KeyColumnIsNumeric = 255 And @ColumnToUseForNumericCheck = @ColumnCount
				Begin
					-- Auto-determining @LineCountToSkip, but @ColumnToUseForNumericCheck = @ColumnCount (or @ColumnToUseForNumericCheck = 1 and no tabs were found)
					-- Check whether the entire line is numeric
					Set @ColumnValue = SubString(@LineIn, @LastCharLoc+1, Len(@LineIn))
					If IsNumeric(@ColumnValue) <> 0
						Set @KeyColumnIsNumeric = 1
					Else
						Set @KeyColumnIsNumeric = 0
				End
				
	 			
				If @LineCountToSkip >= 0
				Begin
					If @LinesRead > @LineCountToSkip
						Set @continue = 0
				End
				Else
				Begin
					If @KeyColumnIsNumeric = 1
					Begin
						Set @continue = 0
						Set @LineCountToSkip = @LinesRead-1
					End
				End
			End -- </c>
		End -- </b>
	End -- </a>

	If @LineCountToSkip < 0
	Begin
		-- Never did find a line with a numeric value in column @ColumnToUseForNumericCheck
		-- Set @LineCountToSkip to @LinesRead, set @ColumnCount to 0, and update @message with a warning
		Set @LineCountToSkip = @LinesRead
		Set @ColumnCount = 0
		Set @message = 'Warning: could not find a line with a numeric value in column ' + Convert(varchar(9), @ColumnToUseForNumericCheck)
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
GRANT VIEW DEFINITION ON [dbo].[ValidateDelimitedFile] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[ValidateDelimitedFile] TO [MTS_DB_Lite]
GO
