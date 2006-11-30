/****** Object:  StoredProcedure [dbo].[UpdateAllActivePeptideDatabases] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure UpdateAllActivePeptideDatabases
/****************************************************
** 
**	Desc: Update all active Peptide databases
**
**	Return values: 0: success, otherwise, error code
** 
**	Parameters:
**
**	Auth:	grk
**	Date:	09/4/2002
**			04/12/2004 grk - removed scheduling code
**			04/14/2004 grk - added log verbosity control
**			04/16/2004 grk - replaced getdate() with { fn NOW() }
**						   - added call to AddParamFileNamesAndPeptideMods
**			04/17/2004 mem - Moved call to AddParamFileNamesAndPeptideMods
**						   - added logging of the number of databases updated
**			07/14/2004 grk - abandoned current activity table and added calls to new peptide db versions
**			08/11/2004 mem - Replaced call to AddParamFileNamesAndPeptideMods with call to 
**							 RefreshParamFileNamesAndPeptideMods and added tracking of DB update stats 
**							  in T_Current_Activity and T_Current_Activity_History
**			09/09/2004 mem - Now setting Update_State to 1 for all PTDB's and MTDB's that will need to be updated
**			09/22/2004 mem - Added PDB_Max_Jobs_To_Process column and GetDBSchemaVersion calls
**			10/06/2004 mem - Added field ET_Minutes_Last7Days
**			10/23/2004 mem - Added call to UpdateAnalysisJobToPeptideDBMap
**			05/05/2005 mem - Added checking for peptide databases with a null Last_Import date
**			07/10/2005 mem - Moved call to UpdateAnalysisJobToPeptideDBMap to after the main update loop
**			08/10/2005 mem - Updated retention time for T_Current_Activity_History from 14 to 120 days
**			11/27/2005 mem - Added brackets around @PDB_Name as needed to allow for DBs with dashes in the name
**			02/16/2005 mem - Now including the detailed error message when recording errors in the log
**			03/13/2006 mem - Now calling VerifyUpdateEnabled
**			03/14/2006 mem - Now using column Pause_Length_Minutes
**			04/12/2006 mem - Now calling ShrinkTempDBLogIfRequired if any DB update lasts more than one minute
**			07/15/2006 mem - Updated list of database states to process to include state 7
**						   - Removed support for DB Schema Version 1
**			11/28/2006 mem - Added parameter @JobMapUpdateHoldoff
**    
*****************************************************/
(
	@JobMapUpdateHoldoff int = 12		-- Hours between call to UpdateAnalysisJobToMTDBMap
)
As	
	set nocount on
	
	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	declare @result int
	
	declare @PDB_Name varchar(64)
	declare @PDB_State int
	declare @PDB_ID int
	
	declare @DBSchemaVersion real
	set @DBSchemaVersion = 1.0

	declare @MTL_Name varchar(128)
	declare @MTL_State int
	declare @MTL_ID int
	
	declare @StartDate datetime
	declare @CompletionDate datetime
	declare @PauseLengthMinutes real
	declare @ProcTimeMinutesLast24Hours float
	declare @ProcTimeMinutesLast7days float
	
	declare @message varchar(255)
	declare @UpdateEnabled tinyint
	
	declare @logVerbosity int -- 0 silent, 1 minimal, 2 verbose, 3 debug
	set @logVerbosity = 1

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled 'Peptide_DB_Update', 'UpdateAllActivePeptideDatabases', @AllowPausing = 0, @PostLogEntryIfDisabled = 0, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done

	-----------------------------------------------------------
	-- log beginning of master update process
	-----------------------------------------------------------

	if @logVerbosity > 1
	begin
		set @message = 'Master Update Begun ' + convert(varchar(32), @myError)
		execute PostLogEntry 'Normal', @message, 'UpdateAllActivePeptideDatabases'
	end

	-----------------------------------------------------------
	-- process each entry in T_Peptide_Database_List
	-----------------------------------------------------------

	declare @done int
	set @done = 0

	declare @ProcessCount int
	set @ProcessCount = 0

	declare @paramFileCacheRefreshed tinyint
	set @paramFileCacheRefreshed = 0
	
	declare @lastImport datetime

	declare @readyForImport float
	declare @demandImport int
	declare @matchCount int
	
	declare @maxJobsToProcess int
	set @maxJobsToProcess = 50000
	
	declare @SQLToExec nvarchar(1024)
	
	-----------------------------------------------------------
	-- Delete Peptide DB entries in the current activity table
	-- that are over 2 days old (and completed successfully)
	-----------------------------------------------------------
	DELETE FROM T_Current_Activity
	WHERE Update_State = 3 AND Update_Completed < GetDate() - 2 AND Type = 'PT'
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
	-- Delete entries in the current activity history table
	-- that are over 120 days old, but always retain at least
	-- one entry for each database
	-----------------------------------------------------------
	DELETE FROM T_Current_Activity_History
	WHERE Snapshot_Date < GetDate() - 120 AND 
		  History_ID NOT IN (	SELECT MAX(History_ID) AS History_ID_Max
								FROM T_Current_Activity_History
								GROUP BY Database_ID, Database_Name)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 
	begin
		set @message = 'Could not delete old entries from the current activity history table'
		set @myError = 38
		goto Done
	end

	-----------------------------------------------------------
	-- Look for peptide databases that were created over 36 hours ago, but for which
	-- Last Import is null; record an error message in T_Log_Entries for any found
	--
	-- However, limit the time between posting errors to T_Log_Entries to be at least 12 hours,
	-- so first check if T_Log_Entries contains a recent error with message 'Database found which Null Last_Import date'
	-----------------------------------------------------------
	-- 
	Set @MatchCount = 0
	SELECT @MatchCount = COUNT(*)
	FROM T_Log_Entries
	WHERE Posted_By = 'UpdateAllActivePeptideDatabases' AND 
		  Message Like 'Database found with null Last_Import date%'
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	If @MatchCount = 0
	Begin
		INSERT INTO T_Log_Entries
			(posted_by, posting_time, type, message)
		SELECT 'UpdateAllActivePeptideDatabases' AS Posted_By, GETDATE() AS Posting_Time, 'Error' AS Type, 
			'Database found with null Last_Import date: ' + PDB_Name + ', created ' + CONVERT(varchar(32), PDB_Created) AS Message
		FROM T_Peptide_Database_List
		WHERE (DATEDIFF(hour, PDB_Created, GETDATE()) >= 36) AND 
			  (PDB_Last_Import IS NULL)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	End


	-----------------------------------------------------------
	-- Find peptide DB's that need to have new results imported
	-- For each, make sure it is present in T_Current_Activity and
	--  set Update_State = 1; however, do not actually update yet
	-----------------------------------------------------------
	--
	exec @myError = PreviewCurrentActivityForPeptideDBs @message = @message output
	if @myError <> 0
		Goto Done
	
	-----------------------------------------------------------
	-- Find MT DB's that need to have new results imported
	-- For each, make sure it is present in T_Current_Activity and
	--  set Update_State = 1; however, do not actually update yet
	-----------------------------------------------------------
	--
	exec @myError = PreviewCurrentActivityForMTDBs @message = @message output
	if @myError <> 0
		Goto Done


	set @PDB_ID = 0
	set @done = 0
	--	
	WHILE @done = 0 and @myError = 0  
	BEGIN -- <a>

		-----------------------------------------------------------
		-- get next available entry from peptide database list table
		-----------------------------------------------------------
		--
		SELECT TOP 1
			@PDB_ID = PDB_ID, 
			@PDB_Name = PDB_Name,
			@PDB_State = PDB_State,
			@lastImport = IsNull(PDB_Last_Import, 0),
			@readyForImport = DATEDIFF(Minute, IsNull(PDB_Last_Import, 0), GETDATE()) / 60.0 - ISNULL(PDB_Import_Holdoff, 24), 
			@demandImport = IsNull(PDB_Demand_Import, 0),
			@maxJobsToProcess = IsNull(PDB_Max_Jobs_To_Process, 50000)
		FROM  T_Peptide_Database_List
		WHERE     ( PDB_State IN (2, 5, 7) OR
					IsNull(PDB_Demand_Import, 0) > 0
				  ) AND PDB_ID > @PDB_ID
		ORDER BY PDB_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0 
		begin
			set @message = 'Could not get next entry from peptide DB table'
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

			-----------------------------------------------------------
			-- Decide if import is needed
			-----------------------------------------------------------		
			declare @importNeeded tinyint
			set @importNeeded = 0
			--
			if (@demandImport > 0) or (@readyForImport > 0) 
				set @importNeeded = 1

			-----------------------------------------------------------
			-- Perform update
			-----------------------------------------------------------

			-- Verify that this peptide database is present in the current activity table,
			-- Add it if missing, or update if present
			--
			Set @matchCount = 0
			SELECT @matchCount = COUNT(*)
			FROM T_Current_Activity
			WHERE Database_ID = @PDB_ID AND Database_Name = @PDB_Name
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			If @matchCount = 0
				INSERT INTO T_Current_Activity (Database_ID, Database_Name, Type, Update_Began, Update_Completed, 
												Pause_Length_Minutes, State, Update_State)
				VALUES (@PDB_ID, @PDB_Name, 'PT', GetDate(), Null,
						0, @PDB_State, 2)
			Else
				UPDATE T_Current_Activity
				SET	Database_Name = @PDB_Name, Update_Began = GetDate(), Update_Completed = Null, 
					Pause_Length_Minutes = 0, State = @PDB_State, Comment = '', Update_State = 2
				WHERE Database_ID = @PDB_ID AND Database_Name = @PDB_Name
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
			exec GetDBSchemaVersionByDBName @PDB_Name, @DBSchemaVersion output
			
			-- log beginning of update for database
			--
			if @logVerbosity > 1
			begin
				set @message = 'Master Update Begun for ' + @PDB_Name
				execute PostLogEntry 'Normal', @message, 'UpdateAllActivePeptideDatabases'
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
			declare @historyId int
			
			declare @msg varchar(512)
			set @msg = ''
			exec GetStatisticsFromExternalDB @PDB_Name, 'PT', 'initial', 
					@count1 output, @count2 output, @count3 output, @count4 output, @msg output

			-- Append the values to T_Current_Activity_History
			--
			Set @historyId = 0
			INSERT INTO T_Current_Activity_History (Database_ID, Database_Name, Snapshot_Date, TableCount1, TableCount2, TableCount3, TableCount4)
			VALUES (@PDB_ID, @PDB_Name, GetDate(), @count1, @count2, @count3, @count4)
			--
			SELECT @historyId = @@Identity
			
			-- Lookup the table counts present at least 24 hours ago for this DB
			-- If this DB doesn't have values that were present 24 hours ago, then the @count variables will remain unchanged
			--
			SELECT TOP 1 @count1 = TableCount1, @count2 = TableCount2, @count3 = TableCount3, @count4 = TableCount4
			FROM (	SELECT TableCount1, TableCount2, TableCount3, TableCount4, Snapshot_Date
					FROM T_Current_Activity_History
					WHERE Database_ID = @PDB_ID AND Database_Name = @PDB_Name 
						AND (Snapshot_Date < GETDATE() - 1)
				) AS LookupQ
			ORDER BY Snapshot_Date DESC


			declare @StoredProcFound int

			if @DBSchemaVersion < 2
			Begin -- <c>
				set @message = 'Unable to update database ' + @PDB_Name + '; DB Schema Version 1 is no longer supported for peptide databases'
				execute PostLogEntry 'Error', @message, 'UpdateAllActivePeptideDatabases'
				set @message = ''

