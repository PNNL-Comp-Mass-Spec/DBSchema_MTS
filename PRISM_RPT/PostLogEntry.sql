/****** Object:  StoredProcedure [dbo].[PostLogEntry] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.PostLogEntry
/****************************************************
**
**	Desc: Put new entry into the main log table
**
**	Return values: 0: success, otherwise, error code
*
**	Auth:	grk
**	Date:	10/31/2001
**			02/17/2005 mem - Added parameter @duplicateEntryHoldoffHours
**			05/31/2007 mem - Expanded the size of @type, @message, and @postedBy
**    
*****************************************************/
	@type varchar(128),
	@message varchar(4096),
	@postedBy varchar(128)= 'na',
	@duplicateEntryHoldoffHours int = 0			-- Set this to a value greater than 0 to prevent duplicate entries being posted within the given number of hours
As

	Declare @duplicateRowCount int
	Set @duplicateRowCount = 0
	
	If IsNull(@duplicateEntryHoldoffHours, 0) > 0
	Begin
		SELECT @duplicateRowCount = COUNT(*)
		FROM T_Log_Entries
		WHERE Message = @message AND Type = @type AND Posting_Time >= (GetDate() - @duplicateEntryHoldoffHours)
	End

	If @duplicateRowCount = 0
	Begin
		INSERT INTO T_Log_Entries
			(posted_by, posting_time, type, message) 
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
GRANT EXECUTE ON [dbo].[PostLogEntry] TO [DMS_SP_User] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[PostLogEntry] TO [msdadmin] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[PostLogEntry] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[PostLogEntry] TO [MTS_DB_Lite] AS [dbo]
GO
