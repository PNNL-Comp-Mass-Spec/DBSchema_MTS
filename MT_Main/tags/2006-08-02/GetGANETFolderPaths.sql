SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[GetGANETFolderPaths]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[GetGANETFolderPaths]
GO


CREATE PROCEDURE dbo.GetGANETFolderPaths
/****************************************************
** 
**	Desc:	Get paths to GANET transfer folder
**	
**	Return values: 0: success, otherwise, error code
** 
**	Auth:	grk
**	Date:	08/26/2003
**			04/08/2005 mem - removed @dbName parameter since unused
**			11/28/2005 mem - Now verifying that @rootFolderPath ends in a slash before concatenating subfolders to it
**						   - Now checking for no match found in T_Folder_Paths for 'GANET Transfer Root Folder', and posting entry to error log if not found
**			07/20/2006 mem - Updated to use dbo.udfCombinePaths
**    
*****************************************************/
(
	@clientPerspective int = 1,					-- 0 means running SP from local server; 1 means running SP from client
	@outFileName varchar(256)='' output,
	@outFileFolderPath varchar(256)='' output,
	@inFileName varchar(256)='' output,
	@inFileFolderPath varchar(256)='' output,
	@predFileName varchar(256)='' output,
	@message varchar(512)='' output
)
AS
	set nocount on

	declare @myError int
	set @myError = 0

	declare @myRowCount int
	set @myRowCount = 0

	set @message = ''
	
	---------------------------------------------------
	-- Get root folder path for GANET transfer folder
	---------------------------------------------------
	
	declare @clientRoot varchar(256)
	declare @serverRoot varchar(256)
	
	SELECT @clientRoot = Client_Path, @serverRoot = Server_Path
	FROM T_Folder_Paths
	WHERE ([Function] = 'GANET Transfer Root Folder')
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 
	begin
		set @message = 'Error looking up GANET transfer path in T_Folder_Paths; Error ' + Convert(varchar(9), @myError)
		execute PostLogEntry 'Error', @message, 'GetGANETFolderPaths'
		goto Done
	end

	if @myRowCount = 0
	begin
		set @message = 'Entry not found for ''GANET Transfer Root Folder'' in T_Folder_Paths'
		execute PostLogEntry 'Error', @message, 'GetGANETFolderPaths'
		set @myError = 50000
		goto Done
	end

    ---------------------------------------------------
	-- Build paths from root
	---------------------------------------------------

	set @outFileName = 'peptideGANET.txt' -- where MTDB puts peptide data file
	set @inFileName = 'JobGANETs.txt' -- where GANET program puts job results
	set @predFileName = 'PredictGANETs.txt' -- where GANET program puts predicted results

	declare @rootFolderPath varchar(256)
	
	if @clientPerspective > 0
		set @rootFolderPath = @clientRoot
	else
		set @rootFolderPath = @serverRoot
	
	set @outFileFolderPath = dbo.udfCombinePaths(@rootFolderPath, 'Out\')
	set @inFileFolderPath = dbo.udfCombinePaths(@rootFolderPath, 'In\' )

    ---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[GetGANETFolderPaths]  TO [DMS_SP_User]
GO

