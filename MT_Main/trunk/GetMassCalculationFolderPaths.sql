SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[GetMassCalculationFolderPaths]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[GetMassCalculationFolderPaths]
GO


CREATE PROCEDURE dbo.GetMassCalculationFolderPaths
/****************************************************
** 
**		Desc: 
**		Get paths to Mass Calculation transfer folder
**
**		Return values: 0: success, otherwise, error code
** 
**		Parameters:
**
**		Auth: mem
**		Date: 11/28/2005
**    
*****************************************************/
(
	@clientPerspective int = 1,					-- 0 means running SP from local server; 1 means running SP from client
	@SequencesFileName varchar(256) output,
	@SequenceModsFilename varchar(256) output,
	@SourceDataFolderPath varchar(256) output,
	@ResultsFileName varchar(256) output,
	@ResultsFolderPath varchar(256) output,
	@message varchar(512) output
)
AS
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0
	
	set @message = ''
	
	---------------------------------------------------
	-- Get root folder path for Mass Calculation transfer folder
	---------------------------------------------------
	
	declare @clientRoot varchar(256)
	declare @serverRoot varchar(256)
	
	SELECT @clientRoot = Client_Path, @serverRoot = Server_Path
	FROM T_Folder_Paths
	WHERE ([Function] = 'Mass Calculation Transfer Root Folder')
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 
	begin
		set @message = 'Error looking up mass calculation transfer path in T_Folder_Paths; Error ' + Convert(varchar(9), @myError)
		execute PostLogEntry 'Error', @message, 'GetMassCalculationFolderPaths'
		goto Done
	end

	if @myRowCount = 0
	begin
		set @message = 'Entry not found for ''Mass Calculation Transfer Root Folder'' in T_Folder_Paths'
		execute PostLogEntry 'Error', @message, 'GetMassCalculationFolderPaths'
		set @myError = 50000
		goto Done
	end
	
    ---------------------------------------------------
	-- Build paths from root
	---------------------------------------------------

	set @SequencesFileName = 'SequenceInfo.txt'
	set @SequenceModsFilename = 'SequenceMods.txt'
	set @ResultsFileName = 'SequenceResults.txt'

	declare @rootFolderPath varchar(256)
	
	if @clientPerspective > 0
		set @rootFolderPath = @clientRoot
	else
		set @rootFolderPath = @serverRoot
	
	If Right(@rootFolderPath, 1) <> '\'
		Set @rootFolderPath = @rootFolderPath + '\'
		
	set @SourceDataFolderPath = @rootFolderPath + 'Out\' 
	set @ResultsFolderPath = @rootFolderPath + 'In\' 

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

GRANT  EXECUTE  ON [dbo].[GetMassCalculationFolderPaths]  TO [DMS_SP_User]
GO

