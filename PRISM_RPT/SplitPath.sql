/****** Object:  StoredProcedure [dbo].[SplitPath] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.SplitPath
/****************************************************
**
**	Desc: Examines the file or folder path defined in @FileOrFolderPath
**		  Populates @FileOrFolderName with the folder name at the end
**		  Populates @FolderPathBase with the path up to @FileOrFolderName (excluding the "\")
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	01/08/2008
**
*****************************************************/
(
    @FileOrFolderPath varchar(512),
    @FolderPathBase varchar(512) output,
    @FileOrFolderName varchar(256) output
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	Declare @message varchar(512)
	Set @message = ''
	
	Declare @CharLoc int
	Set @CharLoc = 0

	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'
	
	Begin Try

		Set @CurrentLocation = 'Validate the inputs'
	
		---------------------------------------------------
		-- Validate the inputs
		---------------------------------------------------
		Set @FileOrFolderPath = LTrim(RTrim(IsNull(@FileOrFolderPath, '')))
		Set @FolderPathBase = ''
		Set @FileOrFolderName = ''

		---------------------------------------------------
		-- Determine the final name in @FileOrFolderPath
		---------------------------------------------------
		
		Set @CurrentLocation = 'Examine @FileOrFolderPath'

		-- If @FileOrFolderPath ends in a '\' then remove it
		If Right(@FileOrFolderPath, 1) = '\'
			Set @FileOrFolderPath = Left(@FileOrFolderPath, Len(@FileOrFolderPath)-1)

		-- Look for the last '\' in @FileOrFolderPath
		Set @CharLoc = CharIndex('\', Reverse(@FileOrFolderPath))
		If @CharLoc <= 0
		Begin
			Set @FolderPathBase = @FileOrFolderPath
			Set @FileOrFolderName = ''			
		End
		Else
		Begin -- <a>
			Set @CharLoc = Len(@FileOrFolderPath) - @CharLoc + 1
			If @CharLoc <= 1
			Begin
				Set @FolderPathBase = ''
				Set @FileOrFolderName = @FileOrFolderPath
			End			
			Else
			Begin -- <b>
				If Left(@FileOrFolderPath, @CharLoc) = '\' OR Left(@FileOrFolderPath, @CharLoc) = '\\'
				Begin
					Set @FolderPathBase = ''
					Set @FileOrFolderName = @FileOrFolderPath
				End
				Else
				Begin -- <c>
					Set @FolderPathBase = Left(@FileOrFolderPath, @CharLoc-1)
					
					If @CharLoc < Len(@FileOrFolderPath)
						Set @FileOrFolderName = SubString(@FileOrFolderPath, @CharLoc+1, Len(@FileOrFolderPath))
					Else
						Set @FileOrFolderName = ''
				End -- </c>
			End -- </b>
		End -- </a>

	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'SplitPath')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
								@ErrorNum = @myError output, @message = @message output,
								@duplicateEntryHoldoffHours = 1
		Goto Done
	End Catch

	
	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	
	return @myError

GO
