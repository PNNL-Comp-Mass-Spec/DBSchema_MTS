SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[UpdateMasterSequenceMasses]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[UpdateMasterSequenceMasses]
GO

CREATE Procedure UpdateMasterSequenceMasses
/****************************************************
** 
**		Desc: Calls CalculateMonoisotopicMassWrapper in Master_Sequences,
**			  keeps track of progress in T_Current_Activity_History
**			  T_Current_Activity
**
**		Return values: 0: success, otherwise, error code
** 
**		Parameters:
**
**		Auth: mem
**		Date: 11/28/2005
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
	
	declare @completionDate datetime
	declare @procTimeMinutesLast24Hours float
	declare @procTimeMinutesLast7days float
	
	declare @message varchar(255)
	declare @logVerbosity int -- 0 silent, 1 minimal, 2 verbose, 3 debug
	set @logVerbosity = 1

	declare @MasterSeqDB varchar(255)
	declare @MasterSeqDBID int
	declare @MasterSeqDBState tinyint
	
	set @MasterSeqDB = 'Master_Sequences'	
	set @MasterSeqDBID = 1000
	set @MasterSeqDBState = 2

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
		INSERT INTO T_Current_Activity (Database_ID, Database_Name, Type, Update_Began, State, Update_State)
		VALUES (@MasterSeqDBID, @MasterSeqDB, 'MSeq', GetDate(), @MasterSeqDBState, 2)
	Else
		UPDATE T_Current_Activity
		SET	Database_Name = @MasterSeqDB, Update_Began = GetDate(), Update_Completed = Null, State = @MasterSeqDBState, Comment = '', Update_State = 2
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
	--
	if @logVerbosity > 1
	begin
		set @message = 'Master Update Begun for ' + @MasterSeqDB
		execute PostLogEntry 'Normal', @message, 'UpdateMasterSequenceMasses'
	end

	-- get table counts before update (remember counts)
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
	-- 
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
	Set @completionDate = GetDate()

	-- Update completion date for database in the current activity history table
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
			Database_ID = @MasterSeqDBID AND Database_Name = @MasterSeqDB
	GROUP BY Database_Name
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	-- Compute the total processing time for the last 7 days for this database,
	Set @procTimeMinutesLast7days = 0
	
	SELECT @procTimeMinutesLast7days = ROUND(SUM(ISNULL(DATEDIFF(second, Snapshot_Date, Update_Completion_Date), 0) / 60.0), 1)
	FROM T_Current_Activity_History
	WHERE (DATEDIFF(hour, ISNULL(Update_Completion_Date, @completionDate), @completionDate) / 24.0 <= 7) AND 
			Database_ID = @MasterSeqDBID AND Database_Name = @MasterSeqDB
	GROUP BY Database_Name
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	-- Update completion date in the current activity table
	--
	UPDATE	T_Current_Activity
	SET Update_Completed = @completionDate, Comment = @StatMsg, Update_State = 3, 
		ET_Minutes_Last24Hours = @procTimeMinutesLast24Hours,
		ET_Minutes_Last7Days = @procTimeMinutesLast7days
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
	-- 
	-----------------------------------------------------------
	--
	if @myError <> 0 and @logVerbosity > 0
	begin
		set @message = 'Master Update Error ' + convert(varchar(32), @myError) + ' occurred'
		execute PostLogEntry 'Error', @message, 'UpdateMasterSequenceMasses'
	end

	return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

