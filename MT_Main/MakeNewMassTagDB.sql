/****** Object:  StoredProcedure [dbo].[MakeNewMassTagDB] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
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
**	Auth:	grk
**	Date:	09/19/2003 Arrrrrrhh! Matey. (International 'Talk Like a Pirate Day')
**			03/16/2004 grk - changed default @dataStoragePath to G: drive
**			04/28/2004 grk - changed default @templateFilePath to proto-5
**			04/30/2004 mem - updated call to sp_add_maintenance_plan_db to look up the GUID for the maintenance plan by name
**			09/07/2004 mem - Now initializing field MTL_Import_Holdoff
**			09/17/2004 mem - changed default @templateFilePath to proto-6\MTS_Backup\
**			09/22/2004 mem - Updated to use MT_Template_01 and to call ConfigureMassTagDB to populate the T_Process_Config table
**			11/12/2004 mem - Added call to MTS_Master.dbo.MakeProvisionalMTDB to obtain next available DB ID and Name
**			12/13/2004 mem - Updated for use on Albert
**			01/07/2005 mem - Now displaying @message If an error occurs
**			03/09/2005 mem - Now allowing @campaign, @peptideDBName, and @proteinDBName to be comma separated lists
**			05/16/2005 mem - Expanded field size for @OrganismDBFileList from 128 to 1024 characters
**			07/01/2005 mem - Added parameter @logStoragePath to specify the location of the transaction log files
**			11/23/2005 mem - Added brackets around @newDBName as needed to allow for DBs with dashes in the name
**			01/20/2006 mem - Updated default MTL_Import_Holdoff from 24 to 48 hours
**			07/18/2006 mem - Updated @dataStoragePath and @logStoragePath to be blank by default, which results in looking up the paths in T_Folder_Paths
**						   - Removed addition to the 'DB Maintenance Plan - PT DB Backup' maintenance plan since DB backups are now performed by SP Backup_MTS_DBs
**			07/27/2006 mem - Updated to verify each campaign defined in @campaign
**			08/26/2006 mem - Now checking the Sql Server version; if Sql Server 2005, then not attempting to update any maintenance plans since SSIS handles DB integrity checks and backups
**			08/31/2006 mem - Now updating Last_Affected in T_Process_Config & T_Process_Step_Control in the newly created database
**			11/10/2006 mem - Updated check for valid peptide database to use V_MTS_PT_DBs if the peptide DB is not on this server
**						   - Removed Sql Server 2000 support
**			11/29/2006 mem - Updated validation of @peptideDBName to work properly if a list of DBs is provided
**						   - Added parameter @InfoOnly
**			06/06/2007 mem - Updated default MTL_Import_Holdoff from 48 to 12 hours
**			04/23/2013 mem - Now adding the new database to the DatabaseSettings table in the dba database
**    
*****************************************************/
(
	@newDBNameRoot varchar(64),					-- e.g. Deinococcus
	@newDBNameType char(1) = 'Q',				-- e.g. P or X or Q
	@description varchar(256),
	@campaign varchar(128) = '',				-- e.g. Deinococcus				(Can be a comma separated list)
	@peptideDBName varchar(1024) = '',			-- e.g. PT_Deinococcus_A55		(Can be a comma separated list)
	@proteinDBName varchar(128) = '',			-- Leave blank If unknown or If using Protein Collections (i.e. using the Protein_Sequences DB)
	@OrganismDBFileList varchar(1024) = '',		-- Optional, comma separated list of fasta files or comma separated list of protein collection names; e.g. 'PCQ_ETJ_2004-01-21.fasta,PCQ_ETJ_2004-01-21'
	@message varchar(512) = '' output,
	@newDBName varchar(128) = '' output,
	@dbState int = 1,
	@dataStoragePath varchar(256) = '',			-- If blank (or If @logStoragePath is blank), then will lookup in T_Folder_Paths
	@logStoragePath varchar(256) = '',			-- If blank (or If @dataStoragePath is blank), then will lookup in T_Folder_Paths
	@templateFilePath varchar(256) = '\\proto-1\DB_Backups\MTS_Templates\MT_Template_01\MT_Template_01.bak',
	@InfoOnly tinyint = 0						-- Set to 1 to validate the inputs and preview the values that will be used to create the new database
)
AS
	Set nocount on

	declare @myError int
	declare @myRowCount int
	Set @myError = 0
	Set @myRowCount = 0
	
	Set @message = ''
	Set @newDBName = ''
	
	declare @UnknownDBList varchar(1024)
	declare @FirstPeptideDB varchar(128)
	declare @organism varchar(64)
	Set @organism = ''
	
	declare @result int
	declare @hit int
	declare @PeptideDBCount int
	declare @PeptideDBCountInvalid int
	
	Declare @sql varchar(1024)
	Declare @PepDBServer varchar(128)
	Set @PepDBServer = ''

	Declare @S nvarchar(2048)
	Declare @Params nvarchar(1024)
	
	-- Validate the input parameters
	If Len(LTrim(RTrim(IsNull(@proteinDBName, '')))) = 0
		Set @proteinDBName = '(na)'
		
	Set @InfoOnly = IsNull(@InfoOnly, 0)

	---------------------------------------------------
	-- Verify peptide DB (or DBs)
	---------------------------------------------------

	CREATE TABLE #T_Peptide_Database_List (
		PeptideDBName varchar(128) NULL,
		PeptideDBID int NULL,
		PeptideDBServer varchar(128) NULL,
		PeptideDBPath varchar(256) NULL
	)
	
	-- Populate #T_Peptide_Database_List using @peptideDBName
	INSERT INTO #T_Peptide_Database_List (PeptideDBName)
	SELECT Value
	FROM dbo.udfParseDelimitedList(@peptideDBName, ',')
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	Set @PeptideDBCount = @myRowCount

	If @myError <> 0 OR @PeptideDBCount = 0
	Begin
		Set @message = 'Error determining the Peptide DB(s) in @peptideDBName'
		If @myError = 0
			Set @myError = 115
		goto done
	End

	---------------------------------------------------
	-- Determine the ID and server for each Peptide DB in #T_Peptide_Database_List
	---------------------------------------------------
	--
	exec @myError = PopulatePeptideDBLocationTable @PreferDBName = 1, @message = @message output

	If @myError <> 0
	Begin
		If Len(IsNull(@message, '')) = 0
			Set @message = 'Error calling PopulatePeptideDBLocationTable'
		
		Set @message = @message + '; Error Code ' + Convert(varchar(12), @myError)
		Goto Done
	End
	
	---------------------------------------------------
	-- Make sure each entry in #T_Peptide_Database_List has PeptideDBID defined
	-- Any that do not are unknown DBs
	---------------------------------------------------
	Set @PeptideDBCountInvalid = 0
	SELECT @PeptideDBCountInvalid = COUNT(*)
	FROM #T_Peptide_Database_List
	WHERE PeptideDBID Is Null

	If @PeptideDBCountInvalid > 0
	Begin
		Set @UnknownDBList = ''
		SELECT @UnknownDBList = @UnknownDBList + PeptideDBName + ','
		FROM #T_Peptide_Database_List
		WHERE PeptideDBID IS NULL
		ORDER BY PeptideDBName

		-- Remove the trailing comma
		Set @UnknownDBList = Left(@UnknownDBList, Len(@UnknownDBList)-1)
			
		Set @message = 'Peptide database'
		If @myRowCount > 1
			Set @message = @message + 's'
		Set @message = @message + ' not found in T_Peptide_Database_List or V_MTS_PT_DBs: ' + @UnknownDBList
		Set @myError = 101
		goto done

	End	

	---------------------------------------------------
	-- All of the peptide DBs are valid
	-- Determine the organism for the first one
	---------------------------------------------------
	--
	SELECT @FirstPeptideDB = PeptideDBName,
		   @PepDBServer = PeptideDBServer
	FROM #T_Peptide_Database_List INNER JOIN 
			(SELECT MIN(PeptideDBName) AS Peptide_DB_First
			FROM #T_Peptide_Database_List
		 ) LookupQ ON #T_Peptide_Database_List.PeptideDBName = LookupQ.Peptide_DB_First
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	If @PepDBServer = @@ServerName
	Begin
		SELECT @Organism = PDB_Organism
		FROM T_Peptide_Database_List
		WHERE PDB_Name = @FirstPeptideDB
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	End
	Else
	Begin
		Set @S = ''
		Set @S = @S + '	SELECT @organism = PDB_Organism'
		Set @S = @S + '	FROM ' + @PepDBServer + '.MT_Main.dbo.T_Peptide_Database_List'
		Set @S = @S + '	WHERE PDB_Name = ''' + @FirstPeptideDB + ''''
		
		-- Params string for sp_ExecuteSql
		Set @Params = '@organism varchar(128) output'
		
		exec sp_executesql @S, @Params, @organism = @organism output
	End

	If Len(IsNull(@organism, '')) = 0
	Begin
		Set @message = 'Organism not defined for Peptide DB ' + @FirstPeptideDB + ' on server ' + @PepDBServer
		Set @myError = 102
		goto done
	End
	
	If @InfoOnly <> 0
		SELECT * FROM #T_Peptide_Database_List ORDER BY PeptideDBName
	
	---------------------------------------------------
	-- Verify Protein DB
	---------------------------------------------------
	--
	If @proteinDBName <> '(na)'
	Begin
		Set @hit = 0
		--
		SELECT @hit = ODB_ID
		FROM T_ORF_Database_List
		WHERE (ODB_Name = @proteinDBName)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		If @myError <> 0
		Begin
			Set @message = 'Error verifying protein database name against T_ORF_Database_List'
			goto done
		End
		
		If @hit = 0
		Begin
			Set @message = 'Protein database ' + @proteinDBName + ' not found in T_ORF_Database_List'
			Set @myError = 102
			goto done
		End
	End

	---------------------------------------------------
	-- Assure that @campaign is not blank
	---------------------------------------------------
	
	Set @campaign = LTrim(RTrim(IsNull(@campaign, '')))
	
	If Len(@campaign) = 0
	Begin
		Set @message = 'One or more campaigns must be defined using @campaign'
		Set @myError = 103
		goto done
	End
	
	---------------------------------------------------
	-- Check @campaign for campaigns not defined in DMS
	---------------------------------------------------

	Declare @UnknownCampaigns varchar(1024)
	Declare @FirstCampaign varchar(128)

	Set @UnknownCampaigns = ''
	SELECT  @UnknownCampaigns = @UnknownCampaigns + CampaignListQ.Value + ','
	FROM dbo.udfParseDelimitedList(@campaign, ',') CampaignListQ LEFT OUTER JOIN
		 V_DMS_Campaign DC ON CampaignListQ.Value = DC.Campaign
	WHERE DC.Campaign IS NULL
	ORDER BY CampaignListQ.Value
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	If @myError <> 0
	Begin
		Set @message = 'Error verifying campaign(s) against V_DMS_Campaign'
		goto done
	End
		
	If @myRowCount > 0
	Begin
		-- Remove the final comma from @UnknownCampaigns
		Set @UnknownCampaigns = Left(@UnknownCampaigns, Len(@UnknownCampaigns)-1)
		
		If @myRowCount = 1
			Set @message = 'Campaign ' + @UnknownCampaigns + ' was not found in V_DMS_Campaign'
		Else
			Set @message = 'Campaigns ' + @UnknownCampaigns + ' were not found in V_DMS_Campaign'
		Set @myError = 104
		goto done
	End

	---------------------------------------------------
	-- Determine the first campaign listed in @campaign
	---------------------------------------------------
	Set @FirstCampaign = ''
	SELECT @FirstCampaign = MIN(CampaignListQ.Value)
	FROM dbo.udfParseDelimitedList(@campaign, ',') CampaignListQ 
	

   	---------------------------------------------------
	-- Populate @dataStoragePath and @logStoragePath if required
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
			Set @myError = 105
			goto done
		End
		Else
		If @myRowCount <> 1
		Begin
			Set @message = 'Could not find entry "Default Database Folder" in table T_Folder_Paths'
			Set @myError = 106
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
			Set @myError = 107
			goto done
		End
		Else
		If @myRowCount <> 1
		Begin
			Set @message = 'Could not find entry "Default Database Transaction Log Folder" in table T_Folder_Paths'
			Set @myError = 108
			goto done
		End
	End
	
	If @InfoOnly <> 0
	Begin
		SELECT	@newDBNameRoot AS DB_Name_Root, 
				@newDBNameType AS DB_Name_Type, 
				@description AS Description, 
				@Organism AS Organism, 
				@campaign AS Campaign_List,
				@peptideDBName AS Peptide_DB_List, 
				@proteinDBName AS Protein_DB_List, 
				@OrganismDBFileList AS Organism_DB_or_Protein_Collection_List,
				@dataStoragePath AS Data_Storage_Path,
				@logStoragePath AS Log_Storage_Path
		GOTO Done
	End
	
	---------------------------------------------------
	-- Get name for new database by
	-- calling MakeProvisionalMTDB in Pogo.MTS_Master
	---------------------------------------------------

	declare @newDBID int
	Set @newDBID = 0
	
	Set @myError = -9999
	Exec @myError = Pogo.MTS_Master.dbo.MakeProvisionalMTDB 
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
			Set @message = 'Error calling procedure Pogo.MTS_Master.dbo.MakeProvisionalMTDB; either the server and database are not available or a permissions error occurred'
		Else		
			Set @message = 'Could not get new database ID from MTS_Master'
		Goto done
	End

	---------------------------------------------------
	-- Create new MT database 
	---------------------------------------------------
	
	declare @dataFilePath varchar(256)
	declare @logFilePath varchar(256)
	Set @dataFilePath = dbo.udfCombinePaths(@dataStoragePath, @newDBName + '_data.mdf')
	Set @logFilePath =  dbo.udfCombinePaths(@logStoragePath,  @newDBName + '_log.ldf')

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
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	If @myError <> 0
	Begin
		Set @Message = 'Error restoring Mass Tag DB from ' + @templateFilePath + ' (Error number = ' + Convert(varchar(9), @myError) + ')'
		
		-- Remove the DB name from MTS_Master
		DELETE FROM Pogo.MTS_Master.dbo.T_MTS_MT_DBs
		WHERE MT_DB_ID = @newDBID
		
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
		GetDate(),
		12
		)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	If @myError <> 0
	Begin
		Set @message = 'Could not add new row to T_MT_Database_List'
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
		    VALUES(@NewDBName, 1, 1, 1, 0)
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
GRANT VIEW DEFINITION ON [dbo].[MakeNewMassTagDB] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[MakeNewMassTagDB] TO [MTS_DB_Lite] AS [dbo]
GO
