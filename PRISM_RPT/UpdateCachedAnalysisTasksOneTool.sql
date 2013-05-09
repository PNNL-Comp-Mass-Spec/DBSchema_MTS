/****** Object:  StoredProcedure [dbo].[UpdateCachedAnalysisTasksOneTool] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.UpdateCachedAnalysisTasksOneTool 
/****************************************************
**
**	Desc:	Updates T_Analysis_Task_Candidate_DBs with stats on the 
**			analysis tasks available for the given analysis tool
**
**	Auth:	mem
**	Date:	12/21/2007
**			01/02/2008 mem - Now updating Last_NewTask_Date in T_Analysis_Task_Candidate_DBs when Task_Count_New is > 0
**			01/09/2008 mem - Now setting @CheckForSkippedDBs to 0 if @ServerNameFilter and @DBNameFilter are not blank
**
*****************************************************/
(
	@ToolID int,							-- Tool ID is required (1=Viper, 2=MultiAlign)
	@ServerNameFilter varchar(128) = '',	-- If defined, then only examines databases on this server
	@DBNameFilter varchar(128)= '',			-- If defined, then only examines this database (must also provide @ServerNameFilter)
	@message varchar(512) = '' output,
	@PreviewSql tinyint = 0
)
As
	Set nocount on

	declare @myRowCount int
	declare @myError int
	Set @myRowCount = 0
	Set @myError = 0
	
	Declare @TaskTableName varchar(64)

	Declare @SqlCountTotalA varchar(512)
	Declare @SqlCounttotalB varchar(512)

	Declare @SqlCountNewA varchar(512)
	Declare @SqlCountNewB varchar(512)

	Declare @SqlCountProcessingA varchar(512)
	Declare @SqlCountProcessingB varchar(512)
	
	Declare @S nvarchar(4000)
	
	Declare @MatchCount int
	Declare @TaskCountTotal int
	Declare @TaskCountNew int
	Declare @TaskCountProcessing int

	Declare @Continue tinyint
	Declare @EntryID int
	Declare @CurrentServer varchar(255)
	Declare @CurrentMTDB varchar(255)
	Declare @DBPath varchar(512)
	Declare @WorkingServerPrefix varchar(255)
	
	Declare @UpdateStartTime datetime
	Declare @CheckForSkippedDBs tinyint
	Set @CheckForSkippedDBs = 1

	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Begin Try
		
		Set @CurrentLocation = 'Validate input parameters'
		
		Set @ToolID = IsNull(@ToolID, 0)
		Set @PreviewSql = IsNull(@PreviewSql, 0)
		Set @ServerNameFilter = IsNull(@ServerNameFilter, '')
		Set @DBNameFilter = IsNull(@DBNameFilter, '')

		Set @message = ''

		---------------------------------------------------
		-- Define the SQL queries that will be used
		---------------------------------------------------

		Set @SqlCountTotalA = ''
		
		If @ToolID = 1
		Begin
			-- VIPER
			Set @TaskTableName = 'T_Peak_Matching_Task'

			Set @SqlCountTotalA = 'SELECT @MatchCount = COUNT(*) FROM '
			Set @SqlCounttotalB = '.dbo.T_Peak_Matching_Task'

			Set @SqlCountNewA = 'SELECT @MatchCount = COUNT(*) FROM '
			Set @SqlCountNewB = '.dbo.T_Peak_Matching_Task WHERE (Processing_State = 1) AND Len(LTrim(RTrim(Ini_File_Name))) > 0'

			Set @SqlCountProcessingA = 'SELECT @MatchCount = COUNT(*) FROM '
			Set @SqlCountProcessingB = '.dbo.T_Peak_Matching_Task WHERE (Processing_State = 2)'
		End
		
		If @ToolID = 2
		Begin
			-- MultiAlign
			Set @TaskTableName = 'T_MultiAlign_Task'
		
			Set @SqlCountTotalA = 'SELECT @MatchCount = COUNT(*) FROM '
			Set @SqlCounttotalB = '.dbo.T_MultiAlign_Task'

			Set @SqlCountNewA = 'SELECT @MatchCount = COUNT(*) FROM '
			Set @SqlCountNewB = '.dbo.T_MultiAlign_Task WHERE (Processing_State = 1) AND Len(LTrim(RTrim(Param_File_Name))) > 0 AND Job_Count > 0'

			Set @SqlCountProcessingA = 'SELECT @MatchCount = COUNT(*) FROM '
			Set @SqlCountProcessingB = '.dbo.T_MultiAlign_Task WHERE (Processing_State = 2)'
		End

		If Len(@SqlCountTotalA) = 0
		Begin
			Set @message = 'Unknown @ToolID value: ' + Convert(varchar(12), @ToolID)
			Set @myError = 51000
			Goto Done
		End

		
		Set @CurrentLocation = 'Create temporary tables'
		
		---------------------------------------------------
		-- Create a temporary table to hold list of databases to process
		---------------------------------------------------
		CREATE TABLE #Tmp_DB_Names (
			Entry_ID int identity(1,1),
			Server_Name varchar(128),
			MTDB_Name varchar(128)
		) 

		---------------------------------------------------
		-- Populate the temporary table with list of mass tag
		-- databases that are not deleted
		---------------------------------------------------
		If Len(@ServerNameFilter) > 0 And Len(@DBNameFilter) > 0
		Begin
			INSERT INTO #Tmp_DB_Names (Server_Name, MTDB_Name)
			SELECT	Server_Name, MT_DB_Name
			FROM	MTS_Master.dbo.V_Active_MT_DBs
			WHERE Server_Name = @ServerNameFilter AND
				  MT_DB_Name = @DBNameFilter
			
			-- Disable checking for skipped DBs since we're only checking 1 database
			Set @CheckForSkippedDBs = 0
		End
		Else
		Begin		
			INSERT INTO #Tmp_DB_Names (Server_Name, MTDB_Name)
			SELECT	Server_Name, MT_DB_Name
			FROM	MTS_Master.dbo.V_Active_MT_DBs
			ORDER BY Server_Name, MT_DB_Name
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--
			If @myError <> 0
			Begin
				Set @message = 'could not load temporary table'
				Goto done
			End

			If Len(@ServerNameFilter) > 0
			Begin
				DELETE FROM #Tmp_DB_Names
				WHERE Server_Name <> @ServerNameFilter
			End
		End
		
		If @PreviewSql <> 0
			SELECT *
			FROM #Tmp_DB_Names
			ORDER BY Entry_ID
			
		Set @CurrentLocation = 'Process MTS servers'

		---------------------------------------------------
		-- Step through the mass tag database list and query
		-- the analysis tool task table in each one (if it exists)
		---------------------------------------------------
		
		Set @UpdateStartTime = GetDate()
		Set @EntryID = 0
		Set @Continue = 1
		
		While @Continue = 1 and @myError = 0  
		Begin -- <a>
		
			Begin
				-- Get next available entry from #Tmp_DB_Names
				--
				SELECT	TOP 1 
					@EntryID = Entry_ID,
					@CurrentServer = Server_Name, 
					@CurrentMTDB = MTDB_Name
				FROM	#Tmp_DB_Names 
				WHERE	Entry_ID > @EntryID
				ORDER BY Entry_ID
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				--		
				If @myRowCount = 0
					Set @Continue =0
			End

			If @myRowCount > 0
			Begin -- <b>
			
				Set @CurrentLocation = 'Prepare to query ' + @CurrentMTDB
				
				-- Construct the working server prefix
				If Lower(@@ServerName) = Lower(@CurrentServer)
					Set @WorkingServerPrefix = ''
				Else
					Set @WorkingServerPrefix = @CurrentServer + '.'

				-- Define the full path to the DB; note that @WorkingServerPrefix will be blank or will End in a period
				Set @DBPath = @WorkingServerPrefix + '[' + @CurrentMTDB + ']'
				
				-- Check If the database actually exists
				Set @MatchCount = 0
				Set @S = ''
				Set @S = @S + ' SELECT @MatchCount = Count(*) '
				Set @S = @S + ' FROM ' + @WorkingServerPrefix + 'master.dbo.sysdatabases AS SD'
				Set @S = @S + ' WHERE SD.NAME = ''' + @CurrentMTDB + ''''

				If @PreviewSql <> 0
				Begin
					Print @S
					Set @MatchCount = 1
				End
				Else
					EXEC sp_executesql @S, N'@MatchCount int OUTPUT', @MatchCount OUTPUT

				If (@MatchCount > 0)
				Begin -- <c>
				
					Begin Try
						
						Set @CurrentLocation = 'Look for T_Peak_Matching_Task in ' + @DBPath + '.sys.tables'
						
						-- Check If table @TaskTableName exists in @CurrentMTDB

						Set @MatchCount = 0
						Set @S = ''				
						Set @S = @S + ' SELECT @MatchCount = COUNT(*)'
						Set @S = @S + ' FROM ' + @DBPath + '.sys.tables'
						Set @S = @S + ' WHERE name = ''' + @TaskTableName + ''''

						If @PreviewSql <> 0
						Begin
							Print @S
							Set @MatchCount = 1
						End
						Else
							EXEC sp_executesql @S, N'@MatchCount int OUTPUT', @MatchCount OUTPUT

						-- Reset the task count variables
						Set @TaskCountTotal = -1
						Set @TaskCountNew = 0
						Set @TaskCountProcessing = -1
						
						If (@MatchCount > 0)
						Begin -- <d>

							Set @S = @SqlCountTotalA + @DBPath + @SqlCountTotalB
							If @PreviewSql <> 0
								Print @S
							Else
								EXEC sp_executesql @S, N'@MatchCount int OUTPUT', @MatchCount OUTPUT
							Set @TaskCountTotal = @MatchCount
							
							Set @S = @SqlCountNewA + @DBPath + @SqlCountNewB
							If @PreviewSql <> 0
								Print @S
							Else
								EXEC sp_executesql @S, N'@MatchCount int OUTPUT', @MatchCount OUTPUT
							Set @TaskCountNew = @MatchCount
							
							Set @S = @SqlCountProcessingA + @DBPath + @SqlCountProcessingB
							If @PreviewSql <> 0
								Print @S
							Else
								EXEC sp_executesql @S, N'@MatchCount int OUTPUT', @MatchCount OUTPUT
							Set @TaskCountProcessing = @MatchCount
							
						End -- </d>
					
						If @PreviewSql <> 0
							Set @continue = 0
						Else
						Begin
							If Not Exists (	SELECT Database_Name 
											FROM T_Analysis_Task_Candidate_DBs 
											WHERE Tool_ID = @ToolID AND Server_Name = @CurrentServer AND Database_Name = @CurrentMTDB)
							Begin
								-- Add the entry for @CurrentMTDB since it doesn't exist in T_Analysis_Task_Candidate_DBs
								INSERT INTO T_Analysis_Task_Candidate_DBs (Tool_ID, Server_Name, Database_Name)
								VALUES (@ToolID, @CurrentServer, @CurrentMTDB)
							End
							
							-- Update the Task_Count values for @CurrentMTDB in T_Analysis_Task_Candidate_DBs
							UPDATE T_Analysis_Task_Candidate_DBs
							SET Task_Count_Total = @TaskCountTotal,
								Task_Count_New = @TaskCountNew,
								Task_Count_Processing = @TaskCountProcessing,
								Last_Affected = GetDate(),
								Last_NewTask_Date = CASE WHEN @TaskCountNew > 0 THEN GetDate() ELSE Last_NewTask_Date END
							WHERE Tool_ID = @ToolID AND 
								  Server_Name = @CurrentServer AND 
								  Database_Name = @CurrentMTDB
						End
												
					End Try
					Begin Catch
						-- Error caught; log the error but continue processing
						Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'UpdateCachedAnalysisTasksOneTool')
						exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
												@ErrorNum = @myError output, @message = @message output
					End Catch
					
				End -- </c>
	
			End -- </b>	
					   
		End -- </a>

		If @CheckForSkippedDBs <> 0
		Begin
			Set @CurrentLocation = 'Look for DBs that were not updated'
			
			---------------------------------------------------
			-- For the servers just checked, if any of the databases were not updated (e.g. because they were
			--  not available or are no longer active) then change Task_Count_New to be -Task_Count_New
			---------------------------------------------------

			UPDATE T_Analysis_Task_Candidate_DBs
			SET Task_Count_New = -Task_Count_New
			FROM T_Analysis_Task_Candidate_DBs CDBs INNER JOIN
				(SELECT DISTINCT Server_Name FROM #Tmp_DB_Names) ServerQ
				ON CDBs.Server_Name = ServerQ.Server_Name
			WHERE CDBs.Tool_ID = @ToolID AND
				  CDBs.Last_Affected < @UpdateStartTime AND 
				  CDBs.Task_Count_New > 0
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			
			If @myRowCount > 0
			Begin
				Set @Message = 'Changed the Task_Count_New value to -Task_Count_New for ' + Convert(varchar(12), @myRowCount) + ' database'
				If @myRowCount > 1
					Set @Message = @message + 's because the DBs were not found (or are no longer active)'
				else
					Set @Message = @message + ' because the DB was not found (or is no longer active)'

				-- Construct the list of skipped databases
				Declare @SkippedDBList varchar(512)
				
				SELECT @SkippedDBList = COALESCE(@SkippedDBList + ', ', '') + Database_Name
				FROM T_Analysis_Task_Candidate_DBs CDBs
				WHERE CDBs.Tool_ID = @ToolID AND
					  CDBs.Task_Count_New < 0
				ORDER BY Database_Name
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
					
				-- Append the list of skipped databases
				Set @Message = @Message + ': ' + IsNull(@SkippedDBList, 'Unknown DB Name(s)')
				
				Exec PostLogEntry 'Warning', @message, 'UpdateCachedAnalysisTasksOneTool'
				Set @message = ''
				
			End
		End

		Set @CurrentLocation = 'Done checking all DBs'

	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'UpdateCachedAnalysisTasksOneTool')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
								@ErrorNum = @myError output, @message = @message output
		Goto Done
	End Catch

	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	Return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[UpdateCachedAnalysisTasksOneTool] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[UpdateCachedAnalysisTasksOneTool] TO [MTS_DB_Lite] AS [dbo]
GO
