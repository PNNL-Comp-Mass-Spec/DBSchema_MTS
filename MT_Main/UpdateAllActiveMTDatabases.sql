/****** Object:  StoredProcedure [dbo].[UpdateAllActiveMTDatabases] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure UpdateAllActiveMTDatabases
/****************************************************
** 
**	Desc: Update all active PMT Tag databases
**
**	Return values: 0: success, otherwise, error code
** 
**	Parameters:
**
**	Auth:	grk
**	Date:	09/04/2002
**			04/12/2004 grk - removed scheduling code
**			04/14/2004 grk - added log verbosity control
**			04/16/2004 grk - added check of update state for assigned pepdide DB
**						   - replaced getdate() with { fn NOW() }
**			04/17/2004 mem - added logging of the number of databases updated
**			08/09/2004 mem - added use of T_Current_Activity_History
**			09/07/2004 mem - abandoned current activity table and switched to using MTL_Last_Import and MTL_Demand_Import
**			09/21/2004 mem - Updated to work with MTDBs with DBSchemaVersion = 2 and added MTL_Max_Jobs_To_Process column
**			10/06/2004 mem - Added field ET_Minutes_Last7Days
**			12/04/2004 mem - Now setting Update_State to 5 for skipped databases
**			05/05/2005 mem - Added checking for peptide databases with a null Last_Import date
**			07/10/2005 mem - Added call to UpdateAnalysisJobToMTDBMap
**			11/09/2005 mem - Removed deletion of old entries from T_Current_Activity_History since this is now done in UpdateAllActivePeptideDatabases
**			11/27/2005 mem - Added brackets around @MTL_Name as needed to allow for DBs with dashes in the name
**			12/12/2005 mem - Now calling UpdateAnalysisJobToMTDBMap every 18 hours
**			02/16/2005 mem - Now including the detailed error message when recording errors in the log
**			03/10/2006 mem - Now calling VerifyUpdateEnabled
**			03/13/2006 mem - Now posting a log entry at the start of UpdateAnalysisJobToMTDBMap
**			03/14/2006 mem - Now using column Pause_Length_Minutes
**			04/12/2006 mem - Now calling ShrinkTempDBLogIfRequired if any DB update lasts more than one minute
**			07/24/2006 mem - Now passing parameters @PeptideDBList and @ProteinDBList to GetMTAssignedDBs, then checking the update state of all peptide DBs mapped to a given PMT Tag DB
**			11/28/2006 mem - Added parameter @JobMapUpdateHoldoff
**			01/17/2007 mem - Updated to skip DBs with state >= 15 even if MTL_Demand_Import is non-zero
**			03/06/2007 mem - Switched to Try/Catch error handling
**			05/09/2007 mem - Now calling RefreshCachedDMSInfoIfRequired (Ticket:422)
**			05/31/2007 mem - Now setting @duplicateEntryHoldoffHours to 4 when calling PostLogEntry for various errors
**			11/14/2007 mem - Decreased @JobMapUpdateHoldoff to 4 hours since the execution speed of UpdateAnalysisJobToMTDBMap has been improved
**			01/25/2011 mem - Decreased @JobMapUpdateHoldoff to 0.9 hours
**			10/11/2013 mem - Switch to SCOPE_IDENTITY()
**			06/20/2017 mem - Expand @MTL_Name to varchar(128)
**    
*****************************************************/
(
	@JobMapUpdateHoldoff real = 0.9		-- Hours between call to UpdateAnalysisJobToMTDBMap
)
As
	set nocount on
	
	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	declare @result int
	declare @UpdateEnabled tinyint
	declare @SkipUpdate tinyint
	
	declare @MTL_Name varchar(128)
	declare @MTL_State int
	declare @MTL_ID int
	set @MTL_ID = 0

	declare @DBSchemaVersion real
	set @DBSchemaVersion = 1.0

	declare @StartDate datetime
	declare @CompletionDate datetime
	declare @PauseLengthMinutes real
	declare @ProcTimeMinutesLast24Hours float
	declare @ProcTimeMinutesLast7days float
	
	declare @message varchar(4096)

	declare @logVerbosity int -- 0 silent, 1 minimal, 2 verbose, 3 debug
	set @logVerbosity = 1

	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Begin Try -- <x>
		
		-- Validate that updating is enabled, abort if not enabled
		exec VerifyUpdateEnabled 'PMT_Tag_DB_Update', 'UpdateAllActiveMTDatabases', @AllowPausing = 0, @PostLogEntryIfDisabled = 0, @UpdateEnabled = @UpdateEnabled output, @message = @message output
		If @UpdateEnabled = 0
			Goto Done
	
		-----------------------------------------------------------
		-- log beginning of master update process
		-----------------------------------------------------------
		
		if @logVerbosity > 1
		begin
			set @message = 'Master Update Begun ' + convert(varchar(32), @myError)
			execute PostLogEntry 'Normal', @message, 'UpdateAllActiveMTDatabases'
		end
	
		-----------------------------------------------------------
		-- Find MT DB's that need to have new results imported
		-- For each, make sure it is present in T_Current_Activity and
		--  set Update_State = 1; however, do not actually update yet
		-----------------------------------------------------------
		--
		exec @myError = PreviewCurrentActivityForMTDBs @message = @message output
		if @myError <> 0
			Goto Done
	
		-----------------------------------------------------------
		-- process each entry in T_MT_Database_List
		-----------------------------------------------------------
	
		declare @skippedDBList varchar(2048)
		set @skippedDBList = ''
	
		declare @done int
		set @done = 0
	
		declare @processCount int
		set @processCount = 0
	
		declare @lastImport datetime
	
		declare @readyForImport float
		declare @demandImport int
		declare @importNeeded tinyint
		declare @skipImport tinyint
	
		declare @MatchCount int
	
		declare @maxJobsToProcess int
		set @maxJobsToProcess = 50000
		
		declare @SQLToExec nvarchar(1024)
	
		-----------------------------------------------------------
		-- Delete MT DB entries in the current activity table
		-- that are over 2 days old (and completed successfully)
		-----------------------------------------------------------
		DELETE FROM T_Current_Activity
		WHERE Update_State = 3 AND Update_Completed < GetDate() - 2 AND Type = 'MT'
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0 
		begin
			set @message = 'Could not delete old entries from the current activity table'
			set @myError = 38
			goto Done
		end
	
		-----------------------------------------------------------
		-- Look for MT databases that were created over 36 hours ago, but for which
		-- Last Import is null; record an error message in T_Log_Entries for any found
		--
		-- However, limit the time between posting errors to T_Log_Entries to be at least 12 hours,
		-- so first check if T_Log_Entries contains a recent error with message 'Database found which Null Last_Import date'
		-----------------------------------------------------------
		-- 
		Set @MatchCount = 0
		SELECT @MatchCount = COUNT(*)
		FROM T_Log_Entries
		WHERE Posted_By = 'UpdateAllActiveMTDatabases' AND 
			  Message Like 'Database found with null Last_Import date%'
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	
		If @MatchCount = 0
		Begin
			INSERT INTO T_Log_Entries
				(posted_by, posting_time, type, message)
			SELECT 'UpdateAllActiveMTDatabases' AS Posted_By, GETDATE() AS Posting_Time, 'Error' AS Type, 
				'Database found with null Last_Import date: ' + MTL_Name + ', created ' + CONVERT(varchar(32), MTL_Created) AS Message
			FROM T_MT_Database_List
			WHERE (DATEDIFF(hour, MTL_Created, GETDATE()) >= 36) AND 
				  (MTL_Last_Import IS NULL)
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
		End
	
		WHILE @done = 0 and @myError = 0  
		BEGIN -- <a>
	
			-- Get next entry
			Set @CurrentLocation = 'Get next available entry from mass tag database list table'
			
			SELECT TOP 1
				@MTL_ID = MTL_ID, 
				@MTL_Name = MTL_Name,
				@MTL_State = MTL_State,
				@lastImport = IsNull(MTL_Last_Import, 0),
				@readyForImport = DATEDIFF(Minute, IsNull(MTL_Last_Import, 0), GETDATE()) / 60.0 - ISNULL(MTL_Import_Holdoff, 24), 
				@demandImport = IsNull(MTL_Demand_Import, 0),
				@maxJobsToProcess = IsNull(MTL_Max_Jobs_To_Process, 50000)
			FROM  T_MT_Database_List
			WHERE    ( MTL_State IN (2, 5) OR
						IsNull(MTL_Demand_Import, 0) > 0
					  )  AND MTL_ID > @MTL_ID
			ORDER BY MTL_ID
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--
			if @myError <> 0 
			begin
				set @message = 'Could not get next entry from MT DB table'
				set @myError = 39
				goto Done
			end
			
			-- We are done if we didn't find any more records
			--
			If @myRowCount = 0
			Begin
				set @done = 1
			End
			Else
			Begin -- <b>
				Set @SkipUpdate = 0
				
				-----------------------------------------------------------
				-- Always skip DBs with States >= 15
				-- The only reason we would reach this code for a DB with state >= 15 is if
				--  MTL_Demand_Import is non-zero
				-----------------------------------------------------------
				Set @CurrentLocation = 'Determine @SkipUpdate'

				If @demandImport > 0 AND @MTL_State >= 15
				Begin
					set @SkipUpdate = 1
	
					set @message = 'Skipping update for database ' + @MTL_Name + ' since its state is ' + Convert(varchar(12), @MTL_State) + '; change MTL_Demand_Import to 0 for this DB to avoid this error message'
					execute PostLogEntry 'Error', @message, 'UpdateAllActiveMTDatabases', @duplicateEntryHoldoffHours=4
					set @message = ''
				End
				
				If @SkipUpdate = 0
				Begin -- <c>
					Begin Try -- <y>
						Set @CurrentLocation = 'Update ' + @MTL_Name
					
						-----------------------------------------------------------
						-- Decide if import is needed
						-----------------------------------------------------------		
						set @importNeeded = 0
						--
						if (@demandImport > 0) or (@readyForImport > 0) 
							set @importNeeded = 1
		
						-----------------------------------------------------------
						-- Perform update
						-----------------------------------------------------------
		
						-- Verify that this MT database is present in the current activity table,
						-- Add it if missing, or update if present
						--
						Set @MatchCount = 0
						SELECT @MatchCount = COUNT(*)
						FROM T_Current_Activity
						WHERE Database_ID = @MTL_ID AND Database_Name = @MTL_Name
						--
						SELECT @myError = @@error, @myRowCount = @@rowcount
		
						If @MatchCount = 0
						Begin
							INSERT INTO T_Current_Activity (Database_ID, Database_Name, Type, Update_Began, Update_Completed, 
															Pause_Length_Minutes, State, Update_State)
							VALUES (@MTL_ID, @MTL_Name, 'MT', GetDate(), Null,
									0, @MTL_State, 2)
						End
						Else
						Begin
							UPDATE T_Current_Activity
							SET	Database_Name = @MTL_Name, Update_Began = GetDate(), Update_Completed = Null, 
								Pause_Length_Minutes = 0, State = @MTL_State, Comment = '', Update_State = 2
							WHERE Database_ID = @MTL_ID AND Database_Name = @MTL_Name
						End
						--
						SELECT @myError = @@error, @myRowCount = @@rowcount
						--
						if @myError <> 0 
						begin
							set @message = 'Could not update current activity table'
							set @myError = 40
							goto Done
						end
		
						-- Lookup the DB Schema Version
						--
						Set @CurrentLocation = 'Call GetDBSchemaVersionByDBName for ' + @MTL_Name
						
						exec GetDBSchemaVersionByDBName @MTL_Name, @DBSchemaVersion output
		
						-- Get assigned peptide DB(s) and protein DB(s)
						--
						declare @PeptideDBName varchar(128)
						declare @ProteinDBName varchar(128)
						declare @PeptideDBList varchar(1024)
						declare @ProteinDBList varchar(1024)
		
						Set @CurrentLocation = 'Call GetMTAssignedDBs for ' + @MTL_Name

						exec @myError = GetMTAssignedDBs @MTL_Name, @PeptideDBName output, @ProteinDBName output, @DBSchemaVersion, @PeptideDBList output, @ProteinDBList output
						--
						if @myError <> 0 
						begin
							set @message = 'Could not get assigned peptide database'
							set @myError = 32
							goto Done
						end
						
						-- skip mass tag update if any of the assigned peptide DBs
						-- currently have an update in progress
						--
						declare @ptUpdateState int
						set @ptUpdateState = 0
						--
						Set @MatchCount = 0
						SELECT @MatchCount = Count(*)
						FROM T_Current_Activity INNER JOIN
							(	SELECT Value
								FROM dbo.udfParseDelimitedList(@PeptideDBList, ',')
							) PeptideQ ON PeptideQ.Value = T_Current_Activity.Database_Name
						WHERE Update_State IN (1, 2)
						--
						SELECT @myError = @@error, @myRowCount = @@rowcount
						--
						if @myError <> 0 
						begin
							set @message = 'Could not check update state of assigned peptide database'
							set @myError = 33
							goto Done
						end
						--
						if @MatchCount > 0
						begin
							set @skippedDBList = @skippedDBList + @MTL_Name + ', ' 
							UPDATE T_Current_Activity
							SET Update_State = 5
							WHERE Database_ID = @MTL_ID AND Database_Name = @MTL_Name
						end
						else
						Begin -- <d>
		
							-- log beginning of update for database
							--
							if @logVerbosity > 1
							begin
								set @message = 'Master Update Begun for ' + @MTL_Name
								execute PostLogEntry 'Normal', @message, 'UpdateAllActiveMTDatabases'
							end
		
							-- Cache the current start time
							--
							Set @StartDate = GetDate()
							
							-- get table counts before update (remember counts)
							--
							declare @count1 int
							declare @count2 int
							declare @count3 int
							declare @count4 int
							declare @historyID int
							
							declare @msg varchar(512)
							set @msg = ''
							Set @CurrentLocation = 'Call GetStatisticsFromExternalDB for ' + @MTL_Name
						
							exec GetStatisticsFromExternalDB @MTL_Name, 'MT', 'initial', 
									@count1 output, @count2 output, @count3 output, @count4 output, @msg output
		
							-- Append the values to T_Current_Activity_History
							--
							Set @historyId = 0
							INSERT INTO T_Current_Activity_History (Database_ID, Database_Name, Snapshot_Date, TableCount1, TableCount2, TableCount3, TableCount4)
							VALUES (@MTL_ID, @MTL_Name, GetDate(), @count1, @count2, @count3, @count4)
							--
							SELECT @historyId = SCOPE_IDENTITY()
							
							-- Lookup the table counts present at least 24 hours ago for this DB
							-- If this DB doesn't have values that were present 24 hours ago, then the @count variables will remain unchanged
							--
							SELECT TOP 1 @count1 = TableCount1, @count2 = TableCount2, @count3 = TableCount3, @count4 = TableCount4
							FROM (	SELECT TableCount1, TableCount2, TableCount3, TableCount4, Snapshot_Date
									FROM T_Current_Activity_History
									WHERE Database_ID = @MTL_ID AND Database_Name = @MTL_Name 
											AND (Snapshot_Date < GETDATE() - 1)) AS LookupQ
							ORDER BY Snapshot_Date DESC
		
							declare @StoredProcFound int

							If @importNeeded > 0
							Begin
								-----------------------------------------------------------
								-- Make sure the cached DMS Job and Dataset info was refreshed less than 60 minutes ago
								-----------------------------------------------------------
								Exec RefreshCachedDMSInfoIfRequired @UpdateInterval=1.0
							End
							
							If @DBSchemaVersion < 2
							Begin -- <e>
								if @importNeeded > 0
								
									-----------------------------------------------------------
									-- call MasterUpdateProcess sproc in DB if it exists
									------------------------------------------------------------
									Set @CurrentLocation = 'Call MasterUpdateProcess for ' + @MTL_Name

									exec @result = CallStoredProcInExternalDB
														@MTL_Name,	
														'MasterUpdateProcess',
														0,
														@StoredProcFound Output,
														@message Output
							End	 -- </e>
							Else
							Begin -- <e>
								-- @DBSchemaVersion is >= 2
		
								if @importNeeded > 0
									Set @skipImport = 0
								Else
									Set @skipImport = 1
								
								-----------------------------------------------------------
								-- Confirm that MasterUpdateMassTags sproc exists in DB
								-----------------------------------------------------------
								Set @CurrentLocation = 'Look for MasterUpdateMassTags in ' + @MTL_Name

								exec @result = CallStoredProcInExternalDB
													@MTL_Name,	
													'MasterUpdateMassTags',
													1,
													@StoredProcFound Output,
													@message Output
		
								If @StoredProcFound <> 0
								Begin
									Set @CurrentLocation = 'Call MasterUpdateMassTags in ' + @MTL_Name

									Set @SQLToExec = N'[' + Convert(nvarchar(256), @MTL_Name) + N']..MasterUpdateMassTags' + ' ' + Convert(nvarchar(15), @maxJobsToProcess) + ', ' + Convert(nvarchar(2), @skipImport)
									EXEC @result = sp_executesql @SQLToExec
								End
		
						
							End -- </e>
		
							-- get table counts (added for update)
							--
							Set @CurrentLocation = 'Call GetStatisticsFromExternalDB for ' + @MTL_Name
						
							exec GetStatisticsFromExternalDB @MTL_Name, 'MT', 'final', 
									@count1 output, @count2 output, @count3 output, @count4 output, @msg output
							
							Set @CurrentLocation = 'Record update complete for ' + @MTL_Name
						
							-- Cache the current completion time
							--
							Set @CompletionDate = GetDate()
		
							-- Populate @PauseLengthMinutes
							Set @PauseLengthMinutes = 0
							SELECT @PauseLengthMinutes = Pause_Length_Minutes
							FROM T_Current_Activity
							WHERE Database_Name = @MTL_Name
		
							-- Update completion date and Pause Length for MT database in the current activity history table
							UPDATE T_Current_Activity_History
							SET Update_Completion_Date = @CompletionDate, 
								Pause_Length_Minutes = @PauseLengthMinutes
							WHERE History_ID = @historyId
							--
							SELECT @myError = @@error, @myRowCount = @@rowcount
		
		
							-- Compute the total processing time for the last 24 hours for this database,
							Set @ProcTimeMinutesLast24Hours = 0
							
							SELECT @ProcTimeMinutesLast24Hours = ROUND(SUM(ISNULL(DATEDIFF(second, Snapshot_Date, Update_Completion_Date), 0) / 60.0 - Pause_Length_Minutes), 1)
							FROM T_Current_Activity_History
							WHERE (DATEDIFF(minute, ISNULL(Update_Completion_Date, @CompletionDate), @CompletionDate) / 60.0 <= 24) AND 
									Database_ID = @MTL_ID AND Database_Name = @MTL_Name
							GROUP BY Database_Name
							--
							SELECT @myError = @@error, @myRowCount = @@rowcount
		
		
							-- Compute the total processing time for the last 7 days for this database,
							Set @ProcTimeMinutesLast7days = 0
							
							SELECT @ProcTimeMinutesLast7days = ROUND(SUM(ISNULL(DATEDIFF(second, Snapshot_Date, Update_Completion_Date), 0) / 60.0 - Pause_Length_Minutes), 1)
							FROM T_Current_Activity_History
							WHERE (DATEDIFF(hour, ISNULL(Update_Completion_Date, @CompletionDate), @CompletionDate) / 24.0 <= 7) AND 
									Database_ID = @MTL_ID AND Database_Name = @MTL_Name
							GROUP BY Database_Name
							--
							SELECT @myError = @@error, @myRowCount = @@rowcount
		
						
							-- update completion date for MT database in current activity table
							--
							UPDATE	T_Current_Activity
							SET		Update_Completed = @CompletionDate, Comment = @msg, Update_State = 3, 
									ET_Minutes_Last24Hours = @ProcTimeMinutesLast24Hours,
									ET_Minutes_Last7Days = @ProcTimeMinutesLast7days
							WHERE	Database_ID = @MTL_ID AND Database_Name = @MTL_Name
							--
							SELECT @myError = @@error, @myRowCount = @@rowcount
							--
							if @myError <> 0 
							begin
								set @message = 'Could not update current activity table'
								set @myError = 41
								goto Done
							end
		
							-- update completion date for MT database in MT database list
							--
							if @importNeeded > 0
								set @lastImport = @CompletionDate
							--
							UPDATE	T_MT_Database_List
							SET
								MTL_Last_Import = @lastImport,
								MTL_Last_Update = @CompletionDate,
								MTL_Demand_Import = 0
							WHERE	MTL_ID = @MTL_ID
							--
							SELECT @myError = @@error, @myRowCount = @@rowcount
							--
							if @myError <> 0 
							begin
								set @message = 'Could not update current MT database list table'
								set @myError = 42
								goto Done
							end
		
							-- If the update took more than 1 minute, then call ShrinkTempDBLogIfRequired
							If DateDiff(minute, @StartDate, @CompletionDate) >= 1
								exec ShrinkTempDBLogIfRequired
							
							-- Increment the databases processed count
							set @processCount = @processCount + 1
		
							Set @CurrentLocation = 'Log end of update for ' + @MTL_Name
							--
							if @logVerbosity > 1 OR (@logVerbosity > 0 AND @importNeeded > 0)
							begin
								set @message = 'Master Update Complete for ' + @MTL_Name
								execute PostLogEntry 'Normal', @message, 'UpdateAllActiveMTDatabases'
							end
						End -- </d>
					End Try -- </y>
					Begin Catch
						-- Error caught; log the error then abort processing
						Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'UpdateAllActiveMTDatabases')
						exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
												@ErrorNum = @myError output, @message = @message output
						Goto Done
					End Catch
				End -- </c>
			End -- </b>
	
			Set @CurrentLocation = 'Call VerifyUpdateEnabled for PMT_Tag_DB_Update'

			-- Validate that updating is enabled, abort if not enabled
			exec VerifyUpdateEnabled 'PMT_Tag_DB_Update', 'UpdateAllActiveMTDatabases', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
			If @UpdateEnabled = 0
				Goto Done
	
		END -- </a>
	
	
		-----------------------------------------------------------
		-- Update T_Analysis_Job_to_MT_DB_Map for all MT Databases (with MTL_State < 10)
		-- However, only call this SP once every @JobMapUpdateHoldoff hours
		-----------------------------------------------------------
		--
		Declare @PostingTime datetime
		Set @PostingTime = '1/1/2000'
	
		Set @JobMapUpdateHoldoff = IsNull(@JobMapUpdateHoldoff, 1)
				
		SELECT TOP 1 @PostingTime = Posting_Time
		FROM T_Log_Entries
		WHERE Message LIKE 'UpdateAnalysisJobToMTDBMap Complete%'
		ORDER BY Entry_ID DESC
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @JobMapUpdateHoldoff <=0 Or DateDiff(minute, @PostingTime, GetDate()) / 60.0 >= @JobMapUpdateHoldoff OR @myRowCount = 0
		Begin
			Set @CurrentLocation = 'Call UpdateAnalysisJobToMTDBMap'
			
			set @message = 'UpdateAnalysisJobToMTDBMap Starting'
			If @logVerbosity > 1
				execute PostLogEntry 'Normal', @message, 'UpdateAllActiveMTDatabases'
	
			Set @message = ''
			Exec @result = UpdateAnalysisJobToMTDBMap @message = @message Output
	
			if @result <> 0
			begin
				If @result = 55000
				Begin
					set @message = 'Call to UpdateAnalysisJobToMTDBMap aborted'
					If @logVerbosity > 0
						execute PostLogEntry 'Warning', @message, 'UpdateAllActiveMTDatabases'
				End
				Else
				Begin
					set @message = 'Error calling UpdateAnalysisJobToMTDBMap: ' + @message + ' (error code ' + convert(varchar(11), @result) + ')'
					If @logVerbosity > 0
						execute PostLogEntry 'Error', @message, 'UpdateAllActiveMTDatabases'
				End
			end
			else
			begin
				set @message = 'UpdateAnalysisJobToMTDBMap Complete; ' + @message
				If @logVerbosity > 0
					execute PostLogEntry 'Normal', @message, 'UpdateAllActiveMTDatabases'
			end
		End
		
			
		-----------------------------------------------------------
		-- log successful completion of master update process
		-----------------------------------------------------------
		
		Set @CurrentLocation = 'Log completion of master update process'
		
		if @logVerbosity > 1
		begin
			set @message = 'Updated active mass tag databases: ' + convert(varchar(32), @processCount) + ' processed'
			execute PostLogEntry 'Normal', @message, 'UpdateAllActiveMTDatabases'
		end
		
		if @logVerbosity > 1
		begin
			set @message = 'Master Update Completed ' + convert(varchar(32), @myError)
			execute PostLogEntry 'Normal', @message, 'UpdateAllActiveMTDatabases'
		end

	End Try -- </x>
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'UpdateAllActiveMTDatabases')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
								@ErrorNum = @myError output, @message = @message output
		Goto Done
	End Catch
	
Done:
	-----------------------------------------------------------
	-- log skipped updates
	-----------------------------------------------------------
	--
	if @skippedDBList <> '' and @logVerbosity > 0
	begin
		set @message = 'Update was skipped since peptide DB(s) updating: ' + @skippedDBList
		execute PostLogEntry 'Error', @message, 'UpdateAllActiveMTDatabases', @duplicateEntryHoldoffHours=4
	end

	-----------------------------------------------------------
	-- Exit
	-----------------------------------------------------------
	--
	if @myError <> 0 and @logVerbosity > 0
	begin
		set @message = 'Master Update Error ' + convert(varchar(32), @myError) + ' occurred; ' + IsNull(@message, 'Unknown error')
		execute PostLogEntry 'Error', @message, 'UpdateAllActiveMTDatabases'
		
		-- set upate state to failed
	end

	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[UpdateAllActiveMTDatabases] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[UpdateAllActiveMTDatabases] TO [MTS_DB_Lite] AS [dbo]
GO
