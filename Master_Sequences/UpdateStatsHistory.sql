/****** Object:  StoredProcedure [dbo].[UpdateStatsHistory] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.UpdateStatsHistory
/****************************************************
**
**	Desc:	Adds a new entry to T_Stats_History if needed
**			(or if @ForceUpdate <> 0)
**
**	Auth:	mem
**	Date:	08/22/2006
**    
*****************************************************/
(
	@ForceStatsUpdate tinyint = 0,
	@MinimumUpdateThresholdDays smallint = 7
)
AS
	Set NoCount ON

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	Declare @MaxPostingTime datetime
	Declare @MaxSequenceCount int
	Declare @RowCountCompare int
	Declare @UpdateStatsHistory tinyint
	Set @UpdateStatsHistory = 0
	
	--------------------------------------------------------
	-- Validate the inputs
	--------------------------------------------------------
	--	
	Set @MinimumUpdateThresholdDays = IsNull(@MinimumUpdateThresholdDays, 7)
	if @MinimumUpdateThresholdDays < 0
		Set @MinimumUpdateThresholdDays = 0
	
	Set @UpdateStatsHistory = IsNull(@ForceStatsUpdate, 0)

	If @UpdateStatsHistory = 0
	Begin -- <a>
		-----------------------------------------------------
		-- Lookup the most recent entry in T_Stats_History
		-- If it is over 1 week old, then compare @MaxSequenceCount to
		--  the row count reported by V_Table_Row_Counts
		-----------------------------------------------------
		--
		Set @MaxPostingTime = GetDate()
		Set @MaxSequenceCount = 0
		
		SELECT	@MaxPostingTime = SH.Posting_Time, 
				@MaxSequenceCount = SH.Sequence_Count
		FROM T_Stats_History SH INNER JOIN
				(	SELECT MAX(entry_id) AS Entry_ID
					FROM T_Stats_History
				) LookupQ ON SH.Entry_ID = LookupQ.Entry_ID
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		If DateDiff(day, @MaxPostingTime, GetDate()) >= @MinimumUpdateThresholdDays
		Begin -- <b>
			--------------------------------------------------------
			-- See if @MaxSequenceCount is different than
			--  the table row count reported by V_Table_Row_Counts
			--------------------------------------------------------
			--
			SELECT @RowCountCompare = TableRowCount
			FROM V_Table_Row_Counts
			WHERE TableName = 'T_Sequence'
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			
			If @RowCountCompare > @MaxSequenceCount
				Set @UpdateStatsHistory = 1
		End -- </b>
	End -- </a>
	
	If @UpdateStatsHistory <> 0
	Begin
		--------------------------------------------------------
		-- Insert a new row into T_Stats_History
		--------------------------------------------------------
		--
		INSERT INTO T_Stats_History (Sequence_Count)
		SELECT TableRowCount
		FROM V_Table_Row_Counts
		WHERE TableName = 'T_Sequence'
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
	End

Done:	
	Return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[UpdateStatsHistory] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[UpdateStatsHistory] TO [MTS_DB_Lite] AS [dbo]
GO
