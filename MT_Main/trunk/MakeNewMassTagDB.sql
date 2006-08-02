SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[MakeNewMassTagDB]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[MakeNewMassTagDB]
GO

CREATE PROCEDURE MakeNewMassTagDB
/****************************************************
**
**	Desc: Creates a new mass tag database
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**		Auth: grk
**		Date: 9/19/2003 Arrrrrrhh! Matey. 
**			  3/16/2004 grk - changed default @dataStoragePath to G: drive
**			  4/28/2004 grk - changed default @templateFilePath to proto-5
**			  4/30/2004 mem - updated call to sp_add_maintenance_plan_db to look up the GUID for the maintenance plan by name
**			  9/07/2004 mem - Now initializing field MTL_Import_Holdoff
**			  9/17/2004 mem - changed default @templateFilePath to proto-6\MTS_Backup\
**			  9/22/2004 mem - Updated to use MT_Template_01 and to call ConfigureMassTagDB to populate the T_Process_Config table
**			 11/12/2004 mem - Added call to MTS_Master.dbo.MakeProvisionalMTDB to obtain next available DB ID and Name
**			 12/13/2004 mem - Updated for use on Albert
**			 01/07/2005 mem - Now displaying @message if an error occurs
**			 03/09/2005 mem - Now allowing @campaign, @peptideDBName, and @proteinDBName to be comma separated lists
**			 05/16/2005 mem - Expanded field size for @OrganismDBFileList from 128 to 1024 characters
**			 07/01/2005 mem - Added parameter @logStoragePath to specify the location of the transaction log files
**			 11/23/2005 mem - Added brackets around @newDBName as needed to allow for DBs with dashes in the name
**    
*****************************************************/
	@newDBNameRoot varchar(64),				-- e.g. Deinococcus
	@newDBNameType char(1) = 'Q',			-- e.g. P or X or Q
	@description varchar(256),
	@campaign varchar(128) = '',			-- e.g. Deinococcus				(Can be a comma separated list)
	@peptideDBName varchar(128) = '',		-- e.g. PT_Deinococcus_A55
	@proteinDBName varchar(128) = '',		-- e.g. ORF_Deinococcus_V23
	@OrganismDBFileList varchar(1024) = '',	-- e.g. GDR_2000-03-21.fasta	(Can be a comma separated list)
	@message varchar(512) = '' output,
	@newDBName varchar(128) = '' output,
	@dbState int = 1,
	@dataStoragePath varchar(256) = 'F:\SQLServerData\',
	@logStoragePath varchar(256) = 'D:\SQLServerData\',
	@templateFilePath varchar(256) = '\\proto-6\MTS_Templates\MT_Template_01\MT_Template_01.bak'
