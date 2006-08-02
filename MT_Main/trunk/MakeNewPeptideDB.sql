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
**		Auth: grk
**		Date: 12/16/2002 
**			  3/16/2004 grk - changed default @dataStoragePath to G: drive
**			  4/28/2004 grk - changed default @templateFilePath to proto-5
**			  4/30/2004 mem - updated call to sp_add_maintenance_plan_db to look up the GUID for the maintenance plan by name
**			  5/05/2004 mem - added @OrganismDBFileList parameter
**							  changed default value for @newDBNameRoot to 'SWTestPeptide'
**			  8/29/2004 mem - changed default @templateFilePath to PT_Template_01 and added creation of GANET transfer folders
**			  9/17/2004 mem - changed default @templateFilePath to proto-6\MTS_Backup\
**			 11/12/2004 mem - Added call to MTS_Master..MakeProvisionalPeptideDB to obtain next available DB ID and Name
**			 12/07/2004 mem - Updated for use on Albert
**			 01/22/2005 mem - Now displaying @message if an error occurs
**			 03/07/2005 mem - Switched to using AddUpdateConfigEntry to populate T_Process_Config with the values in @OrganismDBFileList
**			 07/01/2005 mem - Added parameter @logStoragePath to specify the location of the transaction log files
**			 10/10/2005 mem - Updated Maintenance Plan name to 'DB Maintenance Plan - PT DB Backup, Part 1' ; previously, was 'DB Maintenance Plan - PT databases'
**			 10/22/2005 mem - Now also adding new database to Maintenance Plan 'DB Maintenance Plan - PT databases'
**			 11/23/2005 mem - Added brackets around @newDBName as needed to allow for DBs with dashes in the name
**    
*****************************************************/
	@newDBNameRoot varchar(64) = 'SWTestPeptide',
	@newDBNameType char(1) = 'A',
	@description varchar(256) = 'Main database for Borrelia',
	@organism varchar(64) = 'Borrelia',
	@OrganismDBFileList varchar(1000) = '',				-- Optional, comma separated list of fasta files
	@message varchar(512) = '' output,
	@templateFilePath varchar(256) = '\\proto-6\MTS_Templates\PT_Template_01\PT_Template_01.bak',
	@dataStoragePath varchar(256) = 'F:\SQLServerData\',
	@logStoragePath varchar(256) = 'D:\SQLServerData\',
	@dbState int = 1
