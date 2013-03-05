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
**    
*****************************************************/
(
	@DBNameMatchList varchar(2048) = 'MT[_]%,PT[_]%',	-- Comma-separated list of databases on this server to include; can include wildcard symbols since used with a LIKE clause.  Use % to process every database on the server (skips DBs that don't have RebuildFragmentedIndices).  Leave blank to ignore this parameter
	@IncludeMTSInterfaceAndControlDBs tinyint = 1,		-- Set to 1 to include MTS_Master, MT_Main, MT_HistoricLog, and Prism_IFC, & Prism_RPT
	@MaxFragmentation int = 15,
	@TrivialPageCount int = 12,
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

	Set @MaxFragmentation = IsNull(@MaxFragmentation, 15)
	If @MaxFragmentation < 0
		Set @MaxFragmentation = 0
	If @MaxFragmentation > 100
		Set @MaxFragmentation = 100
			
	Set @TrivialPageCount = IsNull(@TrivialPageCount, 12)
	If @TrivialPageCount < 0
		Set @TrivialPageCount = 0

	Set @PauseMTSProcessing = IsNull(@PauseMTSProcessing, 1)
	Set @InfoOnly = IsNull(@InfoOnly, 1)
	Set @message = ''
		
	
	Declare @DBName nvarchar(255)
	Declare @DBsProcessed varchar(255)
	Set @DBsProcessed = ''
	
	Declare @Sql nvarchar(4000)
	Declare @SqlParams nvarchar(4000)
	
	Declare @continue tinyint
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

	Set @LastLogTime = GetUTCDate()
	If @myRowCount >= 4 And @InfoOnly = 0
	Begin
		Set @LogMsg = 'Calling RebuildFragmentedIndices for ' + Convert(varchar(12), @myRowCount) + ' databases'
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
	-- Then process the remaining DBs
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
			End
			Else
			Begin
				Set @LogMsg = 'Calling [' + @DBName + '].dbo.RebuildFragmentedIndices'
										
				If @InfoOnly <> 0
					Print @LogMsg
				
				If DateDiff(minute, @LastLogTime, GetUTCDate()) >= 5
				Begin
					Set @LastLogTime = GetUTCDate()
					Exec PostLogEntry 'Progress', @LogMsg, 'RebuildMTSDBIndices'
				End
					
				Set @Sql = 'exec [' + @DBName + '].dbo.RebuildFragmentedIndices @MaxFragmentation, @TrivialPageCount, @VerifyUpdateEnabled, @infoOnly, @message output'
				Set @SqlParams = '@MaxFragmentation int, @TrivialPageCount int, @VerifyUpdateEnabled tinyint, @infoOnly tinyint, @message varchar(1024) output'
				Set @message = ''
				Set @VerifyUpdateEnabled = 0

				Exec @myError = sp_executesql @Sql, @SqlParams, @MaxFragmentation, @TrivialPageCount, @VerifyUpdateEnabled, @infoOnly, @message output
				
				If @myError <> 0
				Begin
					Set @LogMsg = 'Error calling RebuildFragmentedIndices in ' + @DBName
					If IsNull(@message, '') <> ''
						Set @LogMsg = @LogMsg + ': ' + @message
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
