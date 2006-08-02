SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[MakeNewMassTagDB_Replace]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[MakeNewMassTagDB_Replace]
GO

CREATE PROCEDURE MakeNewMassTagDB_Replace
/****************************************************
**
**	Desc: 
**		Replaces the actual database 
**		for an existing mass tag database 
**		with a completely new (empty) one
**
**		Requires that existing actual database
**		to have been manually deleted
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**		Auth: grk
**		Date: 10/17/2003 
**			  4/28/2004 mem - changed default @dataStoragePath to G: drive
**			  4/28/2004 mem - changed default @templateFilePath to proto-5
**			  9/17/2004 mem - changed default @templateFilePath to proto-6\MTS_Backup\
**			  9/22/2004 mem - Updated to use MT_Template_01 and to call ConfigureMassTagDB to populate the T_Process_Config table
**			 11/08/2004 mem - Rearranged input parameters to match MakeNewMassTagDB and now populating @organism from T_Peptide_Database_List
**			 12/13/2004 mem - Updated for use on Albert
**			 01/22/2005 mem - Now displaying @message if an error occurs
**			 07/01/2005 mem - Added parameter @logStoragePath to specify the location of the transaction log files
**			 11/23/2005 mem - Added brackets around @newDBName as needed to allow for DBs with dashes in the name
**    
*****************************************************/
	@mtDBName varchar(128) = '',
	@campaign varchar(64) = '',				-- e.g. Deinococcus
	@peptideDBName varchar(128) = '',		-- e.g. PT_Deinococcus_A55
	@proteinDBName varchar(128) = '',		-- e.g. ORF_Deinococcus_V23
	@OrganismDBFileList varchar(1024) = '',	-- e.g. GDR_2000-03-21.fasta	(Can be a comma separated list)
	@message varchar(512) output,
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

	declare @organism varchar(64)
	set @organism = ''
	
	declare @GANetRootPath varchar(256)
	set @GANetRootPath = ''
	
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
	-- Make sure that entry exists in MTDB list
	---------------------------------------------------
	declare @mtID int
	set @mtID = 0
	--
	SELECT @mtID = MTL_ID
	FROM T_MT_Database_List
	WHERE (MTL_Name = @mtDBName)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Could not check MTDB list'
		goto done
	end

	if @mtID = 0
	begin
		set @myError = 1
		set @message = 'Mass tag database is not in MTDB list'
		goto done
	end

	---------------------------------------------------
	-- Make sure that existing copy of DB has been deleted
	---------------------------------------------------
	
	declare @dbID int
	set @dbID = 0
	--
	SELECT @dbID = dbid
	FROM master.dbo.sysdatabases
	WHERE ([name] = @mtDBName)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Could not check master database list'
		goto done
	end

	if @dbID <> 0
	begin
		set @myError = 2
		set @message = 'Mass tag database has not been deleted'
		goto done
	end
	
	---------------------------------------------------
	-- Create new MT database 
	---------------------------------------------------
	
	declare @dataFilePath varchar(256)
	declare @logFilePath varchar(256)
	set @dataFilePath = @dataStoragePath + @mtDBName + '_data.mdf'
	set @logFilePath =  @logStoragePath + @mtDBName + '_log.ldf'

	-- new MT database is created by restore from
	-- a backup file that has been established as a
	-- template for new MT databases
	--
	RESTORE DATABASE @mtDBName
	FROM DISK = @templateFilePath
	WITH RECOVERY,
		MOVE 'MT_Template_01_dat' TO @dataFilePath, 
		MOVE 'MT_Template_01_log' TO @logFilePath
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @Message = 'Error restoring Mass Tag DB from ' + @templateFilePath + ' (Error number = ' + Convert(varchar(9), @myError) + ')'
		Goto Done
	end

	set @message = 'Replaced: "' + @mtDBName + '"'

	---------------------------------------------------
	--Update entry in MT Main tracking table
	---------------------------------------------------

	declare @provider varchar(256)
	set @provider = 'Provider=sqloledb;Data Source=albert;Initial Catalog=' + @mtDBName + ';User ID=mtuser;Password=mt4fun'
	
	UPDATE T_MT_Database_List
	SET MTL_Organism = @organism,
		MTL_Campaign = @campaign,
		MTL_Connection_String = @provider, 
		MTL_NetSQL_Conn_String = '', 
		MTL_NetOleDB_Conn_String = '', 
		MTL_State = @dbState,
		MTL_Created = GetDate(),
		MTL_Last_Update = Null,
		MTL_Last_Import = Null,
		MTL_Import_Holdoff = 24
	WHERE MTL_ID = @mtID


	---------------------------------------------------
	-- Configure the newly created database
	---------------------------------------------------
	
	Exec @result = ConfigureMassTagDB @mtDBName, @campaign, 
									  @peptideDBName, @proteinDBName, @OrganismDBFileList

		
		
	--------------------------------------------------
	-- Make sure that GANET transfer folders exist
	---------------------------------------------------
	Exec @result = MakeGANETTransferFolderForDB @mtDBName, @message output


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
		Execute	msdb..sp_add_maintenance_plan_db @planID, @mtDBName
	Else
	Begin
		Set @message = 'Database maintenance plan ''' + @DBMaintPlanName + ''' not found in msdb..sysdbmaintplans'
		Exec PostLogEntry 'Error', @message, 'MakeNewMassTagDB_Replace'
	End


	---------------------------------------------------
	-- Update MTUser and MTAdmin permissions for Albert
	-- need to revoke and grant MTUser and MTAdmin since
	-- the template DB has the Pogo versions of those users
	-- embedded in it, and we need to add the Albert versions
	---------------------------------------------------
	
	declare @sql varchar(1024)
	Set @sql = 'exec [' + @mtDBName + '].dbo.UpdateUserPermissions'
	
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

GRANT  EXECUTE  ON [dbo].[MakeNewMassTagDB_Replace]  TO [DMS_SP_User]
GO