AS
	SET NOCOUNT ON
	 
	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	set @message = ''
	set @newDBName = ''
	
	declare @organism varchar(64)
	set @organism = ''
	
	declare @result int
	declare @hit int
	
	---------------------------------------------------
	-- verify peptide DB and get its organism
	---------------------------------------------------
	
	set @hit = 0
	--
	SELECT     @hit = PDB_ID, @organism = PDB_Organism
	FROM         T_Peptide_Database_List
	WHERE     (PDB_Name = @peptideDBName)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'error trying to verify peptide database'
		goto done
	end

	if @hit = 0
	begin
		set @message = 'peptide database could not be found'
		goto done
	end

	---------------------------------------------------
	-- verify Protein DB
	---------------------------------------------------

	if @proteinDBName <> '(na)'
	BEGIN
		set @hit = 0
		--
		SELECT @hit = ODB_ID
		FROM T_ORF_Database_List
		WHERE (ODB_Name = @proteinDBName)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0
		begin
			set @message = 'error trying to verify Protein database'
			goto done
		end

		if @hit = 0
		begin
			set @message = 'Protein database could not be found'
			goto done
		end

	END

	---------------------------------------------------
	-- verify campaign against DMS
	-- If @campaign contains multiple entries, then verify the first one only
	---------------------------------------------------

	Declare @DelimeterLoc int
	Declare @FirstCampaign varchar(64)
	
	Set @DelimeterLoc = CharIndex(',', @campaign)		
	If @DelimeterLoc > 0
		-- Campaign includes commas; extract the first campaign name
		Set @FirstCampaign = RTrim(LTrim(SubString(@campaign, 1, @DelimeterLoc-1)))
	Else
		Set @FirstCampaign = RTrim(LTrim(@campaign))
			  	
	set @hit = 0
	--
	SELECT     @hit = ID
	FROM         V_DMS_Campaign
	WHERE     (Campaign = @FirstCampaign)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'error trying to verify campaign'
		goto done
	end

	if @hit = 0
	begin
		set @message = 'campaign could not be found in DMS'
		goto done
	end


	---------------------------------------------------
	-- Get name for new database by
	-- calling MakeProvisionalMTDB in Pogo.MTS_Master
	---------------------------------------------------

	declare @newDBID int
	set @newDBID = 0
	
	Exec @myError = Pogo.MTS_Master.dbo.MakeProvisionalMTDB 
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
	-- Create new MT database 
	---------------------------------------------------
	
	declare @dataFilePath varchar(256)
	declare @logFilePath varchar(256)
	set @dataFilePath = @dataStoragePath + @newDBName + '_data.mdf'
	set @logFilePath =  @logStoragePath + @newDBName + '_log.ldf'

	-- new MT database is created by restore from
	-- a backup file that has been established as a
	-- template for new MT databases
	--
	RESTORE DATABASE @newDBName
	FROM DISK = @templateFilePath
	WITH RECOVERY,
		MOVE 'MT_Template_01_dat' TO @dataFilePath, 
		MOVE 'MT_Template_01_log' TO @logFilePath
	--
	Set @myError = @@Error
	
	if @myError <> 0
	begin
		set @Message = 'Error restoring Mass Tag DB from ' + @templateFilePath + ' (Error number = ' + Convert(varchar(9), @myError) + ')'
		
		-- Remove the DB name from MTS_Master
		DELETE FROM Pogo.MTS_Master.dbo.T_MTS_MT_DBs
		WHERE MT_DB_ID = @newDBID
		
		Goto Done
	end

	Set @message = 'Created "' + @newDBName + '"'


	---------------------------------------------------
	-- Make entry in MT Main tracking table
	---------------------------------------------------
	
	declare @provider varchar(256)
	set @provider = 'Provider=sqloledb;Data Source=' + Lower(@@ServerName) + ';Initial Catalog=' + @newDBName + ';User ID=mtuser;Password=mt4fun'

	declare @NetSqLProvider varchar(256)
	set @NetSqLProvider = 'Server=' + Lower(@@ServerName) + ';database=' + @newDBName + ';uid=mtuser;Password=mt4fun'

	declare @NetOleDBProvider varchar(256)
	set @NetOleDBProvider = @provider

	
	INSERT INTO T_MT_Database_List (
		MTL_ID,
		MTL_Name, 
		MTL_Description, 
		MTL_Organism, 
		MTL_Campaign, 
		MTL_Connection_String, 
		MTL_NetSQL_Conn_String, 
		MTL_NetOleDB_Conn_String, 
		MTL_State,
		MTL_Created,
		MTL_Import_Holdoff
		)
	VALUES	(
		@newDBID,
		@newDBName,
		@description,
		@organism, 
		@FirstCampaign, 
		@provider,
		@NetSqLProvider,
		@NetOleDBProvider,
		@dbState,
		getdate(),
		24
		)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'could not add new record to MT DB list'
		goto done
	end

	
	---------------------------------------------------
	-- Configure the newly created database
	---------------------------------------------------
	
	Exec @result = ConfigureMassTagDB @newDBName, @campaign,
									  @peptideDBName, @proteinDBName,
									  @OrganismDBFileList


	--------------------------------------------------
	-- Make sure that GANET transfer folders exist
	---------------------------------------------------
	Exec @result = MakeGANETTransferFolderForDB @newDBName, @message output


	---------------------------------------------------
	-- add new database to maintenance plan for MTDB
	---------------------------------------------------

	Declare @DBMaintPlanName varchar(128)
	Declare @planID as UniqueIdentifier
	
	Set @DBMaintPlanName = 'DB Maintenance Plan - MT databases'
	Set @planID = '{00000000-0000-0000-0000-000000000000}'

	SELECT @planID = plan_ID
	FROM msdb..sysdbmaintplans
	WHERE plan_name = @DBMaintPlanName

	If @planID <> '{00000000-0000-0000-0000-000000000000}'
		Execute	msdb..sp_add_maintenance_plan_db @planID, @newDBName
	Else
	Begin
		Set @message = 'Database maintenance plan ''' + @DBMaintPlanName + ''' not found in msdb..sysdbmaintplans'
		Exec PostLogEntry 'Error', @message, 'MakeNewMassTagDB_Ex'
	End


	---------------------------------------------------
	-- Update MTUser and MTAdmin permissions for Albert
	-- need to revoke and grant MTUser and MTAdmin since
	-- the template DB has the Pogo versions of those users
	-- embedded in it, and we need to add the Albert versions
	---------------------------------------------------
	
	declare @sql varchar(1024)
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

GRANT  EXECUTE  ON [dbo].[MakeNewMassTagDB]  TO [DMS_SP_User]
GO