AS
	SET NOCOUNT ON
	 
	declare @myError int
	set @myError = 0

	declare @myRowCount int
	set @myRowCount = 0
	
	set @message = ''

	declare @GANETRootPath varchar(256)
	set @GANETRootPath = ''

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
	-- calling MakeProvisionalPeptideDB in Pogo.MTS_Master
	---------------------------------------------------

	declare @newDBID int
	set @newDBID = 0
	
	declare @newDBName varchar(128)
	set @newDBName = ''

	Exec @myError = Pogo.MTS_Master.dbo.MakeProvisionalPeptideDB 
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
	-- Create new Peptide database 
	---------------------------------------------------
	
	declare @dataFilePath varchar(256)
	declare @logFilePath varchar(256)
	set @dataFilePath = @dataStoragePath + @newDBName + '_data.mdf'
	set @logFilePath =  @logStoragePath + @newDBName + '_log.ldf'

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
	Set @myError = @@Error
	
	if @myError <> 0
	begin
		set @Message = 'Error restoring Peptide DB from ' + @templateFilePath + ' (Error number = ' + Convert(varchar(9), @myError) + ')'
		set @myError = 104

		-- Remove the DB name from MTS_Master
		DELETE FROM Pogo.MTS_Master.dbo.T_MTS_Peptide_DBs
		WHERE Peptide_DB_ID = @newDBID

		Goto Done
	end

   	---------------------------------------------------
	-- Make entry in MT Main tracking table
	---------------------------------------------------
	
	declare @provider varchar(256)
	set @provider = 'Provider=sqloledb;Data Source=' + Lower(@@ServerName) + ';Initial Catalog=' + @newDBName + ';User ID=mtuser;Password=mt4fun'

	declare @NetSqLProvider varchar(256)
	set @NetSqLProvider = 'Server=' + Lower(@@ServerName) + ';database=' + @newDBName + ';uid=mtuser;Password=mt4fun'

	declare @NetOleDBProvider varchar(256)
	set @NetOleDBProvider = @provider
	
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
	if @myError <> 0
	begin
		set @message = 'could not add new record to PT DB list'
		set @myError = 105
		goto done
	end

	--------------------------------------------------
	-- Get directory for GANET files
	---------------------------------------------------
	if @GANETRootPath = ''
	begin
		SELECT     @GANETRootPath = Server_Path
		FROM         T_Folder_Paths
		WHERE     ([Function] = 'GANET Transfer Root Folder')
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0
		begin
			set @message = 'error looking up GANETRootPath'
			goto done
		end
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
	
	set @path = @GANETRootPath + 'In\' + @newDBName
	exec @result = MakeFolder @path
	
	set @path = @GANETRootPath + 'Out\' + @newDBName
	exec @result = MakeFolder @path

	---------------------------------------------------
	-- add new database to maintenance plan for Peptide DB's
	-- first add to the main maintenance plan
	---------------------------------------------------

	Declare @DBMaintPlanName varchar(128)
	Declare @planID as UniqueIdentifier
	
	Set @DBMaintPlanName = 'DB Maintenance Plan - PT databases'
	Set @planID = '{00000000-0000-0000-0000-000000000000}'

	SELECT @planID = plan_ID
	FROM msdb..sysdbmaintplans
	WHERE plan_name = @DBMaintPlanName

	If @planID <> '{00000000-0000-0000-0000-000000000000}'
		Execute	msdb..sp_add_maintenance_plan_db @planID, @newDBName
	Else
	Begin
		Set @message = 'Database maintenance plan ''' + @DBMaintPlanName + ''' not found in msdb..sysdbmaintplans'
		Exec PostLogEntry 'Error', @message, 'MakeNewPeptideDB'
	End

	---------------------------------------------------
	-- now add to the maintenance plan dedicated to weekly DB backups
	---------------------------------------------------

	Set @DBMaintPlanName = 'DB Maintenance Plan - PT DB Backup, Part 1'
	Set @planID = '{00000000-0000-0000-0000-000000000000}'

	SELECT @planID = plan_ID
	FROM msdb..sysdbmaintplans
	WHERE plan_name = @DBMaintPlanName

	If @planID <> '{00000000-0000-0000-0000-000000000000}'
		Execute	msdb..sp_add_maintenance_plan_db @planID, @newDBName
	Else
	Begin
		Set @message = 'Database maintenance plan ''' + @DBMaintPlanName + ''' not found in msdb..sysdbmaintplans'
		Exec PostLogEntry 'Error', @message, 'MakeNewPeptideDB'
	End

	---------------------------------------------------
	-- Optional: Populate the T_Process_Config table with @OrganismDBFileList
	---------------------------------------------------

	Declare @sql varchar(1024)
	
	Declare @singleEntry varchar(255)
	Declare @listSeparator char
	Set @listSeparator = ','
	
	Declare @done tinyint
	Declare @sepLoc int
	
	If Len(IsNull(@OrganismDBFileList, '')) > 0
	Begin
		-- First clear any entries with Name = Organism_DB_File_Name in T_Process_Config
		
		Set @sql = ''
		Set @sql = @sql + 'DELETE FROM [' + @newDBName + ']..T_Process_Config '
		Set @sql = @sql + 'WHERE [Name] = ''Organism_DB_File_Name'''

		Exec (@sql)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount


		Set @message = ''
		Set @done = 0
		
		While @done = 0
		Begin
			Set @sepLoc = CharIndex(@listSeparator, @OrganismDBFileList)
			If @sepLoc = 0		
			Begin
				-- No list separator found
				Set @singleEntry = @OrganismDBFileList
				Set @OrganismDBFileList = ''
				Set @done = 1
			End
			Else
			Begin
				-- List separator found
				Set @singleEntry = SubString(@OrganismDBFileList, 1, @sepLoc-1)
				Set @OrganismDBFileList = LTrim(SubString(@OrganismDBFileList, @sepLoc+1, Len(@OrganismDBFileList) - @sepLoc))
			End

			Set @singleEntry = LTrim(RTrim(@singleEntry))

			If Len(@singleEntry) > 0
			Begin
				Exec AddUpdateConfigEntry @newDBName, 'Organism_DB_File_Name', @singleEntry
			End
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
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[MakeNewPeptideDB]  TO [DMS_SP_User]
GO

