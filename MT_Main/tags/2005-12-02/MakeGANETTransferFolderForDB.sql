SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[MakeGANETTransferFolderForDB]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[MakeGANETTransferFolderForDB]
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
**		Auth: mem
**		Date: 09/22/2004
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
	SELECT	@GANETRootPath = Server_Path
	FROM	T_Folder_Paths
	WHERE	([Function] = 'GANET Transfer Root Folder')
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'error looking up GANETRootPath'
		goto done
	end

	
	if @GANETRootPath = ''
		begin
			set @message = 'valid GANETRootPath could not be found'
			goto done
		end

	---------------------------------------------------
	-- create directories for GANet files
	---------------------------------------------------
	
	declare @path varchar(256)
	
	set @path = @GANETRootPath + 'In\' + @DBName
	exec @myError = MakeFolder @path
	
	set @path = @GANETRootPath + 'Out\' + @DBName
	exec @myError = MakeFolder @path

Done:
	return @myError
GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

