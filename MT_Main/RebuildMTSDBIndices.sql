/****** Object:  StoredProcedure [dbo].[RebuildMTSDBIndices] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.RebuildMTSDBIndices
/****************************************************
**
**	Desc:	Calls RebuildFragmentedIndices in a series of MTS databases
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	10/15/2012
**			10/18/2012 mem - Added parameter @PauseMTSProcessing
**			07/17/2014 mem - Changed default value for @MaxFragmentation from 15 to 25
**						   - Changed default value for @TrivialPageCount from 12 to 22
**			03/17/2016 mem - Added new parameters:
**								@PercentFreeSpace; ignored if 0 or 100 (note that FillFactor is 100 - @PercentFreeSpace so when @PercentFreeSpace is 10, FillFactor is 90)
**								@MinFragmentation; will reorganize indices with fragmentation over this threshold but below @MaxFragmentation
**						   - Now preferentially uses stored procedure dba_indexDefrag_sp in the dba database instead of RebuildFragmentedIndices
**    
*****************************************************/
(
	@DBNameMatchList varchar(2048) = 'MT[_]%,PT[_]%',	-- Comma-separated list of databases on this server to include; can include wildcard symbols since used with a LIKE clause.  Use % to process every database on the server (skips DBs that don't have RebuildFragmentedIndices).  Leave blank to ignore this parameter
	@IncludeMTSInterfaceAndControlDBs tinyint = 1,		-- Set to 1 to include MTS_Master, MT_Main, MT_HistoricLog, and Prism_IFC, & Prism_RPT
	@MinFragmentation int = 5,			-- Indices with a fragmentation value between @MinFragmentation and @MaxFragmentation are reorganized
	@MaxFragmentation int = 25,			-- Indices with fragmentation values over this threshold are rebuilt
	@TrivialPageCount int = 8,			-- Microsoft recommends ignoring indices less than 8 pages in length (8 pages is one extent); thus this should be 8 or larger
	@PercentFreeSpace int = 10,			-- Used to define FillFactor; @PercentFreeSpace=10 means FillFactor = 90; ignored if 0 or 100
	@PauseMTSProcessing tinyint = 1,
	@InfoOnly tinyint = 1,								-- Set to 1 to display the SQL that would be run
	@message varchar(255) = '' OUTPUT
)
As	
	set nocount on
	
	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	-- Validate the inputs
	Set @DBNameMatchList = LTrim(RTrim(IsNull(@DBNameMatchList, '')))

	Set @IncludeMTSInterfaceAndControlDBs = IsNull(@IncludeMTSInterfaceAndControlDBs, 0)

	Set @MinFragmentation = IsNull(@MinFragmentation, 5)
	If @MinFragmentation < 0
		Set @MinFragmentation = 0
	If @MinFragmentation > 50
		Set @MinFragmentation = 50

	Set @MaxFragmentation = IsNull(@MaxFragmentation, 25)
	If @MaxFragmentation < 0
		Set @MaxFragmentation = 0
	If @MaxFragmentation > 100
		Set @MaxFragmentation = 100
			
	Set @TrivialPageCount = IsNull(@TrivialPageCount, 8)
	If @TrivialPageCount < 0
		Set @TrivialPageCount = 0

	Set @PercentFreeSpace = IsNull(@PercentFreeSpace, 10)
	If @PercentFreeSpace < 0
		Set @PercentFreeSpace = 0
	If @PercentFreeSpace > 100
		Set @PercentFreeSpace = 100

	Set @PauseMTSProcessing = IsNull(@PauseMTSProcessing, 1)
	Set @InfoOnly = IsNull(@InfoOnly, 1)
	Set @message = ''
		
	
	Declare @DBName nvarchar(255)
	Declare @DBsProcessed varchar(255)
	Set @DBsProcessed = ''
	
	Declare @Sql nvarchar(4000)
	Declare @SqlParams nvarchar(4000)
	
	Declare @continue tinyint
	Declare @skipThisDB tinyint
	Declare @DBProcessCount int
	Set @DBProcessCount = 0
	
	Declare @DBSkipCount int
	Set @DBSkipCount = 0
	
	Declare @CharLoc int
	Declare @LogMsg varchar(512)
	Declare @MatchCount int
	Declare @LastLogTime datetime
	
	---------------------------------------
	-- Create a temporary table to hold the databases to process
	---------------------------------------
	--
	If Exists (SELECT [Name] FROM sysobjects WHERE [Name] = '#Tmp_DB_List')
		DROP TABLE #Tmp_DB_List

	CREATE TABLE #Tmp_DB_List (
		DatabaseName varchar(255) NOT NULL
	)

	CREATE CLUSTERED INDEX #IX_Tmp_DB_Backup_List ON #Tmp_DB_List (DatabaseName)

	---------------------------------------
	-- Optionally include the MTS databases
	-- If any of these do not exist on this server, then they will be deleted below
	---------------------------------------
	--
	If @IncludeMTSInterfaceAndControlDBs <> 0
	Begin
		INSERT INTO #Tmp_DB_List (DatabaseName) VALUES ('MTS_Master')
		INSERT INTO #Tmp_DB_List (DatabaseName) VALUES ('MT_Main')
		INSERT INTO #Tmp_DB_List (DatabaseName) VALUES ('MT_HistoricLog')
		INSERT INTO #Tmp_DB_List (DatabaseName) VALUES ('Prism_IFC')
		INSERT INTO #Tmp_DB_List (DatabaseName) VALUES ('Prism_RPT')
	End


	---------------------------------------
	-- Look for databases on this server that match @DBNameMatchList
	---------------------------------------
	--
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
				Set @Sql = @Sql + ' INSERT INTO #Tmp_DB_List (DatabaseName)'
				Set @Sql = @Sql + ' SELECT [Name]'
				Set @Sql = @Sql + ' FROM master.dbo.sysdatabases SD LEFT OUTER JOIN '
				Set @Sql = @Sql +      ' #Tmp_DB_List DBList ON SD.Name = DBList.DatabaseName'
				Set @Sql = @Sql + ' WHERE [Name] LIKE ''' + @DBName + ''' And DBList.DatabaseName IS Null'
				
				Exec @myError = sp_executesql @Sql

			End
		End
	End


	---------------------------------------
	-- Delete databases defined in #Tmp_DB_List that are not defined in sysdatabases
	---------------------------------------
	--
	DELETE #Tmp_DB_List
	FROM #Tmp_DB_List DBList LEFT OUTER JOIN
		 master.dbo.sysdatabases SD ON SD.Name = DBList.DatabaseName
	WHERE SD.Name IS Null
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	
	If @myRowCount > 0
		Set @message = 'Deleted ' + Convert(varchar(9), @myRowCount) + ' non-existent databases'
	

	---------------------------------------
	-- Count the number of databases in #Tmp_DB_List
	---------------------------------------
	--
	Set @myRowCount = 0
	SELECT @myRowCount = COUNT(*)
	FROM #Tmp_DB_List
	
	If @myRowCount = 0
	Begin
		Set @Message = 'Warning: no databases were found matching the given specifications'
		Goto Done
	End

	---------------------------------------
	-- Look for stored procedure dba_indexDefrag_sp in the dba database
	---------------------------------------
	
	Declare @UseDbaIndexDefrag tinyint = 0
	Declare @defragProcedureName varchar(32) = 'RebuildFragmentedIndices'
	
	If Exists (Select * from sys.databases where [name] = 'dba')
	Begin
		
		-- Look for the dba_indexDefrag_sp procedure
		--
		Set @Sql = 'SELECT @MatchCount = COUNT(*) FROM dba.Sys.Procedures WHERE Name = ''dba_indexDefrag_sp'''
		Set @SqlParams = '@MatchCount int output'
		Set @MatchCount = 0
		
		Exec @myError = sp_executesql @Sql, @SqlParams, @MatchCount output

		If @MatchCount = 0
		Begin
			If @InfoOnly <> 0
				Print 'Warning: Stored procedure dba_indexDefrag_sp not found in the dba database'
			Else
				Exec PostLogEntry 'Error', 'Stored procedure dba_indexDefrag_sp not found in the dba database', 'RebuildDMSDBIndices'
		End
		Else
		Begin
			Set @UseDbaIndexDefrag = 1
			Set @defragProcedureName = 'dba..dba_indexDefrag_sp'
		End
	End
	Else
	Begin
		If @InfoOnly <> 0
			Print 'dba database not found; cannot use dba_indexDefrag_sp'
		Else
			Exec PostLogEntry 'Error', 'dba database not found; cannot use dba_indexDefrag_sp', 'RebuildDMSDBIndices'
	End

	---------------------------------------
	-- Initialize @LastLogTime and possibly post an initial log entry
	---------------------------------------
	--
	SELECT @myRowCount = COUNT(*)
	FROM #Tmp_DB_List

	Set @LastLogTime = GetUTCDate()
	If @myRowCount >= 4 And @InfoOnly = 0
	Begin
		Set @LogMsg = 'Calling ' + @defragProcedureName + ' for ' + Convert(varchar(12), @myRowCount) + ' databases'
		Exec PostLogEntry 'Progress', @LogMsg, 'RebuildMTSDBIndices'
	End

	---------------------------------------
	-- Possibly Pause MTS processing
	---------------------------------------
	
	Declare @VerifyUpdateEnabled tinyint = 0
	Declare @UnpauseMTSProcessing tinyint = 0

	If @PauseMTSProcessing <> 0
	Begin
		If Exists (SELECT * FROM T_Process_Step_Control WHERE Processing_Step_Name <> 'MS_Peak_Matching' AND Execution_State = 1)
		Begin
			If @InfoOnly <> 0
				Print 'Pause MTS processing using: exec MasterUpdateStepPauseControl @Pause = 1, @ProcessingStepNameExclusionFilter = ''MS_Peak_Matching'''
			Else
				exec MasterUpdateStepPauseControl @Pause = 1, @ProcessingStepNameExclusionFilter = 'MS_Peak_Matching'
				
			Set @UnpauseMTSProcessing = 1
		End
	End
	
	---------------------------------------
	-- Loop through the databases in #Tmp_DB_List
	-- and call RebuildFragmentedIndices for each
	---------------------------------------
	--
	Set @continue = 1
	While @continue <> 0
	Begin -- <a>
		SELECT TOP 1 @DBName = DatabaseName
		FROM #Tmp_DB_List
		ORDER BY DatabaseName
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		If @myRowCount <> 1
		Begin
			Set @continue = 0
		End
		Else
		Begin -- <b>
		
			DELETE FROM #Tmp_DB_List
			WHERE @DBName = DatabaseName

			Set @skipThisDB = 0
	
			If @UseDbaIndexDefrag = 0
			Begin
			-- Make sure the database contains stored procedure RebuildFragmentedIndices
			Set @Sql = 'SELECT @MatchCount = COUNT(*) FROM [' + @DBName + '].Sys.Procedures WHERE Name = ''RebuildFragmentedIndices'''
			Set @SqlParams = '@MatchCount int output'
			Set @MatchCount = 0
			
			Exec @myError = sp_executesql @Sql, @SqlParams, @MatchCount output
			
			If @MatchCount = 0
			Begin
				If @InfoOnly <> 0
					Print 'Warning: Skipping ' + @DBName + ' since procedure RebuildFragmentedIndices not found'
					
				Set @DBSkipCount = @DBSkipCount + 1
					Set @skipThisDB = 1
				End
			End
						
			If @skipThisDB = 0
			Begin
				If @UseDbaIndexDefrag = 0
					Set @LogMsg = 'Calling [' + @DBName + '].dbo.RebuildFragmentedIndices'
				Else
					Set @LogMsg = 'Calling dba..dba_indexDefrag_sp for database ' +  @DBName
										
				If @InfoOnly <> 0
					Print @LogMsg
				
				If DateDiff(minute, @LastLogTime, GetUTCDate()) >= 5
				Begin
					Set @LastLogTime = GetUTCDate()
					Exec PostLogEntry 'Progress', @LogMsg, 'RebuildMTSDBIndices'
				End
					
				If @UseDbaIndexDefrag = 0
				Begin
					Set @Sql = 'exec [' + @DBName + '].dbo.RebuildFragmentedIndices @MaxFragmentation, @TrivialPageCount, @PercentFreeSpace, @VerifyUpdateEnabled, @infoOnly, @message output'
					Set @SqlParams = '@MaxFragmentation int, @TrivialPageCount int, @PercentFreeSpace int, @VerifyUpdateEnabled tinyint, @infoOnly tinyint, @message varchar(1024) output'
					Set @message = ''
					Set @VerifyUpdateEnabled = 0

					Exec @myError = sp_executesql @Sql, @SqlParams, @MaxFragmentation, @TrivialPageCount, @PercentFreeSpace, @VerifyUpdateEnabled, @infoOnly, @message output
				End
				Else
				Begin
				
					If @minFragmentation > @MaxFragmentation
						Set @minFragmentation = @MaxFragmentation
						
					Set @Sql = ''
					Set @Sql = @Sql + ' EXECUTE dba.dbo.dba_indexDefrag_sp '
					
					If @infoOnly = 0
					Begin
						Set @Sql = @Sql + '  @executeSQL       = 1'
						Set @Sql = @Sql + ', @debugMode        = 0'
					End
					Else
					Begin
						Set @Sql = @Sql + '  @executeSQL       = 0'
						Set @Sql = @Sql + ', @debugMode        = 1'
					End

					Set @Sql = @Sql + ' , @printCommands        = 1'					
					Set @Sql = @Sql + ' , @printFragmentation   = 1'
					Set @Sql = @Sql + ' , @forceRescan          = 1'					-- If index scan times are slow when @scanMode is SAMPLED, set this to 0
					Set @Sql = @Sql + ' , @scanMode             = ''SAMPLED'''
					Set @Sql = @Sql + ' , @maxDopRestriction    = 1'
					Set @Sql = @Sql + ' , @minPageCount         = ' + Cast(@TrivialPageCount as nvarchar(9))
					Set @Sql = @Sql + ' , @maxPageCount         = NULL'
					Set @Sql = @Sql + ' , @minFragmentation     = ' + Cast(@minFragmentation as nvarchar(6))  -- Tables with fragmentation between @minFragmentation and @MaxFragmentation will be reorganized instead of rebuilt
					Set @Sql = @Sql + ' , @rebuildThreshold     = ' + Cast(@MaxFragmentation as nvarchar(6))
					Set @Sql = @Sql + ' , @fillFactor           = ' + Cast((100-@PercentFreeSpace) as nvarchar(6))
					Set @Sql = @Sql + ' , @defragDelay          = ''00:00:02'''			 -- Wait 2 seconds between each index
					Set @Sql = @Sql + ' , @defragOrderColumn    = ''range_scan_count'''
					Set @Sql = @Sql + ' , @defragSortOrder      = ''DESC'''
					Set @Sql = @Sql + ' , @excludeMaxPartition  = 0'
					Set @Sql = @Sql + ' , @timeLimit            = 720'					 -- 12 hours
					Set @Sql = @Sql + ' , @database             = ''' + @DBName + ''''
					Set @Sql = @Sql + ' , @tableName            = NULL'					 -- All Tables
				
					Set @SqlParams = ''
				
					If @infoOnly > 0
						Print @Sql

					Exec @myError = sp_executesql @Sql, @SqlParams
				End
						
				If @myError <> 0
				Begin
					If @UseDbaIndexDefrag = 0
					Begin
						Set @LogMsg = 'Error calling RebuildFragmentedIndices in ' + @DBName
						If IsNull(@message, '') <> ''
							Set @LogMsg = @LogMsg + ': ' + @message
					End
					Else
						Set @LogMsg = 'Error calling dba..dba_indexDefrag_sp for ' + @DBName

					Exec PostLogEntry 'Error', @LogMsg, 'RebuildMTSDBIndices'
					
				End
							
				---------------------------------------
				-- Append @DBName to @DBsProcessed, limiting to 175 characters, 
				--  afterwhich a period is added for each additional DB
				---------------------------------------
				--
				If Len(@DBsProcessed) = 0
					Set @DBsProcessed = @DBName
				Else
				Begin
					If Len(@DBsProcessed) <= 175
						Set @DBsProcessed = @DBsProcessed + ', ' + @DBName
					Else
						Set @DBsProcessed = @DBsProcessed + '.'
				End
				
				Set @DBProcessCount = @DBProcessCount + 1
			End
			
		End -- </b>
	End -- </a>


	If @DBProcessCount = 0
		Set @Message = 'Warning: no databases were found matching the given specifications'
	Else
	Begin
		Set @Message = 'DB Maintenance Complete; ProcessCount=' + Convert(varchar(9), @DBProcessCount) + ': ' + @DBsProcessed
	End
	
	---------------------------------------
	-- Post a Log entry if @DBProcessCount > 0 and @InfoOnly = 0
	---------------------------------------
	--
	If @InfoOnly = 0
	Begin
		If @DBProcessCount > 0
			Exec PostLogEntry 'Normal', @message, 'RebuildMTSDBIndices'
	End
	Else
		SELECT @Message As TheMessage


Done:
	DROP TABLE #Tmp_DB_List

	---------------------------------------
	-- Possibly Unpause MTS processing
	---------------------------------------
	
	If @UnpauseMTSProcessing = 1
	Begin
		If @InfoOnly <> 0
			Print 'Unpause MTS processing using: exec MasterUpdateStepUnpauseIfIdle ''%Unpause%'''
		Else
			exec MasterUpdateStepUnpauseIfIdle '%Unpause%'
	End	
	
	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[RebuildMTSDBIndices] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[RebuildMTSDBIndices] TO [MTS_DB_Lite] AS [dbo]
GO
