SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[MakeNewPeptideDB]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[MakeNewPeptideDB]
GO


CREATE PROCEDURE MakeNewPeptideDB
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
**						   - Now checking the Sql Server version; If Sql Server 2005, then not attempting to update any maintenance plans, and instead posting an error message to the log since DBs are currently not auto-added to the appropriate maintenance plan
**			07/27/2006 mem - Updated to use @OrganismDBFileList to also populate Protein_Collection_Filter
**    
*****************************************************/
(
	@newDBNameRoot varchar(64) = 'SWTestPeptide',
	@newDBNameType char(1) = 'A',
	@description varchar(256) = 'Main database for Borrelia',
	@organism varchar(64) = 'Borrelia',
	@OrganismDBFileList varchar(1024) = '',				-- Optional, comma separated list of fasta files or comma separated list of protein collection names; e.g. 'PCQ_ETJ_2004-01-21.fasta,PCQ_ETJ_2004-01-21'
	@message varchar(512) = '' output,
	@templateFilePath varchar(256) = '\\proto-1\DB_Backups\MTS_Templates\PT_Template_01\PT_Template_01.bak',
	@dataStoragePath varchar(256) = '',					-- If blank (or If @logStoragePath is blank), then will lookup in T_Folder_Paths
	@logStoragePath varchar(256) = '',					-- If blank (or If @dataStoragePath is blank), then will lookup in T_Folder_Paths
	@dbState int = 1
)
AS
	Set nocount on

	declare @myError int
	declare @myRowCount int
	Set @myError = 0
	Set @myRowCount = 0
	
	Set @message = ''

	declare @result int

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
	Set @dataStoragePath = LTrim(RTrim(IsNull(@dataStoragePath, '')))
	Set @logStoragePath = LTrim(RTrim(IsNull(@logStoragePath, '')))

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
		Set @message = 'Database ' + @newDBName + ' needs to be added to a database maintenance plan'
		Exec PostLogEntry 'Error', @message, 'MakeNewPeptideDB'
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
	Declare @sql varchar(1024)
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
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO
