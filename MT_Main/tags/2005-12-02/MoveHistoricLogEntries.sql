SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[MoveHistoricLogEntries]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[MoveHistoricLogEntries]
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
**		Date: 07/30/2003
**		      04/14/2004 grk - added log verbosity control
**			  08/13/2005 mem - Updated @intervalHrs to 168 (1 week)
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

	declare @logVerbosity int -- 0 silent, 1 minimal, 2 verbose, 3 debug
	set @logVerbosity = 1
	
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
		set @message = 'Cleaned up MT_Main log'
		execute PostLogEntry 'Normal', @message, 'MoveHistoricLogEntries'
	end
	
	---------------------------------------------------
	-- end transaction
	---------------------------------------------------
	commit transaction @transName
	
	return 0

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[MoveHistoricLogEntries]  TO [DMS_SP_User]
GO

