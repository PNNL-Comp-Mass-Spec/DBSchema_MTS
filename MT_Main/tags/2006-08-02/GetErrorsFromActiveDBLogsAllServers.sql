SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[GetErrorsFromActiveDBLogsAllServers]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[GetErrorsFromActiveDBLogsAllServers]
GO

CREATE Procedure dbo.GetErrorsFromActiveDBLogsAllServers
/****************************************************
** 
**		Desc: Calls Pogo.MTS_Master.dbo.GetErrorsFromActiveDBLogs
**
**		Return values: 0: success, otherwise, error code
** 
**		Parameters:
**
**		Auth:	mem
**		Date:	09/30/2005
**    
*****************************************************/
	@ServerFilter varchar(128) = '',				-- If supplied, then only examines the databases on the given Server
	@errorsOnly int = 1,							-- If 1, then only returns error entries
	@MaxLogEntriesPerDB int = 10,					-- Set to 0 to disable filtering number of 
	@message varchar(255) = '' OUTPUT
As	
	set nocount on
	
	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	Exec Pogo.MTS_Master.dbo.GetErrorsFromActiveDBLogs @ServerFilter, @errorsOnly, @MaxLogEntriesPerDB, @message = @message OUTPUT


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

