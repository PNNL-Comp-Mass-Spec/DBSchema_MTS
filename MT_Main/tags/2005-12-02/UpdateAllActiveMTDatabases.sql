SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[UpdateAllActiveMTDatabases]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[UpdateAllActiveMTDatabases]
GO

CREATE Procedure UpdateAllActiveMTDatabases
/****************************************************
** 
**		Desc: 
**
**		Return values: 0: success, otherwise, error code
** 
**		Parameters:
**
**		Auth: grk
**		Date: 9/4/2002
**
**      Updated
**		04/12/2004 grk - removed scheduling code
**		04/14/2004 grk - added log verbosity control
**		04/16/2004 grk - added check of update state for assigned pepdide DB
**		               - replaced getdate() with { fn NOW() }
**		04/17/2004 mem - added logging of the number of databases updated
**		08/09/2004 mem - added use of T_Current_Activity_History
**		09/07/2004 mem - abandoned current activity table and switched to using MTL_Last_Import and MTL_Demand_Import
**		09/21/2004 mem - Updated to work with MTDBs with DBSchemaVersion = 2 and added MTL_Max_Jobs_To_Process column
**		10/06/2004 mem - Added field ET_Minutes_Last7Days
**		12/04/2004 mem - Now setting Update_State to 5 for skipped databases
**		05/05/2005 mem - Added checking for peptide databases with a null Last_Import date
**		07/10/2005 mem - Added call to UpdateAnalysisJobToMTDBMap
**		11/09/2005 mem - Removed deletion of old entries from T_Current_Activity_History since this is now done in UpdateAllActivePeptideDatabases
**	    11/27/2005 mem - Added brackets around @MTL_Name as needed to allow for DBs with dashes in the name
**    
*****************************************************/
As
	set nocount on
	
	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	declare @result int

	declare @MTL_Name varchar(64)
	declare @MTL_State int
	declare @MTL_ID int
	set @MTL_ID = 0

	declare @DBSchemaVersion real
	set @DBSchemaVersion = 1.0

	declare @completionDate datetime
	declare @procTimeMinutesLast24Hours float
	declare @procTimeMinutesLast7days float
	
	declare @message varchar(255)

	declare @logVerbosity int -- 0 silent, 1 minimal, 2 verbose, 3 debug
	set @logVerbosity = 1


	-----------------------------------------------------------
	-- log beginning of master update process
	-----------------------------------------------------------
	
	if @logVerbosity > 1
	begin
		set @message = 'Master Update Begun ' + convert(varchar(32), @myError)
		execute PostLogEntry 'Normal', @message, 'UpdateAllActiveMTDatabases'
	end

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

	declare @matchCount int

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
	BEGIN --<a>

		-----------------------------------------------------------
		-- get next available entry from mass tag database list table
		-----------------------------------------------------------
		--
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
				  )  AND MTL_ID > @MTL_ID AND charindex(MTL_Name, @skippedDBList) = 0
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
		if @myRowCount = 0
		begin
			set @done = 1
			goto Skip
		end

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
		Set @matchCount = 0
		SELECT @matchCount = COUNT(*)
		FROM T_Current_Activity
		WHERE Database_ID = @MTL_ID AND Database_Name = @MTL_Name
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @matchCount = 0
			INSERT INTO T_Current_Activity (Database_ID, Database_Name, Type, Update_Began, State, Update_State)
			VALUES (@MTL_ID, @MTL_Name, 'MT', GetDate(), @MTL_State, 2)
		Else
			UPDATE T_Current_Activity
			SET	Database_Name = @MTL_Name, Update_Began = GetDate(), Update_Completed = Null, State = @MTL_State, Comment = '', Update_State = 2
			WHERE Database_ID = @MTL_ID AND Database_Name = @MTL_Name
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
		exec GetDBSchemaVersionByDBName @MTL_Name, @DBSchemaVersion output


		-- Get assigned peptide DB and protein DB
		--
		declare @peptideDBName varchar(128)
		declare @proteinDBName varchar(128)
		exec @myError = GetMTAssignedDBs @MTL_Name, @peptideDBName output, @proteinDBName output, @DBSchemaVersion
		--
		if @myError <> 0 
		begin
			set @message = 'Could not get assigned peptide database'
			set @myError = 32
			goto Done
		end
		
		-- skip mass tag update if assigned peptide DB
		-- currently has update in progress
		--
		declare @ptUpdateState int
		set @ptUpdateState = 0
		--
		SELECT @ptUpdateState = Update_State 
		FROM T_Current_Activity 
		WHERE Database_Name = @peptideDBName
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		--
		if @myError <> 0 
		begin
			set @message = 'Could not check update state of assigned peptide database'
			set @myError = 33
			goto Done
		end
		--
		if @ptUpdateState in (1, 2) 
		begin
			set @skippedDBList = @skippedDBList + @MTL_Name + ', ' 
			UPDATE T_Current_Activity
			SET Update_State = 5
			WHERE Database_ID = @MTL_ID AND Database_Name = @MTL_Name
			
			goto Skip
		end
		
		-----------------------------------------------------------
		-- log beginning of update for database
		--
		if @logVerbosity > 1
		begin
			set @message = 'Master Update Begun for ' + @MTL_Name
			execute PostLogEntry 'Normal', @message, 'UpdateAllActiveMTDatabases'
		end

		-- get table counts before update (remember counts)
		--
		declare @count1 int
		declare @count2 int
		declare @count3 int
		declare @count4 int
		declare @historyID int
		
		declare @msg varchar(512)
		set @msg = ''
		exec GetStatisticsFromExternalDB @MTL_Name, 'MT', 'initial', 
				@count1 output, @count2 output, @count3 output, @count4 output, @msg output

		-- Append the values to T_Current_Activity_History
		--
		Set @historyId = 0
		INSERT INTO T_Current_Activity_History (Database_ID, Database_Name, Snapshot_Date, TableCount1, TableCount2, TableCount3, TableCount4)
		VALUES (@MTL_ID, @MTL_Name, GetDate(), @count1, @count2, @count3, @count4)
		--
		SELECT @historyId = @@Identity
		
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

		if @DBSchemaVersion < 2
		Begin
			if @importNeeded > 0
			
				-----------------------------------------------------------
				-- call MasterUpdateProcess sproc in DB if it exists
				-- 
				exec @result = CallStoredProcInExternalDB
									@MTL_Name,	
									'MasterUpdateProcess',
									0,
									@StoredProcFound Output,
									@message Output
		End
		Else
		Begin
			-- @DBSchemaVersion is >= 2

			if @importNeeded > 0
				Set @skipImport = 0
			Else
				Set @skipImport = 1
			
			-----------------------------------------------------------
			-- Confirm that MasterUpdateMassTags sproc exists in DB
			-- 
			exec @result = CallStoredProcInExternalDB
								@MTL_Name,	
								'MasterUpdateMassTags',
								1,
								@StoredProcFound Output,
								@message Output

			If @StoredProcFound <> 0
			Begin
				Set @SQLToExec = N'[' + Convert(nvarchar(256), @MTL_Name) + N']..MasterUpdateMassTags' + ' ' + Convert(nvarchar(15), @maxJobsToProcess) + ', ' + Convert(nvarchar(2), @skipImport)
				EXEC @result = sp_executesql @SQLToExec
			End

	
		End

		-- get table counts (added for update)
		--
		exec GetStatisticsFromExternalDB @MTL_Name, 'MT', 'final', 
				@count1 output, @count2 output, @count3 output, @count4 output, @msg output
		
		-- Cache the current completion time
		--
		Set @completionDate = GetDate()

		-- Update completion date for MT database in the current activity history table
		UPDATE T_Current_Activity_History
		SET Update_Completion_Date = @completionDate
		WHERE History_ID = @historyId
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount


		-- Compute the total processing time for the last 24 hours for this database,
		Set @procTimeMinutesLast24Hours = 0
		
		SELECT @procTimeMinutesLast24Hours = ROUND(SUM(ISNULL(DATEDIFF(second, Snapshot_Date, Update_Completion_Date), 0) / 60.0), 1)
		FROM T_Current_Activity_History
		WHERE (DATEDIFF(minute, ISNULL(Update_Completion_Date, @completionDate), @completionDate) / 60.0 <= 24) AND 
				Database_ID = @MTL_ID AND Database_Name = @MTL_Name
		GROUP BY Database_Name
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount


		-- Compute the total processing time for the last 7 days for this database,
		Set @procTimeMinutesLast7days = 0
		
		SELECT @procTimeMinutesLast7days = ROUND(SUM(ISNULL(DATEDIFF(second, Snapshot_Date, Update_Completion_Date), 0) / 60.0), 1)
		FROM T_Current_Activity_History
		WHERE (DATEDIFF(hour, ISNULL(Update_Completion_Date, @completionDate), @completionDate) / 24.0 <= 7) AND 
				Database_ID = @MTL_ID AND Database_Name = @MTL_Name
		GROUP BY Database_Name
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

	
		-- update completion date for MT database in current activity table
		--
		UPDATE	T_Current_Activity
		SET		Update_Completed = @completionDate, Comment = @msg, Update_State = 3, 
				ET_Minutes_Last24Hours = @procTimeMinutesLast24Hours,
				ET_Minutes_Last7Days = @procTimeMinutesLast7days
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
			set @lastImport = @completionDate
		--
		UPDATE	T_MT_Database_List
		SET
			MTL_Last_Import = @lastImport,
			MTL_Last_Update = @completionDate,
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

		-- Increment the databases processed count
		set @processCount = @processCount + 1

		-- log end of update for database
		--
		if @logVerbosity > 1 OR (@logVerbosity > 0 AND @importNeeded > 0)
		begin
			set @message = 'Master Update Complete for ' + @MTL_Name
			execute PostLogEntry 'Normal', @message, 'UpdateAllActiveMTDatabases'
		end

