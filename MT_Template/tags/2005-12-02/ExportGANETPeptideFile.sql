SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[ExportGANETPeptideFile]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[ExportGANETPeptideFile]
GO


CREATE Procedure dbo.ExportGANETPeptideFile
/****************************************************
**
**	Desc: 
**		Creates a flat file containing peptide records
**		for GA NET external program
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**		Auth:	grk
**		Date:	04/03/2002
**				09/22/2004 mem - Updated to use the T_Score tables and changed output filename from pep_temp to temp_peptides
**				01/23/2005 mem - Moved the output file deletion command to occur after the bulk copy command finishes
**				12/02/2005 mem - Added brackets around @DBName as needed to allow for DBs with dashes in the name
**							   - Increased size of @DBName from 64 to 128 characters
**    
*****************************************************/
(
	@outFileDir varchar(256) = 'F:\GA_Net_Xfer\Out\',
	@outFileName varchar(256) = 'peptideGANET.txt',
	@message varchar(256)='' OUTPUT
)
As
	Set nocount on
	
	Declare @myRowCount int
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

	Set @message = ''

	declare @DBName varchar(128)
	set @DBName = DB_NAME()
	
	declare @pepFilePath varchar(512)
	Set @pepFilePath = '"' + @outFileDir + @DBName + '\' + 'temp_peptides"'

	declare @outFilePath varchar(512)

	declare @cmd varchar(512)
	declare @result int

	declare @lockerCount varchar(12)

	--------------------------------------------------------------
	-- build output file path
	--------------------------------------------------------------

	Set @outFilePath = '"' + @outFileDir + @DBName + '\' + @outFileName + '"'
	
	--------------------------------------------------------------
	-- get the count of peptide lockers
	--------------------------------------------------------------

	-- (future:)
	Set @lockerCount = '0'

	--------------------------------------------------------------
	-- dump the peptide lockers into a temporary file
	--------------------------------------------------------------
	--
	-- (future:)

	--------------------------------------------------------------
	-- dump the peptides into a temporary file
	--------------------------------------------------------------
	-- 
	Set @cmd = 'bcp "SELECT * FROM [' + @DBName + ']..V_GANET_Peptides" queryout ' + @pepFilePath + ' -c -T'
	--
	EXEC @result = master..xp_cmdshell @cmd, NO_OUTPUT 
	Set @myError = @result
	--
	if @myError <> 0
	begin
		-- Error writing file
		Set @message = 'Error exporting data from V_GANET_Peptides to ' + @outFilePath
		goto done
	end

	--------------------------------------------------------------
	-- Make sure @outFilePath does not exist, deleting it if present
	--------------------------------------------------------------
	--
	Set @cmd = 'del ' + @outFilepath
	--
	-- @result will be 1 if @outFilepath didn't exist; that's ok
	EXEC @result = master..xp_cmdshell @cmd, NO_OUTPUT 
	
	--------------------------------------------------------------
	-- create output file and put first line 
	-- (containing locker row count) into it
	--------------------------------------------------------------
	--
	Set @cmd = 'echo ' + @lockerCount + ' > ' + @outFilePath
	--
	EXEC @result = master..xp_cmdshell @cmd, NO_OUTPUT 
	Set @myError = @result

	--------------------------------------------------------------
	-- append the peptide lockers to the output
	--------------------------------------------------------------
	--
	-- (future:)

	--------------------------------------------------------------
	-- append the peptides file to the output file
	--------------------------------------------------------------
	--
	Set @cmd = 'type ' + @pepFilePath + ' >> ' + @outFilePath
	--
	EXEC @result = master..xp_cmdshell @cmd, NO_OUTPUT 
	Set @myError = @result

	--------------------------------------------------------------
	-- get rid of temporary peptide file
	--------------------------------------------------------------
	--
	Set @cmd = 'del ' + @pepFilePath
	--
	EXEC @result = master..xp_cmdshell @cmd, NO_OUTPUT 
	Set @myError = @result
	
Done:
	
	return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

