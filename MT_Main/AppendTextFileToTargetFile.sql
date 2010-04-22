/****** Object:  StoredProcedure [dbo].[AppendTextFileToTargetFile] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure dbo.AppendTextFileToTargetFile
/****************************************************
**
**	Desc: 
**		Appends the contents of one text file to another text file,
**		optionally deleting the source file after appending to the
**		target file
**
**	Parameters:	Returns 0 if no error, error code if an error
**
**	Auth:	mem
**	Date:	07/01/2006
**			07/03/2006 mem - Switched to using xp_cmdshell to append the file contents
**    
*****************************************************/
(
	@SourceFilePath varchar(512),
	@TargetFilePath varchar(512),
	@FileSeparatorText varchar(128) = '-----------------------',
	@DeleteSourceAfterAppend tinyint = 0,
	@SourceIsUnicode smallint = -1,			-- Set to 0 for Ascii, 1 for Unicode, any other number to auto-determine type based on the first two bytes
	@TargetIsUnicode smallint = 0,			-- Set to 0 for Ascii, 1 for Unicode
	@message varchar(255)='' output
)
AS
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	declare @result int

	Declare @LineIn varchar(2048)
	Declare @AtEOF int
	Declare @LinesRead int
	Set @LinesRead = 0

	Declare @CreateFile varchar(12)
	Declare @FileFormatToUse int
	
	-----------------------------------------------
	-- Validate the inputs
	-----------------------------------------------
	Set @SourceFilePath = IsNull(@SourceFilePath, '')
	Set @TargetFilePath = IsNull(@TargetFilePath, '')
	Set @FileSeparatorText = IsNull(@FileSeparatorText, '-----------------------')
	
	If Len(LTrim(RTrim(@SourceFilePath))) = 0
	Begin
		Set @message = 'Error: Source file path not defined'
		Set @myError = 55000
	End

	If Len(LTrim(RTrim(@TargetFilePath))) = 0
	Begin
		Set @message = 'Error: Target file path not defined'
		Set @myError = 55001
	End

	Set @message = ''

	-----------------------------------------------
	-- Create a FileSystemObject object.
	-----------------------------------------------
	--
	DECLARE @FSOObject int
	DECLARE @TextStreamInFile int		-- Only used if @UseXPCmdShell = 0
	DECLARE @TextStreamOutFile int		-- Only used if @UseXPCmdShell = 0
	DECLARE @hr int
	--
	EXEC @hr = sp_OACreate 'Scripting.FileSystemObject', @FSOObject OUT
	IF @hr <> 0
	BEGIN
	    EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
		If Len(IsNull(@message, '')) = 0
			Set @message = 'Error creating FileSystemObject'
		set @myError = 55002
		goto Done
	END

	-----------------------------------------------
	-- Verify that the input file exists
	-----------------------------------------------
	--
	EXEC @hr = sp_OAMethod  @FSOObject, 'FileExists', @result OUT, @SourceFilePath
	IF @hr <> 0
	BEGIN
	    EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
		If Len(IsNull(@message, '')) = 0
			Set @message = 'Error calling FileExists for: ' + @SourceFilePath
		set @myError = 55003
	    goto DestroyFSO
	END
	--
	If @result = 0
	begin
		set @message = 'Source file not found: ' + @SourceFilePath
		set @myError = 55004
	    goto DestroyFSO
	end

	-----------------------------------------------
	-- Default to using xp_cmdshell so that we don't
	-- have to worry about Unicode files
	-----------------------------------------------
	Declare @UseXPCmdShell tinyint
	Set @UseXPCmdShell = 1

	If @UseXPCmdShell <> 0
	Begin
		-----------------------------------------------
		-- Use master..xp_cmdshell to call the "echo" and "type" commands
		-----------------------------------------------

		Declare @cmd nvarchar(4000)
	
		-----------------------------------------------
		-- Write the header line to @TargetFilePath
		-----------------------------------------------
		If Len(LTrim(RTrim(@FileSeparatorText))) > 0	
		Begin
			Set @cmd = 'echo ' + @FileSeparatorText + ' >> "' + @TargetFilePath + '"'
			--
			EXEC @result = master..xp_cmdshell @cmd, NO_OUTPUT 
			--
			if @result <> 0
			Begin
				Set @message = 'Error writing the file separator text to ' + @TargetFilePath
				set @myError = 55005
				goto DestroyFSO
			End
		End
		
		Set @cmd = 'type "' + @SourceFilePath + '" >> "' + @TargetFilePath + '"'
		--
		EXEC @result = master..xp_cmdshell @cmd, NO_OUTPUT 
		--
		if @result <> 0
		Begin
			Set @message = 'Error copying text from ' + @SourceFilePath + ' to ' + @TargetFilePath
			set @myError = 55006
			goto DestroyFSO
		End
		
		if @result = 0
			Set @LinesRead = 1
	
	End
	Else
	Begin -- <a>
		
		-----------------------------------------------
		-- Define the IOMode and FileFormat variables
		-----------------------------------------------
		Declare @IOModeForReading int
		Declare @IOModeForAppending int
		Declare @FormatAscii int
		Declare @FormatUnicode int
		
		-- IOMode 1 = ForReading
		-- IOMode 2 = ForWriting
		-- IOMode 8 = ForAppending
		Set @IOModeForReading = 1
		Set @IOModeForAppending = 8

		Set @FormatAscii = 0
		Set @FormatUnicode = -1

		If @SourceIsUnicode <> 0 and @SourceIsUnicode <> 1
		Begin
			-----------------------------------------------
			-- Open @SourceFilePath and read the first line to
			-- determine if it is a Unicode file
			-----------------------------------------------
			Set @CreateFile = 'False'
			Set @FileFormatToUse = @FormatAscii
			EXEC @hr = sp_OAMethod  @FSOObject, 'OpenTextFile', @TextStreamInFile OUT, @SourceFilePath, @IOModeForReading, @CreateFile, @FileFormatToUse
			IF @hr <> 0
			BEGIN
				EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
				If Len(IsNull(@message, '')) = 0
					Set @message = 'Error calling OpenTextFile for ' + @SourceFilePath
				set @myError = 55007
				goto destroyFSO
			END

			-- For now, assume the source file is not unicode
			Set @SourceIsUnicode = 0

			-- See if we're at the end of the input file (meaning it is zero-length)
			-- If we are, then @AtEOF will be non-zero
			--
			EXEC @hr = sp_OAMethod @TextStreamInFile, 'AtEndOfStream', @AtEOF OUT
			IF @hr <> 0
			BEGIN
				EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
				If Len(IsNull(@message, '')) = 0
					Set @message = 'Error checking EndOfStream for ' + @SourceFilePath
					
				set @myError = 55008
				goto DestroyTextStreams
			END
			
			If @AtEOF = 0
			Begin -- <c>
				-- Read the first line of the input file to see if this is a Unicode file
				-- Little Endian Unicode 16 files start with Bytes 255 and 254 (aka ÿþ)
				-- Big Endian Unicode 16 files start with Bytes 254 and 255 (aka þÿ)

				Set @LineIn = ''
				EXEC @hr = sp_OAMethod  @TextStreamInFile, 'Readline', @LineIn OUT
				IF @hr <> 0
				Begin
					EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
					If Len(IsNull(@message, '')) = 0
						Set @message = 'Error reading text from ' + @SourceFilePath
						
					set @myError = 55009
					goto DestroyTextStreams
				End
						
				If Len(@LineIn) >= 2
				Begin
					Declare @Asc1 int
					Declare @Asc2 int
					Set @Asc1 = Ascii(Substring(@LineIn, 1, 1))
					Set @Asc2 = Ascii(Substring(@LineIn, 2, 1))

					If (@Asc1 = 255 And @Asc2 = 254) OR (@Asc1 = 254 And @Asc2 = 255)
						Set @SourceIsUnicode = 1
				End
			End -- </c>
			
			-- Close the input file		
			EXEC @hr = sp_OAMethod @TextStreamInFile, 'Close'
			EXEC @hr = sp_OADestroy @TextStreamInFile
			Set @TextStreamInFile = 0
		End
		
		-----------------------------------------------
		-- Create a TextStream object to read @SourceFilePath
		-----------------------------------------------
		Set @CreateFile = 'False'
		If @SourceIsUnicode = 0
			Set @FileFormatToUse = @FormatAscii
		Else
			Set @FileFormatToUse = @FormatUnicode
		
		EXEC @hr = sp_OAMethod  @FSOObject, 'OpenTextFile', @TextStreamInFile OUT, @SourceFilePath, @IOModeForReading, @CreateFile, @FileFormatToUse
		IF @hr <> 0
		BEGIN
			EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
			If Len(IsNull(@message, '')) = 0
				Set @message = 'Error calling OpenTextFile for ' + @SourceFilePath
			set @myError = 55010
			goto destroyFSO
		END
		
		
		-----------------------------------------------
		-- Create a TextStream object to append to @TargetFilePath
		-----------------------------------------------
		
		Set @CreateFile = 'True'
		If @TargetIsUnicode = 0
			Set @FileFormatToUse = @FormatAscii
		Else
			Set @FileFormatToUse = @FormatUnicode
			
		EXEC @hr = sp_OAMethod  @FSOObject, 'OpenTextFile', @TextStreamOutFile OUT, @TargetFilePath, @IOModeForAppending, @CreateFile, @FileFormatToUse
		IF @hr <> 0
		BEGIN
			EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
			If Len(IsNull(@message, '')) = 0
				Set @message = 'Error calling OpenTextFile for ' + @TargetFilePath
			set @myError = 55011
			goto destroyFSO
		END

		-----------------------------------------------
		-- Write the header line to @TextStreamOutFile
		-----------------------------------------------
		If Len(LTrim(RTrim(@FileSeparatorText))) > 0	
		Begin
			EXEC @hr = sp_OAMethod @TextStreamOutFile, 'WriteLine', NULL, @FileSeparatorText
			IF @hr <> 0
			BEGIN
				EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
				If Len(IsNull(@message, '')) = 0
					Set @message = 'Error writing the file separator text to ' + @TargetFilePath
				set @myError = 55012
				goto DestroyTextStreams
			END
		End
		
		-- See if we're at the end of the input file
		-- If we are, then @AtEOF will be non-zero
		--
		EXEC @hr = sp_OAMethod @TextStreamInFile, 'AtEndOfStream', @AtEOF OUT
		IF @hr <> 0
		BEGIN
			EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
			If Len(IsNull(@message, '')) = 0
				Set @message = 'Error checking EndOfStream for ' + @SourceFilePath
				
			set @myError = 55013
			goto DestroyTextStreams
		END

		-----------------------------------------------
		-- Read the text from @SourceFilePath and write to @TargetFilePath
		-----------------------------------------------
		While @AtEOF = 0
		Begin -- <b>
			-- Read the next line
			Set @LineIn = ''
			EXEC @hr = sp_OAMethod  @TextStreamInFile, 'Readline', @LineIn OUT
			IF @hr <> 0
			BEGIN
				EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
				If Len(IsNull(@message, '')) = 0
					Set @message = 'Error reading text from ' + @SourceFilePath
					
				set @myError = 55014
				goto DestroyTextStreams
			END

			-- Append it to the output file
			EXEC @hr = sp_OAMethod @TextStreamOutFile, 'WriteLine', NULL, @LineIn

			-- See if we're at the end of the file					
			EXEC @hr = sp_OAMethod @TextStreamInFile, 'AtEndOfStream', @AtEOF OUT

			Set @LinesRead = @LinesRead + 1
		End -- </b>

		If @LinesRead > 0 And Len(@LineIn) <> 0
			-- Add one more blank line to @TextStreamOutFile
			EXEC @hr = sp_OAMethod @TextStreamOutFile, 'WriteLine', NULL, ''

	DestroyTextStreams:
		-----------------------------------------------
		-- Close the text stream objects
		-----------------------------------------------
		Set @hr = 0
		If @TextStreamInFile <> 0
			EXEC @hr = sp_OAMethod @TextStreamInFile, 'Close'
		IF @hr <> 0
		BEGIN
			EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
			If Len(IsNull(@message, '')) = 0
				Set @message = 'Error closing the textstream for ' + @TargetFilePath
				
			set @myError = 55015
			goto done
		END
			
		Set @hr = 0
		If @TextStreamOutFile <> 0
			EXEC @hr = sp_OAMethod @TextStreamOutFile, 'Close'
		IF @hr <> 0
		BEGIN
			EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
			If Len(IsNull(@message, '')) = 0
				Set @message = 'Error closing the textstream for ' + @TargetFilePath
				
			set @myError = 55016
			goto done
		END

		-- Destroy the text stream objects
		If @TextStreamInFile <> 0
			EXEC @hr = sp_OADestroy @TextStreamInFile
			
		If @TextStreamOutFile <> 0
			EXEC @hr = sp_OADestroy @TextStreamOutFile

	End -- </a>

	If @LinesRead > 0 And @DeleteSourceAfterAppend <> 0 and @myError = 0
	Begin
		-----------------------------------------------
		-- Delete the source file 
		-----------------------------------------------
		EXEC @hr = sp_OAMethod  @FSOObject, 'DeleteFile', NULL, @SourceFilePath
		IF @hr <> 0
		BEGIN
			EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
			set @myError = 50020
			goto DestroyFSO
		END
		
	End
	
DestroyFSO:
	-- Destroy the FileSystemObject object.
	Set @hr = 0
	If @FSOObject <> 0
		EXEC @hr = sp_OADestroy @FSOObject
	IF @hr <> 0
	BEGIN
	    EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
		If Len(IsNull(@message, '')) = 0
			Set @message = 'Error destroying FileSystemObject'
			
		set @myError = 55021
		goto done
	END

Done:
	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[AppendTextFileToTargetFile] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[AppendTextFileToTargetFile] TO [MTS_DB_Lite] AS [dbo]
GO
