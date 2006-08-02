SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[DeleteGANETFiles]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[DeleteGANETFiles]
GO


CREATE Procedure dbo.DeleteGANETFiles
/****************************************************
**
**	Desc: 
**		Deletes the specified GANET files
**
**	Parameters:
**
**		Auth:	mem
**		Date:	07/05/2004
**				05/29/2005 mem - No longer adding DB_Name() to @outFileDir or @inFileDir since they now include the database name
**							   - Now also deleting the jobStats file
**
*****************************************************/
	@outFile varchar(256) output,				
	@outFileDir varchar(256) = 'F:\GA_Net_Xfer\Out\',
	@inFile varchar(256) output,				
	@inFileDir varchar(255) = 'F:\GA_Net_Xfer\In\',
	@predFile varchar(256) output,
	@message varchar(255) = '' output
AS
	set nocount on
	
	declare @myError int
	set @myError = 0

	declare @myRowcount int
	
	set @message = ''
	
	declare @result int
	
	declare @outFilePath varchar(255)
	declare @inFilePath varchar(255)
	declare @predFilePath varchar(255)
	declare @jobStatsFilePath varchar(255)
	
	If Right(@outFileDir,1) <> '\'
		Set @outFileDir = @outFileDir + '\'
	If Right(@inFileDir,1) <> '\'
		Set @inFileDir = @inFileDir + '\'

	set @outFilePath = @outFileDir + @outFile
	Set @jobStatsFilePath = Replace(@outFilePath , '\peptideGANET_', '\jobStats_')

	set @inFilePath = @inFileDir + @inFile
	set @predFilePath = @inFileDir + @predFile

	-----------------------------------------------
	-- Delete the given files
	-----------------------------------------------

	DECLARE @FSOObject int
	DECLARE @TxSObject int
	DECLARE @hr int
	
	-- Create a FileSystemObject object.
	--
	EXEC @hr = sp_OACreate 'Scripting.FileSystemObject', @FSOObject OUT
	IF @hr <> 0
	BEGIN
	    EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
		set @myError = 60
		goto Done
	END

	EXEC @hr = sp_OAMethod  @FSOObject, 'DeleteFile', NULL, @outFilePath
	IF @hr <> 0
	BEGIN
	    EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
		set @myError = 60
	    goto DestroyFSO
	END

	EXEC @hr = sp_OAMethod  @FSOObject, 'DeleteFile', NULL, @jobStatsFilePath
	IF @hr <> 0
	BEGIN
	    EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
		set @myError = 60
	    goto DestroyFSO
	END
	
	EXEC @hr = sp_OAMethod  @FSOObject, 'DeleteFile', NULL, @inFilePath
	IF @hr <> 0
	BEGIN
	    EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
		set @myError = 60
	    goto DestroyFSO
	END

	EXEC @hr = sp_OAMethod  @FSOObject, 'DeleteFile', NULL, @predFilePath
	IF @hr <> 0
	BEGIN
	    EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
		set @myError = 60
	    goto DestroyFSO
	END

	-----------------------------------------------
	-- clean up file system object
	-----------------------------------------------
  
DestroyFSO:
	-- Destroy the FileSystemObject object.
	--
	EXEC @hr = sp_OADestroy @FSOObject
	IF @hr <> 0
	BEGIN
	    EXEC LoadGetOAErrorMessage @FSOObject, @hr, @message OUT
		set @myError = 60
		goto done
	END

	-----------------------------------------------
	-- Exit
	-----------------------------------------------
Done:	
	return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

