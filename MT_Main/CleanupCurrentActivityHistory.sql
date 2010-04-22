/****** Object:  StoredProcedure [dbo].[CleanupCurrentActivityHistory] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE CleanupCurrentActivityHistory
/****************************************************
** 
**	Desc: Removes old entries from T_Current_Activity_History
**
**	Return values: 0: success, otherwise, error code
** 
**	Parameters:
**
**	Auth:	mem
**	Date:	11/25/2009 mem - Initial version
**    
*****************************************************/ 
(
	@infoOnly tinyint = 0,				-- Set to 0 to delete old entries from T_Current_Activity_History; 1 to preview the changes
	@ThresholdDays int = 90,			-- Number of days of entries to retain in T_Current_Activity_History.  Note that the date threshold uses the most recent entry in the table as the most recent time; not the current date/time
	@message varchar(512) ='' output
)
As	
	set nocount on
	
	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	declare @HistoryIDMax int
	declare @DateStart datetime
	declare @DateEnd datetime
	
	declare @DateThreshold datetime
		
	---------------------------------------------------
	-- Validate the inputs
	---------------------------------------------------
	
	set @infoOnly = IsNull(@infoOnly, 0)
	Set @ThresholdDays = IsNull(@ThresholdDays, 90)
	if @ThresholdDays < 30
	Begin		
		Set @ThresholdDays = 30
		Print 'Warning: @ThresholdDays must be at least 30'
	End
	
	set @message = ''
	
	---------------------------------------------------
	-- Determine the date threshold
	---------------------------------------------------

	SELECT @DateThreshold = MAX(Snapshot_Date)
	FROM T_Current_Activity_History
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	If @myRowCount = 0
	Begin
		Set @message = 'T_Current_Activity_History is empty; nothing to do'
		Goto Done
	End
	
	Set @DateThreshold = DATEADD(day, - @ThresholdDays, @DateThreshold)

	If @infoOnly <> 0
		Print 'Finding entries before ' + Convert(varchar(32), @DateThreshold, 120)
		
	---------------------------------------------------
	-- Look for data to delete
	---------------------------------------------------

	Set @HistoryIDMax = 0
 
	SELECT @HistoryIDMax = MAX(History_ID),
		   @DateStart =    MIN(Snapshot_Date),
		   @DateEnd =      MAX(Snapshot_Date)
	FROM T_Current_Activity_History
	WHERE (Snapshot_Date <= @DateThreshold)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	
	If @HistoryIDMax > 0
	Begin
		Set @DateStart = IsNull(@DateStart, '1/1/2000')
		Set @DateEnd = IsNull(@DateEnd, '1/1/2000')
		
		If @infoOnly = 0
		Begin
			DELETE FROM T_Current_Activity_History
			WHERE History_ID <= @HistoryIDMax
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			
			set @message = 'Removed ' + convert(varchar(32), @myRowCount) + ' old entries from T_Current_Activity_History'
		End
		Else
		Begin
			SELECT @myRowCount = COUNT(*)
			FROM T_Current_Activity_History
			WHERE History_ID <= @HistoryIDMax
			
			set @message = 'Found ' +  convert(varchar(32), @myRowCount) + ' old entries in T_Current_Activity_History'
		End
	
		set @message = @message + ' (' + Convert(varchar(32), @DateStart, 101) + ' to ' +  Convert(varchar(32), @DateEnd, 101) + ')'
		
		If @infoOnly = 0
			execute PostLogEntry 'Normal', @message, 'CleanupCurrentActivityHistory'		
			
	End
	Else
	Begin
		Set @message = 'No entries older than ' + Convert(varchar(32), @ThresholdDays) + ' days were found in T_Current_Activity_History'
	End
		
Done:
	
	If @myError = 0 And @infoOnly <> 0
		SELECT @message as Message

	return @myError


GO
