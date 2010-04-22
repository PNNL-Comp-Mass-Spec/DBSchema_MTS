/****** Object:  StoredProcedure [dbo].[UpdateMasterSequenceMasses] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create Procedure UpdateMasterSequenceMasses
/****************************************************
** 
**	Desc:	Calls CalculateMonoisotopicMassWrapper in Master_Sequences,
**			 keeps track of progress in T_Current_Activity_History 
**			 and T_Current_Activity
**
**	Return values: 0: success, otherwise, error code
** 
**	Parameters:
**
**	Auth:	mem
**	Date:	11/28/2005
**			03/11/2006 mem - Now calling VerifyUpdateEnabled
**			03/14/2006 mem - Now using column Pause_Length_Minutes
**    
*****************************************************/
(
	@SequencesToProcess int = 0		-- When greater than 0, then only processes the given number of sequences
)
As	
	set nocount on
	
	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	declare @matchCount int
	
	declare @CompletionDate datetime
	declare @PauseLengthMinutes real
	declare @ProcTimeMinutesLast24Hours float
	declare @ProcTimeMinutesLast7days float
	declare @UpdateEnabled tinyint
	
	declare @message varchar(255)
	declare @logVerbosity int -- 0 silent, 1 minimal, 2 verbose, 3 debug
	set @logVerbosity = 1

	declare @MasterSeqDB varchar(255)
	declare @MasterSeqDBID int
	declare @MasterSeqDBState tinyint
	
	set @MasterSeqDB = 'Master_Sequences'	
	set @MasterSeqDBID = 1000
	set @MasterSeqDBState = 2

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled 'Master_Sequences_Update', 'UpdateMasterSequenceMasses', @AllowPausing = 0, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done

	-----------------------------------------------------------
	-- Perform update
	-----------------------------------------------------------

	-- Verify that Master_Sequences is present in the current activity table
	-- Add it if missing, or update if present
	--
	Set @matchCount = 0
	SELECT @matchCount = COUNT(*)
	FROM T_Current_Activity
	WHERE Database_Name = @MasterSeqDB
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	If @matchCount = 0
		INSERT INTO T_Current_Activity (Database_ID, Database_Name, Type, Update_Began, Update_Completed, 
										Pause_Length_Minutes, State, Update_State)
		VALUES (@MasterSeqDBID, @MasterSeqDB, 'MSeq', GetDate(), Null,
				0, @MasterSeqDBState, 2)
	Else
		UPDATE T_Current_Activity
		SET	Database_Name = @MasterSeqDB, Update_Began = GetDate(), Update_Completed = Null, 
			Pause_Length_Minutes = 0, State = @MasterSeqDBState, Comment = '', Update_State = 2
		WHERE Database_ID = @MasterSeqDBID AND Database_Name = @MasterSeqDB
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 
	begin
		set @message = 'Could not update current activity table'
		set @myError = 40
		goto Done
	end
	
	-----------------------------------------------------------
	-- log beginning of update for database
	-----------------------------------------------------------
	if @logVerbosity > 1
	begin
		set @message = 'Master Update Begun for ' + @MasterSeqDB
		execute PostLogEntry 'Normal', @message, 'UpdateMasterSequenceMasses'
	end

	-- Get table counts before update (remember counts)
	--
	declare @count1 int
	declare @historyId int
	
	exec GetTableCountFromExternalDB @MasterSeqDB, 'T_Sequence', @count1 output

	-- Append the values to T_Current_Activity_History
	--
	Set @historyId = 0
	INSERT INTO T_Current_Activity_History (Database_ID, Database_Name, Snapshot_Date, TableCount1, TableCount2, TableCount3, TableCount4)
	VALUES (@MasterSeqDBID, @MasterSeqDB, GetDate(), @count1, 0, 0, 0)
	--
	SELECT @historyId = @@Identity
	

	-----------------------------------------------------------
	-- Call the mass calculation SP
	-----------------------------------------------------------
	Declare @SPToExec varchar(2048)
	Declare @PeptidesProcessedCount int

	Set @SPToExec = '[' + @MasterSeqDB + ']..CalculateMonoisotopicMassWrapper'
	Set @PeptidesProcessedCount = 0

	Exec @myError = @SPToExec	
						@SequencesToProcess,					
						@PeptidesProcessedCount output
														
		
	declare @StatMsg varchar(255)
	set @StatMsg = ' SQ:' + cast(@PeptidesProcessedCount as varchar(12))

	-- Cache the current completion time
	--
	Set @CompletionDate = GetDate()

	-- Populate @PauseLengthMinutes
	Set @PauseLengthMinutes = 0
	SELECT @PauseLengthMinutes = Pause_Length_Minutes
	FROM T_Current_Activity
	WHERE Database_Name = @MasterSeqDB
	
	-- Update completion date and Pause Length for database in the current activity history table
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
			Database_ID = @MasterSeqDBID AND Database_Name = @MasterSeqDB
	GROUP BY Database_Name
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	-- Compute the total processing time for the last 7 days for this database,
	Set @ProcTimeMinutesLast7days = 0
	
	SELECT @ProcTimeMinutesLast7days = ROUND(SUM(ISNULL(DATEDIFF(second, Snapshot_Date, Update_Completion_Date), 0) / 60.0 - Pause_Length_Minutes), 1)
	FROM T_Current_Activity_History
	WHERE (DATEDIFF(hour, ISNULL(Update_Completion_Date, @CompletionDate), @CompletionDate) / 24.0 <= 7) AND 
			Database_ID = @MasterSeqDBID AND Database_Name = @MasterSeqDB
	GROUP BY Database_Name
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	-- Update completion date in the current activity table
	--
	UPDATE	T_Current_Activity
	SET Update_Completed = @CompletionDate, Comment = @StatMsg, Update_State = 3, 
		ET_Minutes_Last24Hours = @ProcTimeMinutesLast24Hours,
		ET_Minutes_Last7Days = @ProcTimeMinutesLast7days
	WHERE Database_ID = @MasterSeqDBID AND Database_Name = @MasterSeqDB
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 
	begin
		set @message = 'Could not update current activity table'
		set @myError = 41
		goto Done
	end
	
	-- log end of update for database
	--
	if @logVerbosity > 1
	begin
		set @message = 'Master Update Complete for ' + @MasterSeqDB
		execute PostLogEntry 'Normal', @message, 'UpdateMasterSequenceMasses'
	end
	
Done:
	-----------------------------------------------------------
	-- Exit
	-----------------------------------------------------------
	--
	if @myError <> 0 and @logVerbosity > 0
	begin
		set @message = 'Master Update Error ' + convert(varchar(32), @myError) + ' occurred'
		execute PostLogEntry 'Error', @message, 'UpdateMasterSequenceMasses'
	end

	return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[UpdateMasterSequenceMasses] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[UpdateMasterSequenceMasses] TO [MTS_DB_Lite] AS [dbo]
GO
