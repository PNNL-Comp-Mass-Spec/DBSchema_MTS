/****** Object:  StoredProcedure [dbo].[PostLogEntry]    Script Date: 08/14/2006 20:23:21 ******/
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
**
**	Parameters: 
**
**	
**
**		Auth: grk
**		Date: 10/31/2001
**			  02/17/2005 mem - Added parameter @duplicateEntryHoldoffHours
**    
*****************************************************/
	@type varchar(50),
	@message varchar(500),
	@postedBy varchar(50)= 'na',
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
			RAISERROR ('Update was unsuccessful for T_Log_Entries table',
						10, 1)
			return 51191
		end
	End
	
	return 0


GO
GRANT EXECUTE ON [dbo].[PostLogEntry] TO [DMS_SP_User]
GO
