/****** Object:  StoredProcedure [dbo].[GetPeptideProphetFolderPaths] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.GetPeptideProphetFolderPaths
/****************************************************
** 
**	Desc:	Get paths to the Peptide Prophpet transfer folder
**
**	Return values: 0: success, otherwise, error code
** 
**	Parameters:
**
**	Auth: 	mem
**	Date: 	07/03/2006
**    
*****************************************************/
(
	@clientPerspective int = 1,					-- 0 means running SP from local server; 1 means running SP from client
	@TransferFolderPath varchar(256) output,
	@JobListFileName varchar(256)='' output,
	@ResultsFileName varchar(256)='' output,
	@message varchar(512)='' output
)
AS
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0
	
	set @message = ''
	
	---------------------------------------------------
	-- Get root folder path for the Peptide Prophet transfer folder
	---------------------------------------------------
	
	declare @clientRoot varchar(256)
	declare @serverRoot varchar(256)
	
	SELECT @clientRoot = Client_Path, @serverRoot = Server_Path
	FROM T_Folder_Paths
	WHERE ([Function] = 'Peptide Prophet Transfer Root Folder')
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 
	begin
		set @message = 'Error looking up peptide prophet transfer path in T_Folder_Paths; Error ' + Convert(varchar(9), @myError)
		execute PostLogEntry 'Error', @message, 'GetPeptideProphetFolderPaths'
		goto Done
	end

	if @myRowCount = 0
	begin
		set @message = 'Entry not found for ''eptide Prophet Transfer Root Folder'' in T_Folder_Paths'
		execute PostLogEntry 'Error', @message, 'GetPeptideProphetFolderPaths'
		set @myError = 50000
		goto Done
	end
	
    ---------------------------------------------------
	-- Define @TransferFolderPath
	---------------------------------------------------

	if @clientPerspective > 0
		set @TransferFolderPath = @clientRoot
	else
		set @TransferFolderPath = @serverRoot
	
	If Right(@TransferFolderPath, 1) <> '\'
		Set @TransferFolderPath = @TransferFolderPath + '\'

    ---------------------------------------------------
	-- Define the default filenames
	---------------------------------------------------

	set @JobListFileName = 'PeptideProphet_JobList.txt'
	set @ResultsFileName = 'PeptideProphet_Results.txt'

    ---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[GetPeptideProphetFolderPaths] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetPeptideProphetFolderPaths] TO [MTS_DB_Lite] AS [dbo]
GO
