SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[ExportGANETData]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[ExportGANETData]
GO


CREATE Procedure dbo.ExportGANETData
/****************************************************
**
**	Desc: 
**		Calls MT_Main..GetGANETFolderPaths, then calls
**		ExportGANETPeptideFile to create the Peptide file,
**		  then creates the Job Stats file
**
**		Return values: 0: success, otherwise, error code
**
**		Parameters:
**
**		Auth:	mem
**		Date:	04/08/2005
**				12/02/2005 mem - Added brackets around @DBName as needed to allow for DBs with dashes in the name
**							   - Increased size of @DBName from 64 to 128 characters
**    
*****************************************************/
(
	@jobStatsFileName varchar(256) = 'jobStats.txt',
	@exportJobStatsFileOnly tinyint = 0,				-- When 1, then only creates the Job Stats file and does not call ExportGANETPeptideFile
	@message varchar(256)='' OUTPUT
)
As
	Set nocount on

	Declare @myRowCount int
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

	set @message = ''

	declare @dbname varchar(128)
	set @dbname = DB_NAME()

	declare @outFileName varchar(256)
	declare @outFileFolderPath varchar(256)
	declare @JobStatsFilePath varchar(512)

	declare @cmd varchar(512)
	declare @result int
		    
	--------------------------------------------------------------
	-- Get the file and folder paths
	--------------------------------------------------------------
	--
	exec @myError = MT_Main..GetGANETFolderPaths
							0,					-- 0 means running SP from local server; 1 means running SP from client
							@outFileName output,
							@outFileFolderPath  output,
							'',					-- inFileName
							'',					-- inFileFolderPath
							'',					-- predFileName
							@message output

	if @myError <> 0
		Goto Done

	--------------------------------------------------------------
	-- Possibly write out the peptides file
	--------------------------------------------------------------
	--
	If IsNull(@exportJobStatsFileOnly, 0) = 0
	Begin
		EXEC @result = ExportGANETPeptideFile @outFileFolderPath, @outFileName, @message OUTPUT
		Set @myError = @result
		--
		If @myError <> 0
			Goto Done
	End

	--------------------------------------------------------------
	-- Write out the job stats file
	--------------------------------------------------------------
	--
	Set @JobStatsFilePath = '"' + @outFileFolderPath + @dbname + '\' + @jobStatsFileName + '"'

	--------------------------------------------------------------
	-- dump the peptides into a temporary file
	--------------------------------------------------------------
	-- 
	Set @cmd = 'bcp "SELECT * FROM [' + @DBName + ']..V_MSMS_Analysis_Jobs" queryout ' + @JobStatsFilePath + ' -c -T'
	--
	EXEC @result = master..xp_cmdshell @cmd, NO_OUTPUT 
	Set @myError = @result
	--
	if @myError <> 0
	begin
		-- Error writing file
		Set @message = 'Error exporting data from V_MSMS_Analysis_Jobs to ' + @outFileFolderPath
		goto done
	end

	SET @message = 'Complete ExportGANET'
        
Done:
	return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

