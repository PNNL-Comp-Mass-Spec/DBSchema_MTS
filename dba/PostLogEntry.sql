/****** Object:  StoredProcedure [dbo].[PostLogEntry] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create Procedure PostLogEntry
/****************************************************
**
**	Desc: Put new entry into the main log table or the
**        health log table
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters: 
**
**	
**
**	Auth:	grk
**	Date:	01/26/2001
**			06/08/2006 grk - added logic to put data extraction manager stuff in analysis log
**			03/30/2009 mem - Added parameter @duplicateEntryHoldoffHours
**						   - Expanded the size of @type, @message, and @postedBy
**			07/20/2009 grk - eliminate health log (http://prismtrac.pnl.gov/trac/ticket/742)
**			09/13/2010 mem - Eliminate analysis log
**						   - Auto-update @duplicateEntryHoldoffHours to be 24 when the log type is Health or Normal and the source is the space manager
**    
*****************************************************/
(
	@type varchar(128),
	@message varchar(4096),
	@postedBy varchar(128)= 'na',
	@duplicateEntryHoldoffHours int = 0			-- Set this to a value greater than 0 to prevent duplicate entries being posted within the given number of hours
)
As
	Declare @duplicateRowCount int
	Set @duplicateRowCount = 0
	
	If (@postedBy Like 'Space%') And @type In ('Health', 'Normal')
	Begin
		-- Auto-update @duplicateEntryHoldoffHours to be 24 if it is zero
		-- Otherwise we get way too many health/status log entries
		
		If @duplicateEntryHoldoffHours = 0
			Set @duplicateEntryHoldoffHours = 24
	End
	
	
	If IsNull(@duplicateEntryHoldoffHours, 0) > 0
	Begin
		SELECT @duplicateRowCount = COUNT(*)
		FROM T_Log_Entries
		WHERE Message = @message AND Type = @type AND Posting_Time >= (GetDate() - @duplicateEntryHoldoffHours)
	End

	If @duplicateRowCount = 0
	Begin
		INSERT INTO T_Log_Entries (posted_by, posting_time, type, message) 
		VALUES ( @postedBy, GETDATE(), @type, @message)
		--
		if @@rowcount <> 1
		begin
			RAISERROR ('Update was unsuccessful for T_Log_Entries table', 10, 1)
			return 51191
		end
	End
			
	return 0

GO
