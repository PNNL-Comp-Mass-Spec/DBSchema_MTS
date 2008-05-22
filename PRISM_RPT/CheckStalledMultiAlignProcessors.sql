/****** Object:  StoredProcedure [dbo].[CheckStalledMultiAlignProcessors] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.CheckStalledMultiAlignProcessors
/****************************************************
**
**	Desc: 
**		Uses V_MultiAlign_Tasks_Stalled to see whether 
**		any active peak matching processors are stalled
**
**		Return values: 0: success, otherwise, error code
** 
**	Auth:	mem
**	Date:	01/03/2008
**
*****************************************************/
	@message varchar(512) = '' output,
	@PostErrorsToLog tinyint = 1,
	@LogEntryHoldoffHours int = 20			-- Set this to a value greater than 0 to prevent multiple log entries from being posted within the given number of hours
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	Declare @StalledProcessorCount int
	Declare @MultipleRowCount int
	Declare @MaximumProcessingTimeHoursElapsed int
	Declare @MaximumHoursSinceLastQuery int
	
	Set @StalledProcessorCount = 0
	Set @MultipleRowCount = 0
	Set @MaximumProcessingTimeHoursElapsed = 0
	Set @MaximumHoursSinceLastQuery = 0
	
	Set @message = ''
	
	SELECT @StalledProcessorCount = COUNT(*)
	FROM V_MultiAlign_Tasks_Stalled
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	
	If @StalledProcessorCount > 0 
	Begin
		Set @Message = 'Found ' + Convert(varchar(9), @StalledProcessorCount) + ' active processor(s) stalled'

		SELECT @MaximumProcessingTimeHoursElapsed = IsNull(MAX(ProcessingTimeHoursElapsed), 0),
				@StalledProcessorCount = COUNT(*)
		FROM V_MultiAlign_Tasks_Stalled
		WHERE Working <> 0

		If @StalledProcessorCount > 0
			Set @Message = @Message + '; ' + Convert(varchar(9), @StalledProcessorCount) + ' processors have been processing for ' + Convert(varchar(9), @MaximumProcessingTimeHoursElapsed) + ' hours'

		SELECT	@MaximumHoursSinceLastQuery = IsNull(MAX(HoursSinceLastQuery), 0),
				@StalledProcessorCount = COUNT(*)
		FROM V_MultiAlign_Tasks_Stalled
		WHERE Working = 0

		If @StalledProcessorCount > 0
			Set @Message = @Message + '; ' + Convert(varchar(9), @StalledProcessorCount) + ' processors have not requested a task in the last ' + Convert(varchar(9), @MaximumHoursSinceLastQuery) + ' hours'


		If @PostErrorsToLog = 0
			Select @Message as ErrorMessage
		Else
		Begin
			If IsNull(@LogEntryHoldoffHours, 0) > 0
			Begin
				SELECT @MultipleRowCount = COUNT(*)
				FROM T_Log_Entries
				WHERE posted_by = 'CheckStalledMultiAlignProcessors' AND 
					  Type = 'Error' AND Posting_Time >= (GetDate() - @LogEntryHoldoffHours)
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
			End

			If @MultipleRowCount = 0
			Begin
				Exec PostLogEntry 'Error', @Message, 'CheckStalledMultiAlignProcessors'
			End
		End
	End	

	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	Return @myError

GO
