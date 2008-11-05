/****** Object:  StoredProcedure [dbo].[PostLogEntryFlushCache] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

create Procedure PostLogEntryFlushCache
/****************************************************
**
**	Desc:	Appends the contents of #Tmp_Cached_Log_Entries to T_Log_Entries,
**			then clears #Tmp_Cached_Log_Entries
**
**			The calling procedure must create and populate #Tmp_Cached_Log_Entries
**
**		CREATE TABLE #Tmp_Cached_Log_Entries (
**			[Entry_ID] int IDENTITY(1,1) NOT NULL,
**			[posted_by] varchar(128) NULL,
**			[posting_time] datetime NOT NULL DEFAULT (GetDate()),
**			[type] varchar(128) NULL,
**			[message] varchar(4096) NULL,
**			[Entered_By] varchar(128) NULL DEFAULT (suser_sname()),
**		)
**
**
**	Return values: 0: success, otherwise, error code
*
**	Auth:	mem
**	Date:	08/26/2008
**    
*****************************************************/
(
	@message varchar(128) = ''
)
As

	INSERT INTO T_Log_Entries
		(posted_by, posting_time, type, message, entered_by) 
	SELECT posted_by, posting_time, type, message, entered_by
	FROM #Tmp_Cached_Log_Entries
	ORDER BY Entry_ID
	
	TRUNCATE TABLE #Tmp_Cached_Log_Entries 
	
	return 0

GO
GRANT VIEW DEFINITION ON [dbo].[PostLogEntryFlushCache] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[PostLogEntryFlushCache] TO [MTS_DB_Lite]
GO
