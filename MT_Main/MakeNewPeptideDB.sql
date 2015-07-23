/****** Object:  StoredProcedure [dbo].[MakeNewPeptideDB] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure MakeNewPeptideDB
/****************************************************
**
**	Desc: Creates a new peptide database
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	grk
**	Date:	12/16/2002 
**			03/16/2004 grk - changed default @dataStoragePath to G: drive
**			04/28/2004 grk - changed default @templateFilePath to proto-5
**			04/30/2004 mem - updated call to sp_add_maintenance_plan_db to look up the GUID for the maintenance plan by name
**			05/05/2004 mem - added @OrganismDBFileList parameter
**							  changed default value for @newDBNameRoot to 'SWTestPeptide'
**			08/29/2004 mem - changed default @templateFilePath to PT_Template_01 and added creation of GANET transfer folders
**			09/17/2004 mem - changed default @templateFilePath to proto-6\MTS_Backup\
**			11/12/2004 mem - Added call to MTS_Master.dbo.MakeProvisionalPeptideDB to obtain next available DB ID and Name
**			12/07/2004 mem - Updated for use on Albert
**			01/22/2005 mem - Now displaying @message If an error occurs
**			03/07/2005 mem - Switched to using AddUpdateConfigEntry to populate T_Process_Config with the values in @OrganismDBFileList
**			07/01/2005 mem - Added parameter @logStoragePath to specify the location of the transaction log files
**			10/10/2005 mem - Updated Maintenance Plan name to 'DB Maintenance Plan - PT DB Backup, Part 1' ; previously, was 'DB Maintenance Plan - PT databases'
**			10/22/2005 mem - Now also adding new database to Maintenance Plan 'DB Maintenance Plan - PT databases'
**			11/23/2005 mem - Added brackets around @newDBName as needed to allow for DBs with dashes in the name
**			07/18/2006 mem - Now using V_DMS_Organism_List_Report to confirm @organism
**						   - Updated @dataStoragePath and @logStoragePath to be blank by default, which results in looking up the paths in T_Folder_Paths
**						   - Removed addition to the 'DB Maintenance Plan - PT DB Backup' maintenance plan since DB backups are now performed by SP Backup_MTS_DBs
**			07/27/2006 mem - Updated to use @OrganismDBFileList to also populate Protein_Collection_Filter
**			08/26/2006 mem - Now checking the Sql Server version; if Sql Server 2005, then not attempting to update any maintenance plans since SSIS handles DB integrity checks and backups
**			08/31/2006 mem - Now updating Last_Affected in T_Process_Config & T_Process_Step_Control in the newly created database
**			11/29/2006 mem - Added parameter @InfoOnly
**			03/24/2008 mem - Changed value for @dbState from 1 to 5
**			04/23/2013 mem - Now adding the new database to the DatabaseSettings table in the dba database
**			05/28/2013 mem - Now setting LogFileAlerts to 0 when adding new databases to the DatabaseSettings table in the dba database
**			04/14/2014 mem - Now checking for the name containing a space or carriage return	
**			07/21/2015 mem - Switched to using ScrubWhitespace to remove whitespace (including space, tab, and carriage return)
**    
*****************************************************/
(
	@newDBNameRoot varchar(64) = 'SWTestPeptide',
	@newDBNameType char(1) = 'A',
	@description varchar(256) = 'Main database for Borrelia',
	@organism varchar(64) = 'Borrelia',
	@OrganismDBFileList varchar(1024) = '',		-- Optional, comma separated list of fasta files or comma separated list of protein collection names; e.g. 'PCQ_ETJ_2004-01-21.fasta,PCQ_ETJ_2004-01-21'
	@message varchar(512) = '' output,
	@templateFilePath varchar(256) = '\\proto-1\DB_Backups\MTS_Templates\PT_Template_01\PT_Template_01.bak',
	@dataStoragePath varchar(256) = '',			-- If blank (or If @logStoragePath is blank), then will lookup in T_Folder_Paths
	@logStoragePath varchar(256) = '',			-- If blank (or If @dataStoragePath is blank), then will lookup in T_Folder_Paths
	@dbState int = 5,
	@InfoOnly tinyint = 0						-- Set to 1 to validate the inputs and preview the values that will be used to create the new database
)
AS
	Set nocount on

	declare @myError int
	declare @myRowCount int
	Set @myError = 0
	Set @myRowCount = 0
	
	Set @message = ''

	declare @result int

	Declare @sql varchar(1024)

	---------------------------------------------------
	-- Check for invalid characters in @newDBNameRoot
	---------------------------------------------------
	
	Set @newDBNameRoot = dbo.ScrubWhitespace(IsNull(@newDBNameRoot, ''))
	
	Exec @myError = ValidateDBName @newDBNameRoot, @message output
	
	If @myError <> 0
		Goto Done
	
	Set @organism = dbo.ScrubWhitespace(IsNull(@organism, ''))
	
	Set @OrganismDBFileList = dbo.ScrubWhitespace(IsNull(@OrganismDBFileList, ''))
	
   	---------------------------------------------------
	-- Verify organism against DMS
	---------------------------------------------------

	Declare @matchCount int
	Set @matchCount = 0
		
	SELECT @matchCount = COUNT(*)
	FROM V_DMS_Organism_List_Report
	WHERE [Name] = @organism
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--	
	If @myError <> 0
	Begin
		Set @message = 'Error verifying organism against V_DMS_Organism_List_Report'
		goto done
	End
	
	If @matchCount < 1
	Begin
		Set @message = 'Organism "' + @organism + '" not found in V_DMS_Organism_List_Report'
		Set @myError = 102
		goto done
	End

	---------------------------------------------------
	-- Populate @dataStoragePath and @logStoragePath If required
	---------------------------------------------------
	Set @dataStoragePath = dbo.ScrubWhitespace(IsNull(@dataStoragePath, ''))
	Set @logStoragePath = dbo.ScrubWhitespace(IsNull(@logStoragePath, ''))

	If Len(@dataStoragePath) = 0 Or Len(@logStoragePath) = 0
	Begin
		Set @dataStoragePath = ''
		SELECT @dataStoragePath = Server_Path
		FROM T_Folder_Paths
		WHERE [Function] = 'Default Database Folder'
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		If @myError <> 0
		Begin
			Set @message = 'Error looking up "Default Database Folder" in table T_Folder_Paths'
			Set @myError = 103
			goto done
		End
		Else
		If @myRowCount <> 1
		Begin
			Set @message = 'Could not find entry "Default Database Folder" in table T_Folder_Paths'
			Set @myError = 104
			goto done
		End
			
		Set @logStoragePath = ''
		SELECT @logStoragePath = Server_Path
		FROM T_Folder_Paths
		WHERE [Function] = 'Default Database Transaction Log Folder'
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myError <> 0
		Begin
			Set @message = 'Error looking up "Default Database Transaction Log Folder" in table T_Folder_Paths'
			Set @myError = 105
			goto done
		End
		Else
		If @myRowCount <> 1
		Begin
			Set @message = 'Could not find entry "Default Database Transaction Log Folder" in table T_Folder_Paths'
			Set @myError = 106
			goto done
		End
	End

	If @InfoOnly <> 0
	Begin
		SELECT	@newDBNameRoot AS DB_Name_Root, 
				@newDBNameType AS DB_Name_Type, 
				@description AS Description, 
				@Organism AS Organism, 
				@OrganismDBFileList AS Organism_DB_or_Protein_Collection_List,
				@dataStoragePath AS Data_Storage_Path,
				@logStoragePath AS Log_Storage_Path
		GOTO Done
	End

	
	---------------------------------------------------
	-- Get name for new database by
	-- calling MakeProvisionalPeptideDB in Pogo.MTS_Master
	---------------------------------------------------

	declare @newDBID int
	Set @newDBID = 0
	
	declare @newDBName varchar(128)
	Set @newDBName = ''

	Set @myError = -9999
	Exec @myError = Pogo.MTS_Master.dbo.MakeProvisionalPeptideDB 
							@@SERVERNAME, 
							@newDBNameRoot, 
							@newDBNameType, 
							@newDBName = @newDBName OUTPUT, 
							@newDBID = @newDBID OUTPUT, 
							@message = @message OUTPUT
	--
	If @myError <> 0
	Begin
		If @myError = -9999
			Set @message = 'Error calling procedure Pogo.MTS_Master.dbo.MakeProvisionalPeptideDB; either the server and database are not available or a permissions error occurred'
		Else		
			Set @message = 'Could not get new database ID from MTS_Master'
		Goto done
	End


   	---------------------------------------------------
	-- Create new Peptide database 
	---------------------------------------------------
	
	declare @dataFilePath varchar(256)
	declare @logFilePath varchar(256)
	Set @dataFilePath = dbo.udfCombinePaths(@dataStoragePath, @newDBName + '_data.mdf')
	Set @logFilePath =  dbo.udfCombinePaths(@logStoragePath,  @newDBName + '_log.ldf')

	-- new Peptide database is created by restore from
	-- a backup file that has been established as a
	-- template for new Peptide databases
	--
	RESTORE DATABASE @newDBName
	FROM DISK = @templateFilePath
	WITH RECOVERY,
		MOVE 'PT_Template_01_dat' TO @dataFilePath, 
		MOVE 'PT_Template_01_log' TO @logFilePath
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	If @myError <> 0
	Begin
		Set @Message = 'Error restoring Peptide DB from ' + @templateFilePath + ' (Error number = ' + Convert(varchar(9), @myError) + ')'

		-- Remove the DB name from MTS_Master
		DELETE FROM Pogo.MTS_Master.dbo.T_MTS_Peptide_DBs
		WHERE Peptide_DB_ID = @newDBID

		Goto Done
	End


	---------------------------------------------------
	-- Make entry in MT Main tracking table
	---------------------------------------------------
	
	declare @provider varchar(256)
	Set @provider = 'Provider=sqloledb;Data Source=' + Lower(@@ServerName) + ';Initial Catalog=' + @newDBName + ';User ID=mtuser;Password=mt4fun'

	declare @NetSqLProvider varchar(256)
	Set @NetSqLProvider = 'Server=' + Lower(@@ServerName) + ';database=' + @newDBName + ';uid=mtuser;Password=mt4fun'

	declare @NetOleDBProvider varchar(256)
	Set @NetOleDBProvider = @provider

	
	INSERT INTO T_Peptide_Database_List (
		PDB_ID,
		PDB_Name, 
		PDB_Description, 
		PDB_Organism, 
		PDB_Connection_String, 
		PDB_NetSQL_Conn_String, 
		PDB_NetOleDB_Conn_String, 
		PDB_State,
		PDB_Created,
		PDB_Import_Holdoff,
		PDB_Demand_Import
		)
	VALUES (
			@newDBID,
			@newDBName,
			@description,
			@organism, 
			@provider,
			@NetSqLProvider,
			@NetOleDBProvider,
			@dbState,
			GETDATE(),
			24,
			0
		)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	If @myError <> 0
	Begin
		Set @message = 'Could not add new row to T_Peptide_Database_List'
		goto done
	End

	---------------------------------------------------
	-- Update the Last_Affected column in T_Process_Config
	-- Leave Entered_By unchanged
	---------------------------------------------------
	Set @sql = ''
	Set @sql = @sql + ' UPDATE [' + @newDBName + '].dbo.T_Process_Config'
	Set @sql = @sql + ' SET Last_Affected = GetDate()'
	Exec (@sql)

	---------------------------------------------------
	-- Update the Last_Affected column in T_Process_Step_Control
	-- Leave Entered_By unchanged
	---------------------------------------------------
	Set @sql = ''
	Set @sql = @sql + ' UPDATE [' + @newDBName + '].dbo.T_Process_Step_Control'
	Set @sql = @sql + ' SET Last_Affected = GetDate()'
	Exec (@sql)


	---------------------------------------------------
	-- Make sure that GANET transfer folders exist
	---------------------------------------------------
	Exec @result = MakeGANETTransferFolderForDB @newDBName, @message output


	---------------------------------------------------
	-- Determine whether or not we're running Sql Server 2005 or newer
	---------------------------------------------------
	Declare @VersionMajor int
	
	exec GetServerVersionInfo @VersionMajor output

	If @VersionMajor = 8
	Begin
		-- Sql Server 2000
		
		---------------------------------------------------
		-- add new database to maintenance plan for Peptide DB's
		---------------------------------------------------

		Declare @DBMaintPlanName varchar(128)
		Declare @planID as UniqueIdentifier
		
		Set @DBMaintPlanName = 'DB Maintenance Plan - PT databases'
		Set @planID = '{00000000-0000-0000-0000-000000000000}'

		SELECT @planID = plan_ID
		FROM msdb.dbo.sysdbmaintplans
		WHERE plan_name = @DBMaintPlanName

		If @planID <> '{00000000-0000-0000-0000-000000000000}'
			Execute	msdb.dbo.sp_add_maintenance_plan_db @planID, @newDBName
		Else
		Begin
			Set @message = 'Database maintenance plan ''' + @DBMaintPlanName + ''' not found in msdb.dbo.sysdbmaintplans'
			Exec PostLogEntry 'Error', @message, 'MakeNewPeptideDB'
		End
	End
	Else
	Begin
		-- Nothing to do since we're using SSIS to call SPs CheckMTSDBs & BackupMTSDBs 
		--  on Sql Server 2005 for integrity checking and DB backup
		Set @myError = 0
	End	


	---------------------------------------------------
	-- Optional: Populate the T_Process_Config table with @OrganismDBFileList
	---------------------------------------------------

	If Len(IsNull(@OrganismDBFileList, '')) > 0
	Begin
		Exec @myError = ConfigureOrganismDBFileFilters @newDBName, @OrganismDBFileList, @message = @message output
		
		If @myError <> 0
		Begin
			If Len(IsNull(@message, '')) = 0
				Set @message = 'Error calling ConfigureOrganismDBFileFilters with @OrganismDBFileList = ' + IsNull(@OrganismDBFileList, '')
			goto done
		End
	End

	---------------------------------------------------
	-- Update MTUser and MTAdmin permissions for Albert
	-- need to revoke and grant MTUser and MTAdmin since
	-- the template DB has the Pogo versions of those users
	-- embedded in it, and we need to add the Albert versions
	---------------------------------------------------
	Set @sql = 'exec [' + @newDBName + '].dbo.UpdateUserPermissions'
	Exec (@sql)


	---------------------------------------------------
	-- Force an update of the DB states in Pogo.MTS_Master
	---------------------------------------------------
	Set @myError = -9999
	Exec @myError = Pogo.MTS_Master.dbo.UpdateDatabaseStates
	--
	If @myError <> 0
	Begin
		If @myError = -9999
			Set @message = 'Error calling procedure Pogo.MTS_Master.dbo.UpdateDatabaseStates; either the server and database are not available or a permissions error occurred'
		Else		
			Set @message = 'Could not get new database ID from MTS_Master'
		Goto done
	End

	---------------------------------------------------
	-- Add the database to the dbalerts database
	---------------------------------------------------
	--
	If Exists (select * from sys.databases where name = 'dba')
	Begin
	
		If Not Exists ( SELECT *
		                FROM dba.dbo.DatabaseSettings
		                WHERE (DBName = @newDBName) )
		Begin
		    INSERT INTO dba.dbo.DatabaseSettings( [DBName],
		                                          SchemaTracking,
		                                          LogFileAlerts,
		                                          LongQueryAlerts,
		                                          Reindex )
		    VALUES(@NewDBName, 1, 0, 1, 0)
		End
	End

	Set @message = 'Created "' + @newDBName + '"'
	
   	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	If @myError <> 0
		Select @message as Message, @myError as ErrorCode
		
	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[MakeNewPeptideDB] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[MakeNewPeptideDB] TO [MTS_DB_Lite] AS [dbo]
GO
