/****** Object:  StoredProcedure [dbo].[MoveHistoricLogEntries] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create Procedure MoveHistoricLogEntries
/****************************************************
**
**	Desc: Move log entries from main log into the 
**        historic log (insert and then delete)
**        that are older then given by @intervalHrs
**
**	Return values: 0: success, otherwise, error code
**	
**
**	Auth:	grk
**	Date:	08/29/2001
**			08/01/2004 mem - Updated @intervalHrs to 168 (1 week)
**			12/01/2005 mem - Increased size of @DBName from 64 to 128 characters
**			08/17/2006 mem - Added support for column Entered_By
**    
*****************************************************/
(
	@intervalHrs int = 168
)
As
	set nocount on
	declare @cutoffDateTime datetime
	
	set @cutoffDateTime = dateadd(hour, -1 * @intervalHrs, getdate())

	declare @DBName varchar(128)
	set @DBName = DB_NAME()

	declare @logVerbosity int -- 0 silent, 1 minimal, 2 verbose, 3 debug
	set @logVerbosity = 0
	
	---------------------------------------------------
	-- Start transaction
	---------------------------------------------------
	--
	declare @transName varchar(64)
	set @transName = 'TRAN_MoveHistoricLogEntries'
	begin transaction @transName

	---------------------------------------------------
	-- put entries into historic log
	---------------------------------------------------
	--
	INSERT INTO MT_HistoricLog.dbo.T_Historic_Log_Entries
		(Entry_ID, posted_by, posting_time, type, message, Entered_By, DBName) 
	SELECT 	Entry_ID, posted_by, posting_time, type, message, Entered_By, @DBName
	FROM 	T_Log_Entries
	WHERE 	posting_time < @cutoffDateTime
	
	--
	if @@error <> 0
	begin
		rollback transaction @transName
		RAISERROR ('Insert was unsuccessful for historic log entry table',
			10, 1)
		return 51180
	end

	---------------------------------------------------
	-- remove entries from main log
	---------------------------------------------------
	--
	DELETE FROM T_Log_Entries
	WHERE posting_time < @cutoffDateTime
	--
	if @@error <> 0
	begin
		rollback transaction @transName
		RAISERROR ('Delete was unsuccessful for log entry table',
			10, 1)
		return 51181
	end
	
	if @logVerbosity > 1
	begin
		declare @message varchar(255)
		set @message = 'Cleaned up T_Log_Entries'
		execute PostLogEntry 'Normal', @message, 'MoveHistoricLogEntries'
	end
	
	---------------------------------------------------
	-- Commit transaction
	---------------------------------------------------
	commit transaction @transName
	
	return 0

GO
GRANT EXECUTE ON [dbo].[MoveHistoricLogEntries] TO [DMS_SP_User]
GO
GRANT VIEW DEFINITION ON [dbo].[MoveHistoricLogEntries] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[MoveHistoricLogEntries] TO [MTS_DB_Lite]
GO
