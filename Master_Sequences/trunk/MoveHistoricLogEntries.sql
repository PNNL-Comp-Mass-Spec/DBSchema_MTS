/****** Object:  StoredProcedure [dbo].[MoveHistoricLogEntries] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure MoveHistoricLogEntries
/****************************************************
**
**	Desc: Move log entries from main log into the 
**        historic log (insert and then delete)
**        that are older then given by @intervalHrs
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters: 
**
**	
**
**		Auth: grk
**		Date: 08/29/2001
**			  08/01/2004 - Updated @intervalHrs to 168 (1 week)
**    
*****************************************************/
(
	@intervalHrs int = 168
)
As
	set nocount on
	declare @cutoffDateTime datetime
	
	set @cutoffDateTime = dateadd(hour, -1 * @intervalHrs, getdate())

	declare @DBName varchar(64)
	set @DBName = DB_NAME()

	set nocount off
	
	-- Start transaction
	--
	declare @transName varchar(64)
	set @transName = 'TRAN_MoveHistoricLogEntries'
	begin transaction @transName

	-- put entries into historic log
	--
	INSERT INTO MT_HistoricLog..T_Historic_Log_Entries
		(Entry_ID, posted_by, posting_time, type, message, DBName) 
	SELECT 
		 Entry_ID, posted_by, posting_time, type, message, @DBName
	FROM T_Log_Entries
	WHERE posting_time < @cutoffDateTime
	
	--
	if @@error <> 0
	begin
		rollback transaction @transName
		RAISERROR ('Insert was unsuccessful for historic log entry table',
			10, 1)
		return 51180
	end

	-- remove entries from main log
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
	
--	declare @message varchar(255)
--	set @message = 'Exited'
--	execute PostLogEntry 'Normal', @message, 'MoveHistoricLogEntries'

	
	commit transaction @transName
	
	return 0


GO
