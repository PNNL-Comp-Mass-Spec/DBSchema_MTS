/****** Object:  StoredProcedure [dbo].[UpdateAnalysisJobDetailsVIPER] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.UpdateAnalysisJobDetailsVIPER
/****************************************************
**
**	Desc:	Updates task details in T_Analysis_Job
**			using information in the source AMT tag databases
**
**	Auth:	mem
**	Date:	12/14/2011 mem - Initial version
**			03/16/2012 mem - Now updating columns Ini_File_Name, Comparison_Mass_Tag_Count, and MD_State when @UpdateMDIDandQID = 1
**			05/24/2013 mem - Added column Refine_Mass_Cal_PPMShift
**
*****************************************************/
(
	@ServerNameFilter varchar(128) = '',	-- If defined, then only examines databases on this server
	@DBNameFilter varchar(128)= '',			-- If defined, then only examines this database (must also provide @ServerNameFilter)
	@UpdateExecutionStats tinyint = 1,
	@CompareStartStopAndURL tinyint = 0,			-- Enabling this leads to slower updates
	@UpdateFDR tinyint = 1,
	@UpdateMDIDandQID tinyint = 1,
	@message varchar(512) = '' output,
	@PreviewSql tinyint = 0
)
As
	Set nocount on

	declare @myRowCount int
	declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

	Declare @S nvarchar(2048)
		
	Declare @MatchCount int

	Declare @Continue tinyint
	Declare @EntryID int
	Declare @CurrentServer varchar(255)
	Declare @CurrentMTDB varchar(255)
	Declare @DBPath varchar(512)
	Declare @WorkingServerPrefix varchar(255)

	Declare @LastLogTime datetime
	Declare @TotalDBsProcessed int = 0
	declare @RowCountUpdated int = 0
	
	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Begin Try
		
		Set @CurrentLocation = 'Validate input parameters'
		
		Set @PreviewSql = IsNull(@PreviewSql, 0)
		Set @ServerNameFilter = IsNull(@ServerNameFilter, '')
		Set @DBNameFilter = IsNull(@DBNameFilter, '')

		Set @UpdateExecutionStats = IsNull(@UpdateExecutionStats, 1)
		Set @CompareStartStopAndURL = IsNull(@CompareStartStopAndURL, 0)
		Set @UpdateFDR = IsNull(@UpdateFDR, 1)
		Set @UpdateMDIDandQID = IsNull(@UpdateMDIDandQID, 1)

		Set @message = ''
		Set @LastLogTime = GetDate()
		
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
						
						If DateDiff(second, @LastLogTime, GetDate()) >= 60
						Begin
							-- Post a progress message every 60 seconds							
							Set @LastLogTime = GetDate()
							Set @message = 'Updating VIPER task info in T_Analysis_Job; ' + Convert(varchar(12), @TotalDBsProcessed) + ' DBs completed; now processing ' + @CurrentMTDB + ' on ' + @CurrentServer
							
							Exec PostLogEntry 'Progress', @message, 'UpdateAnalysisJobDetailsVIPER'
							
							Set @message = ''
						End


						Set @CurrentLocation = 'Look for RequestPeakMatchingTask in ' + @DBPath + '.sys.tables'
						
						-- Check If table T_Peak_Matching_Task existing in @CurrentMTDB

						Set @MatchCount = 0
						Set @S = ''				
						Set @S = @S + ' SELECT @MatchCount = COUNT(*)'
						Set @S = @S + ' FROM ' + @DBPath + '.sys.tables'
						Set @S = @S + ' WHERE name = ''T_Peak_Matching_Task'''

						If @PreviewSql <> 0
						Begin
							Print @S
							Set @MatchCount = 1
						End
						Else
							EXEC sp_executesql @S, N'@MatchCount int OUTPUT', @MatchCount OUTPUT
						
						If (@MatchCount > 0)
						Begin -- <d>
						
						
							If @UpdateExecutionStats <> 0
							Begin -- <e1>
							
								-- First update task and job info
								Set @S = ''
								Set @S = @S + ' UPDATE T_Analysis_Job'
								Set @S = @S + ' SET '
								Set @S = @S     + ' Job_Start = Source.PM_Start,'
								Set @S = @S     + ' Job_Finish = Source.PM_Finish,'								
								Set @S = @S     + ' Assigned_Processor_Name = Source.PM_AssignedProcessorName,'
								Set @S = @S     + ' State_ID = Case When Source.Processing_State <= 4 Then Source.Processing_State Else State_ID End,'
								Set @S = @S     + ' DMS_Job_Min = Source.Job,'
								Set @S = @S     + ' DMS_Job_Max = Source.Job,'
								Set @S = @S     + ' Results_URL = Source.Results_URL,'
								Set @S = @S     + ' Analysis_Manager_Error = Source.Processing_Error_Code, '
								Set @S = @S     + ' Analysis_Manager_Warning = Source.Processing_Warning_Code'
								Set @S = @S + ' FROM T_Analysis_Job AJ'
								Set @S = @S     + '  INNER JOIN ' + @DBPath + '.dbo.V_Peak_Matching_Task Source'
								Set @S = @S     + '    ON AJ.Task_ID = Source.Task_ID AND'
								Set @S = @S     + '       AJ.Task_Database = ''' + @CurrentMTDB + ''' AND'
								Set @S = @S     + '       AJ.Task_Server = ''' +  @CurrentServer + ''' AND'								
								Set @S = @S     + '       AJ.Tool_ID = 1'
								Set @S = @S + ' WHERE '
								
								If @CompareStartStopAndURL  <> 0
								Begin
									Set @S = @S + ' (ABS(DATEDIFF(minute, ISNULL(AJ.Job_Start, ''1/1/1990''), Source.PM_Start)) > 1) OR'
									Set @S = @S + ' (ABS(DATEDIFF(minute, ISNULL(AJ.Job_Finish, ''1/1/1990''), Source.PM_Finish)) > 1) OR'
									Set @S = @S + ' (IsNull(AJ.Results_URL, '') <> Source.Results_URL) OR'
								End
								
								Set @S = @S     + ' (ISNULL(AJ.Assigned_Processor_Name, '''') <> Source.PM_AssignedProcessorName) OR'
								Set @S = @S     + ' (Source.Processing_State <= 4 AND AJ.State_ID <> Source.Processing_State) OR'
								Set @S = @S     + ' (AJ.DMS_Job_Min <> Source.Job) OR'
								Set @S = @S     + ' (AJ.DMS_Job_Max <> Source.Job) OR'
								Set @S = @S     + ' (AJ.Analysis_Manager_Error <> Source.Processing_Error_Code) OR'
								Set @S = @S     + ' (AJ.Analysis_Manager_Warning <> Source.Processing_Warning_Code)'

								If @PreviewSql <> 0
									Print @S
								Else
								Begin
									Exec (@S)
									
									SELECT @myError = @@error, @myRowCount = @@rowcount									
									Set @RowCountUpdated = @RowCountUpdated + @myRowCount
								End
									
							End -- </e1>
							
							
							If @UpdateFDR <> 0
							Begin -- <e2>
							
								-- Next update FDR Info
								Set @S = ''
								Set @S = @S + ' UPDATE T_Analysis_Job'
								Set @S = @S + ' SET AMT_Count_1pct_FDR = Source.AMT_Count_1pct_FDR,'
								Set @S = @S     + ' AMT_Count_5pct_FDR = Source.AMT_Count_5pct_FDR,'
								Set @S = @S     + ' AMT_Count_10pct_FDR = Source.AMT_Count_10pct_FDR,'
								Set @S = @S     + ' AMT_Count_25pct_FDR = Source.AMT_Count_25pct_FDR,'
								Set @S = @S     + ' AMT_Count_50pct_FDR = Source.AMT_Count_50pct_FDR,'
								Set @S = @S     + ' Refine_Mass_Cal_PPMShift = Source.Refine_Mass_Cal_PPMShift'
								Set @S = @S + ' FROM T_Analysis_Job AJ'
								Set @S = @S     + '  INNER JOIN ' + @DBPath + '.dbo.V_PM_Results_FDR_Stats Source'
								Set @S = @S     + '    ON AJ.Task_ID = Source.Task_ID AND'
								Set @S = @S     + '       AJ.Task_Database = ''' + @CurrentMTDB + ''' AND'
								Set @S = @S     + '       AJ.Task_Server = ''' +  @CurrentServer + ''' AND'
								Set @S = @S     + '       AJ.Tool_ID = 1'
								Set @S = @S + ' WHERE '
								Set @S = @S     + ' (ISNULL(AJ.AMT_Count_1pct_FDR, 0) <> Source.AMT_Count_1pct_FDR) OR'
								Set @S = @S     + ' (ISNULL(AJ.AMT_Count_5pct_FDR, 0) <> Source.AMT_Count_5pct_FDR) OR'
								Set @S = @S     + ' (ISNULL(AJ.AMT_Count_10pct_FDR, 0) <> Source.AMT_Count_10pct_FDR) OR'
								Set @S = @S     + ' (ISNULL(AJ.AMT_Count_25pct_FDR, 0) <> Source.AMT_Count_25pct_FDR) OR'
								Set @S = @S     + ' (ISNULL(AJ.AMT_Count_50pct_FDR, 0) <> Source.AMT_Count_50pct_FDR) OR'
								Set @S = @S     + ' (ISNULL(AJ.Refine_Mass_Cal_PPMShift, -99999) <> Source.Refine_Mass_Cal_PPMShift)'

								If @PreviewSql <> 0
									Print @S
								Else
								Begin
									Exec (@S)
									
									SELECT @myError = @@error, @myRowCount = @@rowcount									
									Set @RowCountUpdated = @RowCountUpdated + @myRowCount
								End

									
							End -- </e2>


							If @UpdateMDIDandQID <> 0
							Begin -- <e3>
							
								-- Finally, update MD_ID and QID Info'
								Set @S = ''
								Set @S = @S + ' UPDATE T_Analysis_Job'
								Set @S = @S + ' SET MD_ID = Source.MD_ID,'
								Set @S = @S     + ' QID = Source.Quantitation_ID,'
								Set @S = @S     + ' Ini_File_Name = Source.Ini_File_Name, '
								Set @S = @S     + ' Comparison_Mass_Tag_Count = Source.Comparison_Mass_Tag_Count, '
								Set @S = @S     + ' MD_State = Source.MD_State'
       
								Set @S = @S + ' FROM T_Analysis_Job AJ'
								Set @S = @S     + '  INNER JOIN ' + @DBPath + '.dbo.V_PM_Results_MDID_and_QID Source'
								Set @S = @S     + '    ON AJ.Task_ID = Source.Task_ID AND'
								Set @S = @S     + '       AJ.Task_Database = ''' + @CurrentMTDB + ''' AND'
								Set @S = @S     + '       AJ.Task_Server = ''' +  @CurrentServer + ''' AND'
								Set @S = @S     + '       AJ.Tool_ID = 1'
								Set @S = @S + ' WHERE '
								Set @S = @S     + ' (ISNULL(AJ.MD_ID, -1) <> Source.MD_ID) OR'
								Set @S = @S     + ' (ISNULL(AJ.QID, -1) <> Source.Quantitation_ID) OR'
								Set @S = @S     + ' (ISNULL(AJ.Ini_File_Name, '''') <> Source.Ini_File_Name) OR'
								Set @S = @S     + ' (ISNULL(AJ.Comparison_Mass_Tag_Count, -1) <> Source.Comparison_Mass_Tag_Count) OR'
								Set @S = @S     + ' (ISNULL(AJ.MD_State, 49) <> Source.MD_State)'

								If @PreviewSql <> 0
									Print @S
								Else
								Begin
									Exec (@S)
									
									SELECT @myError = @@error, @myRowCount = @@rowcount									
									Set @RowCountUpdated = @RowCountUpdated + @myRowCount
								End

								
							End -- </e3>
						End -- </d>
					
												
					End Try
					Begin Catch
						-- Error caught; log the error but continue processing additional databases
						Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'UpdateAnalysisJobDetailsVIPER')
						exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
												@ErrorNum = @myError output, @message = @message output
					End Catch
					
				End -- </c>
	
				Set @TotalDBsProcessed = @TotalDBsProcessed + 1
				
			End -- </b>	
					   
		End -- </a>

		Set @CurrentLocation = 'Done checking all DBs'

		if @TotalDBsProcessed > 0
		Begin
			Set @message = 'Updated VIPER task info in T_Analysis_Job for ' + Convert(varchar(12), @TotalDBsProcessed) + ' databases'							
			
			If @RowCountUpdated > 0
			Begin
				Set @message = @message + '; updated ' + Convert(varchar(12), @RowCountUpdated) + ' row'
				If @RowCountUpdated > 1
					Set @message = @message + 's'
			End
			
			Exec PostLogEntry 'Normal', @message, 'UpdateAnalysisJobDetailsVIPER'
		End


	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'UpdateAnalysisJobDetailsVIPER')
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
GRANT VIEW DEFINITION ON [dbo].[UpdateAnalysisJobDetailsVIPER] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[UpdateAnalysisJobDetailsVIPER] TO [MTS_DB_Lite] AS [dbo]
GO
