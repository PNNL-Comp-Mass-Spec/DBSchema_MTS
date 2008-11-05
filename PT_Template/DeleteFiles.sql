/****** Object:  StoredProcedure [dbo].[DeleteFiles] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.DeleteFiles
/****************************************************
**
**	Desc: 
**		Deletes the specified file(s)
**
**	Parameters:
**
**	Auth:	mem
**	Date:	07/05/2006
**
*****************************************************/
(
	@FolderPath varchar(256),
	@FileName1 varchar(256),
	@FileName2 varchar(256)='',			-- Optional
	@FileCountDeleted int = 0 OUTPUT,
	@message varchar(255) = '' OUTPUT
)
AS
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	set @FileCountDeleted = 0
	set @message = ''
	
	declare @result int
	
	declare @CurrentFileName varchar(256)
	declare @CurrentFilePath varchar(512)

	-----------------------------------------------
	-- Create a FileSystemObject object.
	-----------------------------------------------

	DECLARE @FSOObject int
	DECLARE @TxSObject int
	DECLARE @hr int
	
	EXEC @hr = sp_OACreate 'Scripting.FileSystemObject', @FSOObject OUT
	IF @hr <> 0
	BEGIN
	    EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
		If Len(IsNull(@message, '')) = 0
			Set @message = 'Error creating FileSystemObject'
		set @myError = 61000
		goto Done
	END

	-----------------------------------------------
	-- Delete @FileName1 and optionally @FileName2
	-----------------------------------------------

	Declare @Iteration int
	Set @Iteration = 0
	While @Iteration < 2
	Begin
		Set @CurrentFileName = Null
		If @Iteration = 0
			Set @CurrentFileName = @FileName1
		If @Iteration = 1
			Set @CurrentFileName = @FileName2

		If Len(IsNull(@CurrentFileName, '')) > 0
		Begin
			set @CurrentFilePath = dbo.udfCombinePaths(@FolderPath, @CurrentFileName)

			EXEC @hr = sp_OAMethod  @FSOObject, 'FileExists', @result OUT, @CurrentFilePath
			IF @hr <> 0
			BEGIN
				EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
				If Len(IsNull(@message, '')) = 0
					Set @message = 'Error calling FileExists for: ' + @CurrentFilePath
				set @myError = 61001
				goto DestroyFSO
			END
			--
			If @result <> 0
			begin
				EXEC @hr = sp_OAMethod  @FSOObject, 'DeleteFile', NULL, @CurrentFilePath
				IF @hr <> 0
				BEGIN
					EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
					If Len(IsNull(@message, '')) = 0
						Set @message = 'Error deleting file: ' + @CurrentFilePath
					set @myError = 61002
					goto DestroyFSO
				END

				Set @FileCountDeleted = @FileCountDeleted + 1
			end
		End

		Set @Iteration = @Iteration + 1
	End
	
DestroyFSO:
	-----------------------------------------------
	-- Clean up the file system object
	-----------------------------------------------
	EXEC @hr = sp_OADestroy @FSOObject
	IF @hr <> 0
	BEGIN
	    EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
		set @myError = 61003
		goto done
	END

	-----------------------------------------------
	-- Exit
	-----------------------------------------------
Done:	
	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[DeleteFiles] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[DeleteFiles] TO [MTS_DB_Lite]
GO
