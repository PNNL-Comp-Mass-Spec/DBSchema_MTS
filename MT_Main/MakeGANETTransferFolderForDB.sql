/****** Object:  StoredProcedure [dbo].[MakeGANETTransferFolderForDB] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE MakeGANETTransferFolderForDB
/****************************************************
**
**	Desc: 
**		Creates a transfer folder for GANET results
**		for the given database
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	09/22/2004
**			07/18/2006 mem - Updated to use udfCombinePaths and ValidateFolderExists
**    
*****************************************************/
	@DBName varchar(128) = '',
	@message varchar(512) output

AS

	set nocount on
	
	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @GANETRootPath varchar(256)
	set @GANETRootPath = ''

	--------------------------------------------------
	-- Get directory for GANET files
	---------------------------------------------------
	Set @myError = ''
	SELECT @GANETRootPath = Server_Path
	FROM T_Folder_Paths
	WHERE [Function] = 'GANET Transfer Root Folder'
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	If @myError <> 0
	Begin
		set @message = 'Error looking up "GANET Transfer Root Folder" in table T_Folder_Paths'
		Goto Done
	End
	Else
	If @myRowCount <> 1
	Begin
		set @message = 'Could not find entry "GANET Transfer Root Folder" in table T_Folder_Paths'
		set @myError = 110
		Goto Done
	End
	
	---------------------------------------------------
	-- Create the NET transfer folders
	---------------------------------------------------
	
	declare @FolderPath varchar(256)
	
	set @FolderPath = dbo.udfCombinePaths(dbo.udfCombinePaths(@GANETRootPath, 'In'), @DBName)
	exec @myError = ValidateFolderExists @FolderPath, @CreateIfMissing = 1, @message = @message output
	
	If @myError <> 0
	Begin
		if Len(IsNull(@message, '')) = 0
			Set @message = 'Error verifying that the NET transfer input folder exists: ' + IsNull(@FolderPath, '??')
		else
			Set @message = @message + ' (NET transfer input folder)'
			
		Set @myError = 111
		Goto Done
	End

	set @FolderPath = dbo.udfCombinePaths(dbo.udfCombinePaths(@GANETRootPath, 'Out'), @DBName)
	exec @myError = ValidateFolderExists @FolderPath, @CreateIfMissing = 1, @message = @message output
	
	If @myError <> 0
	Begin
		if Len(IsNull(@message, '')) = 0
			Set @message = 'Error verifying that the NET transfer output folder exists: ' + IsNull(@FolderPath, '??')
		else
			Set @message = @message + ' (NET transfer output folder)'
			
		Set @myError = 112
		Goto Done
	End

Done:
	return @myError
GO
GRANT VIEW DEFINITION ON [dbo].[MakeGANETTransferFolderForDB] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[MakeGANETTransferFolderForDB] TO [MTS_DB_Lite] AS [dbo]
GO