Skip:
	END --<a>


	-----------------------------------------------------------
	-- Update T_Analysis_Job_to_MT_DB_Map for all MT Databases (with MTL_State < 10)
	-----------------------------------------------------------
	--
	declare @JobMappingRowCountAdded int
	Set @JobMappingRowCountAdded = 0

	Set @message = ''
	Exec @result = UpdateAnalysisJobToMTDBMap @RowCountAdded = @JobMappingRowCountAdded OUTPUT, @message = @message Output

	if @result <> 0 and @logVerbosity > 0
	begin
		set @message = 'Error calling UpdateAnalysisJobToMTDBMap: ' + @message + ' (error code ' + convert(varchar(11), @result) + ')'
		execute PostLogEntry 'Error', @message, 'UpdateAllActiveMTDatabases'
	end
	else
		if @logVerbosity > 1 OR (@logVerbosity > 0 AND @JobMappingRowCountAdded > 0)
		begin
			set @message = 'UpdateAnalysisJobToMTDBMap; Rows updated: ' + Convert(varchar(11), @JobMappingRowCountAdded)
			execute PostLogEntry 'Normal', @message, 'UpdateAllActiveMTDatabases'
		end

		
	-----------------------------------------------------------
	-- log successful completion of master update process
	-----------------------------------------------------------

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

Done:
	-----------------------------------------------------------
	-- log skipped updates
	-----------------------------------------------------------
	--
	if @skippedDBList <> '' and @logVerbosity > 0
	begin
		set @message = 'Update was skipped since peptide DB updating: ' + @skippedDBList
		execute PostLogEntry 'Error', @message, 'UpdateAllActiveMTDatabases'
	end

	-----------------------------------------------------------
	-- 
	-----------------------------------------------------------
	--
	if @myError <> 0 and @logVerbosity > 0
	begin
		set @message = 'Master Update Error ' + convert(varchar(32), @myError) + ' occurred'
		execute PostLogEntry 'Error', @message, 'UpdateAllActiveMTDatabases'
		
		-- set upate state to failed
	end

	return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[UpdateAllActiveMTDatabases]  TO [DMS_SP_User]
GO

