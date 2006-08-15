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
**  Auth: mem
**	Date: 06/03/2003
**
**  Updated: 6/23/2003 by mem
**			 7/07/2003
**			 8/26/2003
**			 2/13/2004 by mem: Changed logic to only obtain a task for processing if no tasks already have a state of 2 = Processing
**			 2/16/2004 by mem: Changed code that looks for available tasks to use a temporary table to avoid deadlock issues
**			 2/21/2004 by mem: Due to updates in QuantitationProcessWork, removed logic that aborts processing if other tasks have a state of 2
**
****************************************************/
(
	@EntriesProcessed int=0 output	--number of entries in T_Quantitation_Description that were processed
)
As
	Set NoCount On

	Declare @myError int,
			@myRowCount int,
			@AvailableCount int,
			@TasksCurrentlyProcessing int,
			@ErrorCodeReturn int

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


	Print @message
	SELECT @message
	Return @myError



GO
GRANT EXECUTE ON [dbo].[QuantitationProcessStart] TO [DMS_SP_User]
GO
