SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[Backup_MTS_DBs]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[Backup_MTS_DBs]
GO

CREATE PROCEDURE dbo.Backup_MTS_DBs
/****************************************************
**
**	Desc: Uses Red-Gate's SQL Backup software to backup the specified databases
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	05/23/2006
**			05/25/2006 mem - Expanded functionality
**			07/02/2006 mem - Now combining the status log files created by SQL Backup into a single text file for each backup session
**    
*****************************************************/
(
	@BackupFolderRoot varchar(128) = '',			-- If blank, then looks up the value in T_Folder_Paths
	@DBNameMatchList varchar(2048) = 'MT[_]%',		-- Comma-separated list of databases on this server to include; can include wildcard symbols since used with a LIKE clause.  Leave blank to ignore this parameter
	@TransactionLogBackup tinyint = 0,				-- Set to 0 for a full backup, 1 for a transaction log backup
	@IncludeMTSInterfaceAndControlDBs tinyint = 0,	-- Set to 1 to include MTS_Master, MT_Main, MT_HistoricLog, and Prism_IFC, & Prism_RPT
	@IncludeSystemDBs tinyint = 0,
	@FileAndThreadCount tinyint = 1,				-- Set to 2 or 3 to backup the database to multiple files and thus use multiple compression threads
	@Verify tinyint = 1,							-- Set to 1 to verify each backup
	@InfoOnly tinyint = 1,							-- Set to 1 to display the Backup SQL that would be run
	@message varchar(255) = '' OUTPUT
)
As	
	set nocount on
	
	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	Declare @ExitCode int
	Declare @SqlErrorCode int

	-- Validate the inputs
	Set @BackupFolderRoot = IsNull(@BackupFolderRoot, '')
	Set @DBNameMatchList = LTrim(RTrim(IsNull(@DBNameMatchList, '')))

	Set @TransactionLogBackup = IsNull(@TransactionLogBackup, 0)
	Set @IncludeMTSInterfaceAndControlDBs = IsNull(@IncludeMTSInterfaceAndControlDBs, 0)
	Set @IncludeSystemDBs = IsNull(@IncludeSystemDBs, 0)
	
	Set @FileAndThreadCount = IsNull(@FileAndThreadCount, 1)
	If @FileAndThreadCount < 1
		Set @FileAndThreadCount = 1
	Else
		If @FileAndThreadCount > 3
			Set @FileAndThreadCount = 3

	Set @Verify = IsNull(@Verify, 0)
	Set @InfoOnly = IsNull(@InfoOnly, 0)

	Set @message = ''

	Declare @DBName nvarchar(255)
	Declare @DBBackupList varchar(255)
	Set @DBBackupList = ''
	
	Declare @Sql nvarchar(4000)
	Declare @SqlRestore nvarchar(4000)
	
	Declare @BackupType nvarchar(32)
	Declare @BackupTime nvarchar(64)
	Declare @BackupFileBaseName nvarchar(512)
	Declare @BackupFileBasePath nvarchar(1024)
	Declare @BackupFileList nvarchar(2048)
	
	Declare @continue tinyint
	Declare @FullDBBackupMatchMode tinyint
	Declare @CharLoc int
	Declare @DBBackupFullCount int
	Declare @DBBackupTransCount int
	
	Set @DBBackupFullCount = 0
	Set @DBBackupTransCount = 0

	---------------------------------------
	-- Validate @BackupFolderRoot
	---------------------------------------
	Set @BackupFolderRoot = LTrim(RTrim(@BackupFolderRoot))
	If Len(@BackupFolderRoot) = 0
	Begin
		SELECT @BackupFolderRoot = Server_Path
		FROM T_Folder_Paths
		WHERE ([Function] = 'Database Backup Path')
	End
	
	Set @BackupFolderRoot = LTrim(RTrim(@BackupFolderRoot))
	If Len(@BackupFolderRoot) = 0
	Begin
		Set @myError = 50000
		Set @message = 'Backup path not defined via @BackupFolderRoot parameter, and could not be found in table T_Folder_Paths'
		Goto Done
	End
	
	If Right(@BackupFolderRoot, 1) <> '\'
		Set @BackupFolderRoot = @BackupFolderRoot + '\'
	
	
	---------------------------------------
	-- Define @DBBackupStatusLogPathBase
	---------------------------------------
	Declare @DBBackupStatusLogPathBase varchar(512)
	Declare @DBBackupStatusLogFileName varchar(512)
	
	Set @DBBackupStatusLogPathBase = ''
	SELECT @DBBackupStatusLogPathBase = Server_Path
	FROM T_Folder_Paths
	WHERE ([Function] = 'Database Backup Log Path')
	
	If Len(@DBBackupStatusLogPathBase) = 0
	Begin
		Set @message = 'Could not find entry ''Database Backup Log Path'' in table T_Folder_Paths; assuming E:\SqlServerBackup\'
		Execute PostLogEntry 'Error', @message, 'Backup_MTS_DBs'
		Set @message = ''
		
		Set @DBBackupStatusLogPathBase = 'E:\SqlServerBackup\'
	End

	If Right(@DBBackupStatusLogPathBase, 1) <> '\'
		Set @DBBackupStatusLogPathBase = @DBBackupStatusLogPathBase + '\'
	

	---------------------------------------
	-- Define the summary status file file path
	---------------------------------------
	Declare @DBBackupStatusLogSummary varchar(512)

	Set @BackupTime = Convert(nvarchar(64), GetDate(), 120 )
	Set @BackupTime = Replace(Replace(Replace(@BackupTime, ' ', '_'), ':', ''), '-', '')

	If @TransactionLogBackup = 0
		Set @DBBackupStatusLogSummary = @DBBackupStatusLogPathBase + 'DB_Backup_Full_' + @BackupTime + '.txt'
	Else
		Set @DBBackupStatusLogSummary = @DBBackupStatusLogPathBase + 'DB_Backup_Log_' + @BackupTime + '.txt'

	---------------------------------------
	-- Create a temporary table to hold the databases to process
	---------------------------------------
	If Exists (SELECT [Name] FROM sysobjects WHERE [Name] = '#Tmp_DB_Backup_List')
		DROP TABLE #Tmp_DB_Backup_List

	CREATE TABLE #Tmp_DB_Backup_List (
		DatabaseName varchar(255) NOT NULL,
		Recovery_Model varchar(64) NOT NULL DEFAULT 'Unknown',
		Perform_Full_DB_Backup tinyint NOT NULL DEFAULT 0
	)

	CREATE CLUSTERED INDEX #IX_Tmp_DB_Backup_List ON #Tmp_DB_Backup_List (DatabaseName)

	---------------------------------------
	-- Optionally include the system databases
	---------------------------------------
	If @IncludeSystemDBs <> 0
	Begin
		INSERT INTO #Tmp_DB_Backup_List (DatabaseName, Perform_Full_DB_Backup) VALUES ('Master', 1)
		INSERT INTO #Tmp_DB_Backup_List (DatabaseName, Perform_Full_DB_Backup) VALUES ('Model', 1)
		INSERT INTO #Tmp_DB_Backup_List (DatabaseName, Perform_Full_DB_Backup) VALUES ('MSDB', 1)
	End

	---------------------------------------
	-- Optionally include the MTS databases
	-- If any of these do not exist on this server, then they will be deleted below
	---------------------------------------
	If @IncludeMTSInterfaceAndControlDBs <> 0
	Begin
		INSERT INTO #Tmp_DB_Backup_List (DatabaseName) VALUES ('MTS_Master')
		INSERT INTO #Tmp_DB_Backup_List (DatabaseName) VALUES ('MT_Main')
		INSERT INTO #Tmp_DB_Backup_List (DatabaseName) VALUES ('MT_HistoricLog')
		INSERT INTO #Tmp_DB_Backup_List (DatabaseName) VALUES ('Prism_IFC')
		INSERT INTO #Tmp_DB_Backup_List (DatabaseName) VALUES ('Prism_RPT')
	End


	---------------------------------------
	-- Look for databases on this server that match @DBNameMatchList
	---------------------------------------
	If Len(@DBNameMatchList) > 0
	Begin
		-- Make sure @DBNameMatchList ends in a comma
		If Right(@DBNameMatchList,1) <> ','
			Set @DBNameMatchList = @DBNameMatchList + ','

		-- Split @DBNameMatchList on commas and loop

		Set @continue = 1
		While @continue <> 0
		Begin
			Set @CharLoc = CharIndex(',', @DBNameMatchList)
			
			If @CharLoc <= 0
				Set @continue = 0
			Else
			Begin
				Set @DBName = LTrim(RTrim(SubString(@DBNameMatchList, 1, @CharLoc-1)))
				Set @DBNameMatchList = LTrim(SubString(@DBNameMatchList, @CharLoc+1, Len(@DBNameMatchList) - @CharLoc))

				Set @Sql = ''
				Set @Sql = @Sql + ' INSERT INTO #Tmp_DB_Backup_List (DatabaseName)'
				Set @Sql = @Sql + ' SELECT [Name]'
				Set @Sql = @Sql + ' FROM master.dbo.sysdatabases SD LEFT OUTER JOIN '
				Set @Sql = @Sql +      ' #Tmp_DB_Backup_List DBL ON SD.Name = DBL.DatabaseName'
				Set @Sql = @Sql + ' WHERE [Name] LIKE ''' + @DBName + ''' And DBL.DatabaseName IS Null'
				
				Exec (@Sql)
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error
			End
		End
	End


	---------------------------------------
	-- Delete databases defined in #Tmp_DB_Backup_List that are not defined in sysdatabases
	---------------------------------------
	DELETE #Tmp_DB_Backup_List
	FROM #Tmp_DB_Backup_List DBL LEFT OUTER JOIN
		 master.dbo.sysdatabases SD ON SD.Name = DBL.DatabaseName
	WHERE SD.Name IS Null
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	
	If @myRowCount > 0
		Set @message = 'Deleted ' + Convert(varchar(9), @myRowCount) + ' non-existent databases'
	
	
	---------------------------------------
	-- Update column Recovery_Model in #Tmp_DB_Backup_List
	-- This only works if on Sql Server 2005 or higher
	---------------------------------------
	If Exists (SELECT Name FROM master.dbo.sysobjects WHERE name = 'databases')
	Begin
		-- Sql Server 2005 or higher
		UPDATE #Tmp_DB_Backup_List
		SET Recovery_Model = SD.recovery_model_desc
		FROM #Tmp_DB_Backup_List DBL INNER JOIN
			 master.sys.databases SD ON DBL.DatabaseName = SD.Name
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
	End

	
	---------------------------------------
	-- If @TransactionLogBackup = 0, then update Perform_Full_DB_Backup to 1 for all DBs
	-- Otherwise, update Perform_Full_DB_Backup to 1 for databases with a Simple recovery model
	---------------------------------------
	If @TransactionLogBackup = 0
	Begin
		UPDATE #Tmp_DB_Backup_List
		SET Perform_Full_DB_Backup = 1
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
	End
	Else
	Begin
		UPDATE #Tmp_DB_Backup_List
		SET Perform_Full_DB_Backup = 1
		WHERE Recovery_Model = 'SIMPLE'
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
	End		


	---------------------------------------
	-- Count the number of databases in #Tmp_DB_Backup_List
	---------------------------------------
	Set @myRowCount = 0
	SELECT @myRowCount = COUNT(*)
	FROM #Tmp_DB_Backup_List
	
	If @myRowCount = 0
	Begin
		Set @Message = 'Warning: no databases were found matching the given specifications'
		Goto Done
	End


	---------------------------------------
	-- Loop through the databases in #Tmp_DB_Backup_List
	-- First process DBs with Perform_Full_DB_Backup = 1
	-- Then process the remaining DBs
	---------------------------------------
	Set @FullDBBackupMatchMode = 1
	Set @continue = 1
	While @continue <> 0
	Begin
		SELECT TOP 1 @DBName = DatabaseName
		FROM #Tmp_DB_Backup_List
		WHERE Perform_Full_DB_Backup = @FullDBBackupMatchMode
		ORDER BY DatabaseName
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		If @myRowCount <> 1
		Begin
			If @FullDBBackupMatchMode = 1
				Set @FullDBBackupMatchMode = 0
			Else
				Set @continue = 0
		End
		Else
		Begin
			DELETE FROM #Tmp_DB_Backup_List
			WHERE @DBName = DatabaseName

			---------------------------------------
			-- Construct the backup and restore commands for database @DBName
			---------------------------------------
			
			If @FullDBBackupMatchMode = 1
			Begin
				Set @Sql = N'-SQL "BACKUP DATABASE '
				Set @BackupType = 'FULL'
				Set @DBBackupFullCount = @DBBackupFullCount + 1
			End
			Else
			Begin
				Set @Sql = N'-SQL "BACKUP LOG '
				Set @BackupType = 'LOG'
				Set @DBBackupTransCount = @DBBackupTransCount + 1
			End

			Set @Sql = @Sql + N'[' + @DBName + N'] TO '

			-- Generate a time stamp in the form: yyyymmdd_hhnnss
			Set @BackupTime = Convert(nvarchar(64), GetDate(), 120 )
			Set @BackupTime = Replace(Replace(Replace(@BackupTime, ' ', '_'), ':', ''), '-', '')
			
			Set @BackupFileBaseName =  @DBName + '_' + @BackupType + '_' + @BackupTime
			Set @BackupFileBasePath = @BackupFolderRoot + @DBName + '\' + @BackupFileBaseName

			If @FileAndThreadCount > 1
				Set @BackupFileList = 'DISK = ''' + @BackupFileBasePath + '_01.sqb'''
			Else
				Set @BackupFileList = 'DISK = ''' + @BackupFileBasePath + '.sqb'''
			
			If @FileAndThreadCount = 2
				Set @BackupFileList = @BackupFileList + ', DISK = ''' + @BackupFileBasePath + '_02.sqb'''

			If @FileAndThreadCount = 3
				Set @BackupFileList = @BackupFileList + ', DISK = ''' + @BackupFileBasePath + '_03.sqb'''
			
			Set @Sql = @Sql + @BackupFileList
			Set @Sql = @Sql + N' WITH MAXDATABLOCK=524288, NAME=''<AUTO>'', DESCRIPTION=''<AUTO>'', ERASEFILES=20, COMPRESSION=3,'
			Set @Sql = @Sql + N' THREADS=' + Convert(nvarchar(4), @FileAndThreadCount) + N','
			
			Set @DBBackupStatusLogFileName = @DBBackupStatusLogPathBase + @BackupFileBaseName + '.log'
			Set @Sql = @Sql + N' LOGTO=''' + @DBBackupStatusLogFileName + ''', MAILTO_ONERROR = ''matthew.monroe@pnl.gov''"'

			Set @SqlRestore = N'-SQL "RESTORE VERIFYONLY FROM ' + @BackupFileList + '"'
			
			
			If @InfoOnly = 0
			Begin
				---------------------------------------
				-- Perform the backup
				---------------------------------------
				exec master..sqlbackup @Sql, @ExitCode OUTPUT, @SqlErrorCode OUTPUT

				If (@ExitCode <> 0) OR (@SqlErrorCode <> 0)
				Begin
					---------------------------------------
					-- Error occurred; post a log entry
					---------------------------------------
					Set @message = 'SQL Backup of DB ' + @DBName + ' failed with exitcode: ' + Convert(varchar(19), @ExitCode) + ' and SQL error code: ' + Convert(varchar(19), @SqlErrorCode)
					Execute PostLogEntry 'Error', @message, 'Backup_MTS_DBs'
				End
				Else
				Begin
					If @Verify <> 0
					Begin
						-------------------------------------
						-- Verify the backup
						-------------------------------------
						exec master..sqlbackup @SqlRestore, @ExitCode OUTPUT, @SqlErrorCode OUTPUT

						If (@ExitCode <> 0) OR (@SqlErrorCode <> 0)
						Begin
							---------------------------------------
							-- Error occurred; post a log entry
							---------------------------------------
							Set @message = 'SQL Backup Verify of DB ' + @DBName + ' failed with exitcode: ' + Convert(varchar(19), @ExitCode) + ' and SQL error code: ' + Convert(varchar(19), @SqlErrorCode)
							Execute PostLogEntry 'Error', @message, 'Backup_MTS_DBs'
						End
					End
				End
				
				---------------------------------------
				-- Append the contents of @DBBackupStatusLogFileName to @DBBackupStatusLogSummary
				---------------------------------------
				Exec @myError = AppendTextFileToTargetFile	@DBBackupStatusLogFileName, 
															@DBBackupStatusLogSummary, 
															@DeleteSourceAfterAppend = 1, 
															@message = @message output
				If @myError <> 0
				Begin
					Set @message = 'Error calling AppendTextFileToTargetFile: ' + @message
					Execute PostLogEntry 'Error', @message, 'Backup_MTS_DBs'
					Goto Done
				End
			End
			Else
			Begin
				---------------------------------------
				-- Preview the backup Sql 
				---------------------------------------
				Set @Sql = Replace(@Sql, '''', '''' + '''')
				Print 'exec master..sqlbackup N''' + @Sql + ''''
				
				Set @SqlRestore = Replace(@SqlRestore, '''', '''' + '''')
				Print 'exec master..sqlbackup N''' + @SqlRestore + ''''
			End
			
			---------------------------------------
			-- Append @DBName to @DBBackupList, limiting to 175 characters, 
			--  afterwhich a period is added for each additional DB
			---------------------------------------
			If Len(@DBBackupList) = 0
				Set @DBBackupList = @DBName
			Else
			Begin
				If Len(@DBBackupList) <= 175
					Set @DBBackupList = @DBBackupList + ', ' + @DBName
				Else
					Set @DBBackupList = @DBBackupList + '.'
			End

		End
	End


	If @DBBackupFullCount + @DBBackupTransCount = 0
		Set @Message = 'Warning: no databases were found matching the given specifications'
	Else
	Begin
		Set @Message = 'DB Backup Complete ('
		if @DBBackupFullCount > 0
			Set @Message = @Message + 'FullBU=' + Convert(varchar(9), @DBBackupFullCount) 
		if @DBBackupTransCount > 0
		Begin
			If Right(@Message,1) <> '('
				Set @Message = @Message + '; '
			Set @Message = @Message + 'LogBU=' + Convert(varchar(9), @DBBackupTransCount) 
		End

		Set @Message = @Message + '): ' + @DBBackupList
	End
	
	---------------------------------------
	-- Post a Log entry if @DBBackupFullCount + @DBBackupTransCount > 0 and @InfoOnly = 0
	---------------------------------------
	If @InfoOnly = 0
	Begin
		If @DBBackupFullCount + @DBBackupTransCount > 0
			Execute PostLogEntry 'Normal', @message, 'Backup_MTS_DBs'
	End
	Else
		SELECT @Message As TheMessage

Done:
	DROP TABLE #Tmp_DB_Backup_List

	Return @myError



GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO
