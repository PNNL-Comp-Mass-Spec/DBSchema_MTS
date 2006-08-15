/****** Object:  StoredProcedure [dbo].[MakeNewORFDB] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.MakeNewORFDB
/****************************************************
**
**	Desc: Creates a new ORF database
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**		Auth: mem
**		Date: 04/29/2004
**			  04/30/2004 mem - updated call to sp_add_maintenance_plan_db to look up the GUID for the maintenance plan by name
**			  05/05/2004 mem - changed the order of the input parameters to put the @fastaFile parameters directly after @organism
**								  changed default value for @newDBNameRoot to 'SWTestORF'
**			  09/17/2004 mem - changed default @templateFilePath to proto-6\MTS_Backup\
**			  11/12/2004 mem - Added call to MTS_Master..MakeProvisionalProteinDB to obtain next available DB ID and Name
**			  12/13/2004 mem - Updated for use on Albert
**			  01/22/2005 mem - Now displaying @message if an error occurs
**			  07/01/2005 mem - Added parameter @logStoragePath to specify the location of the transaction log files
**			  08/11/2005 mem - Added output parameter @newDBName, placing it directly after @message
**							 - Reordered the parameters following @message to match the order used in MakeNewMassTagDB
**			  11/23/2005 mem - Added brackets around @newDBName as needed to allow for DBs with dashes in the name
**    
*****************************************************/
	@newDBNameRoot varchar(64) = 'Human',
	@newDBNameType char(1) = 'V',
	@description varchar(256) = 'Human ORF database',
	@organism varchar(64) = 'Human',
	@fastaFileName varchar(255) = '',			-- Optional, e.g. Human_2002-12-09.fasta
	@fastaFilePath varchar(255) = '',			-- Optional path, e.g. \\gigasax\DMS_Organism_Files\Human\FASTA\
	@message varchar(512) = '' output,
	@newDBName varchar(128) = '' output,
	@dbState int = 5,
	@dataStoragePath varchar(256) = 'F:\SQLServerData\',
	@logStoragePath varchar(256) = 'D:\SQLServerData\',
	@templateFilePath varchar(256) = '\\proto-6\MTS_Templates\ORF_Template_00\ORF_Template_00.bak'
