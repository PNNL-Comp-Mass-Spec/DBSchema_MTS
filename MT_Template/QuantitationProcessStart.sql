/****** Object:  StoredProcedure [dbo].[QuantitationProcessStart] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.QuantitationProcessStart
/****************************************************	
**
**  Desc: Processes the entries in T_Quantitation_Description that 
**        have a Quantitation_State = 1 (new)
**        Quantitation results are written to T_Quantitation_Results
**
**  Return values: 0 if success, otherwise, error code
**
**  Parameters: EntriesProcessed returns the number of entries processed
**
**  Auth:	mem
**	Date:	06/03/2003
**			06/23/2003
**			07/07/2003
**			08/26/2003
**			02/13/2004 mem - Changed logic to only obtain a task for processing if no tasks already have a state of 2 = Processing
**			02/16/2004 mem - Changed code that looks for available tasks to use a temporary table to avoid deadlock issues
**			02/21/2004 mem - Due to updates in QuantitationProcessWork, removed logic that aborts processing if other tasks have a state of 2
**			05/28/2007 mem - Added call to VerifyUpdateEnabled
**			10/20/2008 mem - Added parameter @MaxEntriesToProcess
**			11/03/2009 mem - No longer displaying @message via a Select statement
**
****************************************************/
(
	@EntriesProcessed int=0 output,		-- Number of entries in T_Quantitation_Description that were processed
	@MaxEntriesToProcess int = 0		-- Set to a positive number to limit the number of entries to process
)
As
	Set NoCount On

	Declare @myError int,
			@myRowCount int,
			@AvailableCount int,
			@TasksCurrentlyProcessing int,
			@ErrorCodeReturn int
	
	Declare @UpdateEnabled tinyint
	
	Set @myError = 0
	Set @myRowCount = 0
	Set @AvailableCount = 0
	Set @TasksCurrentlyProcessing = 0
	Set @ErrorCodeReturn = 0

	Declare @message varchar(255)
	
	Set @message = ''
 
	--Variables for the current quantitation entry
	Declare @QuantitationID int,
		    @QuantitationState tinyint

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @StepName = 'MS_Peak_Matching', @CallingFunctionDescription = 'QuantitationProcessStart', @AllowPausing = 0, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done

	-----------------------------------------------------------
	-- Validate the inputs
	-----------------------------------------------------------
	--
	Set @EntriesProcessed = 0
	Set @MaxEntriesToProcess = IsNull(@MaxEntriesToProcess, 0)
	
	-----------------------------------------------------------
	-- Step 1
	--
	-- Populate a temporary table with the jobs available for processing
	-- This is done to avoid deadlock issues
	-- While doing this, see how many jobs are available for processing
	-----------------------------------------------------------

	CREATE TABLE #QIDList (
		QID int
	)

	INSERT INTO #QIDList
	SELECT QD.Quantitation_ID
	FROM T_Quantitation_Description AS QD
	WHERE QD.Quantitation_State = 1
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	SET @AvailableCount = @myRowCount
	--
	if @myError <> 0 
	begin
		set @message = 'Error accessing the T_Quantitation_Description table'
		set @myError = 100
		goto Done
	end
	--
	SELECT @message = 'Found ' + convert(varchar(32), @AvailableCount) + ' quantitation set(s) available for processing'
	
	-----------------------------------------------------------
	-- Step 2
	--
	-- Process each entry in #QIDList table
	--  with Quantitation_State = 1 
	-----------------------------------------------------------
	--
	
	While @AvailableCount > 0 And @myError = 0
	Begin
		
		Begin Transaction TransQuantitationProcess
		
		-- Get next available entry from #QIDList, joining to T_Quantitation_Description
		--  to make sure its state is still 1
		--
		SET @QuantitationID = -1
		SELECT	TOP 1	@QuantitationID = #QIDList.QID
		FROM	T_Quantitation_Description AS QD WITH (HoldLock)
				Inner Join #QIDList ON #QIDList.QID = QD.Quantitation_ID
		WHERE	QD.Quantitation_State = 1
		ORDER BY #QIDList.QID		
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0
		begin
			RollBack Transaction TransQuantitationProcess
			set @message = 'Could not get next entry from T_Quantitation_Description'
			set @myError = 101
			goto Done
		end

		--Make sure QuantitationID is not null
		--
		Set @QuantitationID	= IsNull(@QuantitationID, -1)
		
		If @myRowCount = 0 Or @QuantitationID < 0
			Begin
				RollBack Transaction TransQuantitationProcess
				-- No entries available for processing
				Goto done
			End
		Else
			Begin
				-- Change Quantitation_State to 2 (processing)
				UPDATE	T_Quantitation_Description
				SET		Quantitation_State = 2
				WHERE	Quantitation_ID = @QuantitationID
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				--
				if @myError <> 0
				begin
					RollBack Transaction TransQuantitationProcess
					set @message = 'Could not set Quantitation_State to 2 in T_Quantitation_Description'
					set @myError = 102
					goto Done
				end
				
				-- All is fine, so commit the transaction and begin processing
				Commit Transaction TransQuantitationProcess
				
				Select 'Processing Quantitation ID = ' + Convert(varchar(9), @QuantitationID)
				
				-- Process by calling QuantitationProcessWork
				Exec @ErrorCodeReturn = QuantitationProcessWork @QuantitationID
				
				-- Update Quantitation_State to 3 (Success) or 4 (Failure)
				If @ErrorCodeReturn = 0
					Set @QuantitationState = 3
				Else
					Set @QuantitationState = 4
	
				-- Update T_Quantitation_Description with @QuantitationState 
				UPDATE	T_Quantitation_Description
				SET		Quantitation_State = @QuantitationState
				WHERE	Quantitation_ID = @QuantitationID

				-- Increment @EntriesProcessed
				Set @EntriesProcessed = @EntriesProcessed + 1
			End

		-- Re-populate #QIDList since another process may have added a new entry to T_Quantitation_Description
		DELETE FROM #QIDList
		--
		INSERT INTO #QIDList
		SELECT QD.Quantitation_ID
		FROM T_Quantitation_Description AS QD
		WHERE QD.Quantitation_State = 1
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		SET @AvailableCount = @myRowCount

		If @MaxEntriesToProcess > 0 And @EntriesProcessed >= @MaxEntriesToProcess
			Set @AvailableCount =0

		If @AvailableCount > 0
		Begin
			-- Validate that updating is enabled, abort if not enabled
			exec VerifyUpdateEnabled @StepName = 'MS_Peak_Matching', @CallingFunctionDescription = 'QuantitationProcessStart', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
			If @UpdateEnabled = 0
				Set @AvailableCount = 0
		End
	End


Done:
	-----------------------------------------------------------
	-- Done processing; 
	-----------------------------------------------------------
	--
	If @myError = 0
		Begin
			-- If we processed 1 or more entries, then post an entry T_Log_Entries
			If @EntriesProcessed > 0
				Begin
					Set @message = 'Processed ' + convert(varchar(32), @EntriesProcessed) + ' quantitation set(s)'
				End
		End
	Else
		Begin
			-- Error occurred; post to T_Log_Entries
			If Len(@message) > 0
				Set @message = ': ' + @message
			
			Set @message = 'Quantitation Processing Error ' + convert(varchar(32), @myError) + @message
			Execute PostLogEntry 'Error', @message, 'QuantitationProcessing'
			Print @message
		End

	Return @myError


GO
GRANT EXECUTE ON [dbo].[QuantitationProcessStart] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[QuantitationProcessStart] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[QuantitationProcessStart] TO [MTS_DB_Lite] AS [dbo]
GO
