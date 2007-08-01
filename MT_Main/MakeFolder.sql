/****** Object:  StoredProcedure [dbo].[MakeFolder] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
Create Procedure MakeFolder
/****************************************************
** 
**		Desc: 
**		create a folder on the file system from
**
**		Return values: 0: success, otherwise, error code
** 
**		Parameters:
**			@folderPath	- full path to new folder
** 
**		Auth: grk
**		Date: 12/11/2002
**    
*****************************************************/
	@folderPath varchar(255) = ''
As
	set nocount on 
	
	declare @myError int		-- internal error status
	set @myError = 0
	
	declare @result int			-- receive return status of procedure
	declare @cmd varchar(255)	-- string to contain external command
	
	-- define external command to make the folder
	--
	set @cmd = 'mkdir "' + @folderPath + '"'
	
	-- execute command string as external program
	--
	EXEC @result = master..xp_cmdshell @cmd, NO_OUTPUT 

	set @myError = @result
	return  @myError 
GO
GRANT EXECUTE ON [dbo].[MakeFolder] TO [DMS_SP_User]
GO