AS
	SET NOCOUNT ON
	 
	declare @myError int
	set @myError = 0

	declare @myRowCount int
	set @myRowCount = 0
	
	set @message = ''
	declare @result int

   	---------------------------------------------------
	-- verify organism against DMS
	---------------------------------------------------

	Declare @matchCount int
	Set @matchCount = 0
		
	SELECT @matchCount = COUNT(*)
	FROM V_DMS_Organism_DB_File_Import
	WHERE Organism = @organism
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	If @myError <> 0 or @myRowCount <> 1
	Begin
		set @message = 'Error verifying organism against DMS organism list'
		set @myError = 101
		goto done
	End
	
	If @matchCount < 1
	Begin
		set @message = 'Organism "' + @organism + '" not found in DMS'
		set @myError = 102
		goto done
	End
	
	---------------------------------------------------
	-- Get name for new database by
	-- calling MakeProvisionalProteinDB in Pogo.MTS_Master
	---------------------------------------------------

	declare @newDBID int
	set @newDBID = 0
	
	set @newDBName = ''

	Exec @myError = Pogo.MTS_Master.dbo.MakeProvisionalProteinDB  
							@@SERVERNAME, 
							@newDBNameRoot, 
							@newDBNameType, 
							@newDBName = @newDBName OUTPUT, 
							@newDBID = @newDBID OUTPUT, 
							@message = @message OUTPUT
	--
	if @myError <> 0
	begin
		set @message = 'could not get new seqence number from MTS_Master'
		goto done
	end


  	---------------------------------------------------
	-- Create new ORF database
	---------------------------------------------------
	
	declare @dataFilePath varchar(256)
	declare @logFilePath varchar(256)
	set @dataFilePath = @dataStoragePath + @newDBName + '_data.mdf'
	set @logFilePath =  @logStoragePath + @newDBName + '_log.ldf'

	-- new ORF database is created by restore from
	-- a backup file that has been established as a
	-- template for new Peptide databases
	--
	RESTORE DATABASE @newDBName
	FROM DISK = @templateFilePath
	WITH RECOVERY,
		MOVE 'ORF_Template_00_dat' TO @dataFilePath, 
		MOVE 'ORF_Template_00_log' TO @logFilePath
	--
	Set @myError = @@Error
	
	if @myError <> 0
	begin
		set @Message = 'Error restoring ORF DB from ' + @templateFilePath + ' (Error number = ' + Convert(varchar(9), @myError) + ')'

		-- Remove the DB name from MTS_Master
		DELETE FROM Pogo.MTS_Master.dbo.T_MTS_Protein_DBs
		WHERE Protein_DB_ID = @newDBID

		Goto Done
	end
	
	set @message = 'Created: "' + @newDBName + '"'

   	---------------------------------------------------
	-- Make entry in MT Main tracking table
	---------------------------------------------------
	
	declare @provider varchar(256)
	set @provider = 'Provider=sqloledb;Data Source=' + Lower(@@ServerName) + ';Initial Catalog=' + @newDBName + ';User ID=mtuser;Password=mt4fun'
	
	declare @NetSqLProvider varchar(256)
	set @NetSqLProvider = 'Server=' + Lower(@@ServerName) + ';database=' + @newDBName + ';uid=mtuser;Password=mt4fun'

	declare @NetOleDBProvider varchar(256)
	set @NetOleDBProvider = @provider

	INSERT INTO T_ORF_Database_List
		(
		ODB_ID,
		ODB_Name, 
		ODB_Description, 
		ODB_Organism, 
		ODB_Connection_String, 
		ODB_NetSQL_Conn_String, 
		ODB_NetOleDB_Conn_String, 
		ODB_State,
		ODB_Created
		)
	VALUES 
		(
			@newDBID,
			@newDBName,
			@description,
			@organism, 
			@provider,
			@NetSqLProvider,
			@NetOleDBProvider,
			@dbState,
			GETDATE()
		)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'could not add new record to Orf DB list'
		goto done
	end


	---------------------------------------------------
	-- Optional: Update fasta file name in new ORF DB
	---------------------------------------------------
	declare @S nvarchar(1024)

	set @S = N''
	set @S = @S + 'DELETE FROM [' + @newDBName + ']..T_ORF_Organism_DB_File'
	exec @result = sp_executesql @S	

	Set @fastaFileName = IsNull(@fastaFileName, '')
	Set @fastaFilePath = IsNull(@fastaFilePath, '')

	set @S = N''
	set @S = @S + 'INSERT INTO [' + @newDBName + ']..T_ORF_Organism_DB_File(Organism_DB_File_Name,Organism_DB_Path,Organism) '
	set @S = @S + 'VALUES('
	set @S = @S + '''' + @fastaFileName + ''', '
	set @S = @S + '''' + @fastaFilePath + ''', '
	set @S = @S + '''' + @organism + ''''
	set @S = @S + ') '
	exec @result = sp_executesql @S	


   	---------------------------------------------------
	-- add new database to maintenance plan for ORF DB's
	---------------------------------------------------

	Declare @DBMaintPlanName varchar(128)
	Declare @planID as UniqueIdentifier
	
	Set @DBMaintPlanName = 'DB Maintenance Plan - ORF databases'
	Set @planID = '{00000000-0000-0000-0000-000000000000}'

	SELECT @planID = plan_ID
	FROM msdb..sysdbmaintplans
	WHERE plan_name = @DBMaintPlanName

	If @planID <> '{00000000-0000-0000-0000-000000000000}'
		Execute	msdb..sp_add_maintenance_plan_db @planID, @newDBName
	Else
	Begin
		Set @message = 'Database maintenance plan ''' + @DBMaintPlanName + ''' not found in msdb..sysdbmaintplans'
		Exec PostLogEntry 'Error', @message, 'MakeNewORFDB'
	End


	---------------------------------------------------
	-- Update MTUser and MTAdmin permissions for Albert
	-- need to revoke and grant MTUser and MTAdmin since
	-- the template DB has the Pogo versions of those users
	-- embedded in it, and we need to add the Albert versions
	---------------------------------------------------

	Declare @sql varchar(1024)	
	Set @sql = 'exec [' + @newDBName + '].dbo.UpdateUserPermissions'
	Exec (@sql)
	

	---------------------------------------------------
	-- Force an update of the DB states in Pogo.MTS_Master
	---------------------------------------------------
	
	Exec @myError = Pogo.MTS_Master.dbo.UpdateDatabaseStates

	
   	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	If @myError <> 0
		Select @message as Message
		
	return @myError


GO
GRANT EXECUTE ON [dbo].[MakeNewORFDB] TO [DMS_SP_User]
GO