/*				
				if @importNeeded > 0
				begin
					
					-----------------------------------------------------------
					-- Update the param file names and peptide mods the first time
					-- this code is reached
					-----------------------------------------------------------	
					if @paramFileCacheRefreshed = 0
					begin
						Exec RefreshParamFileNamesAndPeptideMods
						Set @paramFileCacheRefreshed = 1
					end
					
					-----------------------------------------------------------
					-- call old version master update sproc in DB if it exists
					-----------------------------------------------------------	
					exec @result = CallStoredProcInExternalDB
										@PDB_Name,	
										'MasterUpdatePeptideProcess',
										0,
										@StoredProcFound Output,
										@message Output


				end
*/

			End -- </c>
			Else
			Begin -- <c>
				-- @DBSchemaVersion is >= 2

				If @importNeeded > 0
				Begin
					-----------------------------------------------------------
					-- Call the MasterUpdateProcessImport sproc
					-----------------------------------------------------------	
					exec @result = CallStoredProcInExternalDB
										@PDB_Name,	
										'MasterUpdateProcessImport',
										0,
										@StoredProcFound Output,
										@message Output
				End
				
				-----------------------------------------------------------
				-- Confirm that the MasterUpdateProcessBackground sproc exists in DB
				-----------------------------------------------------------	
				exec @result = CallStoredProcInExternalDB
									@PDB_Name,	
									'MasterUpdateProcessBackground',
									1,
									@StoredProcFound Output,
									@message Output

				If @StoredProcFound <> 0
				Begin
					Set @SQLToExec = N'[' + Convert(nvarchar(256), @PDB_Name) + N']..MasterUpdateProcessBackground' + ' ' + Convert(nvarchar(15), @maxJobsToProcess)
					EXEC @result = sp_executesql @SQLToExec
				End
			End -- </c>

			
			-- get table counts (added for update)
			--
			exec GetStatisticsFromExternalDB @PDB_Name, 'PT', 'final', 
					@count1 output, @count2 output, @count3 output, @count4 output, @msg output
			
			-- Cache the current completion time
			--
			Set @CompletionDate = GetDate()
			
			-- Populate @PauseLengthMinutes
			Set @PauseLengthMinutes = 0
			SELECT @PauseLengthMinutes = Pause_Length_Minutes
			FROM T_Current_Activity
			WHERE Database_Name = @PDB_Name

			-- Update completion date and Pause Length for PT database in the current activity history table
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
				Database_ID = @PDB_ID AND Database_Name = @PDB_Name
			GROUP BY Database_Name
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount


			-- Compute the total processing time for the last 7 days for this database,
			Set @ProcTimeMinutesLast7days = 0
			
			SELECT @ProcTimeMinutesLast7days = ROUND(SUM(ISNULL(DATEDIFF(second, Snapshot_Date, Update_Completion_Date), 0) / 60.0 - Pause_Length_Minutes), 1)
			FROM T_Current_Activity_History
			WHERE (DATEDIFF(hour, ISNULL(Update_Completion_Date, @CompletionDate), @CompletionDate) / 24.0 <= 7) AND 
					Database_ID = @PDB_ID AND Database_Name = @PDB_Name
			GROUP BY Database_Name
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount


			-- Update completion date in the current activity table
			--
			UPDATE	T_Current_Activity
			SET Update_Completed = @CompletionDate, Comment = @msg, Update_State = 3, 
				ET_Minutes_Last24Hours = @ProcTimeMinutesLast24Hours,
				ET_Minutes_Last7Days = @ProcTimeMinutesLast7days
			WHERE Database_ID = @PDB_ID AND Database_Name = @PDB_Name
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--
			if @myError <> 0 
			begin
				set @message = 'Could not update current activity table'
				set @myError = 41
				goto Done
			end
			
			
			-- update completion dates for PT database
			--
			if @importNeeded > 0
				set @lastImport = @CompletionDate
			--
			UPDATE T_Peptide_Database_List
			SET 
				PDB_Last_Import = @lastImport,
				PDB_Last_Update = @CompletionDate,
				PDB_Demand_Import = 0
			WHERE (PDB_ID = @PDB_ID)
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--
			if @myError <> 0 
			begin
				set @message = 'Could not update current PT database list table'
				set @myError = 42
				goto Done
			end

			-- If the update took more than 1 minute, then call ShrinkTempDBLogIfRequired
			If DateDiff(minute, @StartDate, @CompletionDate) >= 1
				exec ShrinkTempDBLogIfRequired

			-- Increment the databases processed count
			set @ProcessCount = @ProcessCount + 1
			
			-- log end of update for database
			--
			if @logVerbosity > 1 OR (@logVerbosity > 0 AND @importNeeded > 0)
			begin
				set @message = 'Master Update Complete for ' + @PDB_Name
				execute PostLogEntry 'Normal', @message, 'UpdateAllActivePeptideDatabases'
			end

		End -- </b>

		-- Validate that updating is enabled, abort if not enabled
		exec VerifyUpdateEnabled 'Peptide_DB_Update', 'UpdateAllActivePeptideDatabases', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
		If @UpdateEnabled = 0
			Goto Done

	END -- </a>


	-----------------------------------------------------------
	-- Update T_Analysis_Job_to_Peptide_DB_Map for all Peptide Databases (with PDB_State < 10)
	-- However, only call this SP once every 12 hours since it can take a while to run
	-----------------------------------------------------------
	--
	Declare @PostingTime datetime
	Set @PostingTime = '1/1/2000'
	
	Set @JobMapUpdateHoldoff = IsNull(@JobMapUpdateHoldoff, 12)
	
	SELECT TOP 1 @PostingTime = Posting_Time
	FROM T_Log_Entries
	WHERE Message LIKE 'UpdateAnalysisJobToPeptideDBMap Complete%'
	ORDER BY Entry_ID DESC
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	If @JobMapUpdateHoldoff <=0 Or DateDiff(hour, @PostingTime, GetDate()) >= @JobMapUpdateHoldoff OR @myRowCount = 0
	Begin
		set @message = 'UpdateAnalysisJobToPeptideDBMap Starting'
		If @logVerbosity > 0
			execute PostLogEntry 'Normal', @message, 'UpdateAllActivePeptideDatabases'

		Set @message = ''
		Exec @result = UpdateAnalysisJobToPeptideDBMap @message = @message Output

		if @result <> 0
		begin
			If @result = 55000
			Begin
				set @message = 'Call to UpdateAnalysisJobToPeptideDBMap aborted'
				If @logVerbosity > 0
					execute PostLogEntry 'Warning', @message, 'UpdateAllActivePeptideDatabases'
			End
			Else
			Begin
				set @message = 'Error calling UpdateAnalysisJobToPeptideDBMap: ' + @message + ' (error code ' + convert(varchar(11), @result) + ')'
				If @logVerbosity > 0
					execute PostLogEntry 'Error', @message, 'UpdateAllActivePeptideDatabases'
			End
		end
		else
		begin
			set @message = 'UpdateAnalysisJobToPeptideDBMap Complete; ' + @message
			If @logVerbosity > 0
				execute PostLogEntry 'Normal', @message, 'UpdateAllActivePeptideDatabases'
		end
	End

	-----------------------------------------------------------
	-- log successful completion of master update process
	-----------------------------------------------------------
	
	if @logVerbosity > 1
	begin
		set @message = 'Updated active peptide databases: ' + convert(varchar(32), @ProcessCount) + ' processed'
		execute PostLogEntry 'Normal', @message, 'UpdateAllActivePeptideDatabases'
	end
	
	if @logVerbosity > 1
	begin
		set @message = 'Master Update Completed ' + convert(varchar(32), @myError)
		execute PostLogEntry 'Normal', @message, 'UpdateAllActivePeptideDatabases'
	end

Done:
	-----------------------------------------------------------
	-- Exit
	-----------------------------------------------------------
	--
	if @myError <> 0 and @logVerbosity > 0
	begin
		set @message = 'Master Update Error ' + convert(varchar(32), @myError) + ' occurred; ' + IsNull(@message, 'Unknown error')
		execute PostLogEntry 'Error', @message, 'UpdateAllActivePeptideDatabases'
	end

	return @myError

GO
