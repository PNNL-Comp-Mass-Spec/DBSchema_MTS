/****** Object:  StoredProcedure [dbo].[GetAllMassTagDatabases] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.GetAllMassTagDatabases
/****************************************************
**
**	Desc: Return list of all mass tag databases in prism
**        
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**		@message   -- explanation of any error that occurred
**
**		Auth: grk
**		Date: 4/07/2004
**			 04/09/2004 grk - removed default on @message argument
**			 04/16/2004 mem - Added [Last Update] column
**			 05/05/2004 mem - Added filtering out of MTDB's with state 'unused'
**			 05/06/2004 mem - Added @IncludeUnused and @IncludeDeleted parameters
**			 10/23/2004 mem - Added PostUsageLogEntry and switched to using V_MT_Database_List_Report_Ex in MT_Main
**			 12/06/2004 mem - Switched to use Pogo.MTS_Master..GetAllMassTagDatabases
**			 05/13/2005 mem - Added parameter @VerboseColumnOutput
**    
*****************************************************/
	@message varchar(512)='' output,
	@IncludeUnused tinyint = 0,			-- Set to 1 to include unused databases
	@IncludeDeleted tinyint = 0,		-- Set to 1 to include deleted databases
	@ServerFilter varchar(128) = '',	-- If supplied, then only examines the databases on the given Server
	@VerboseColumnOutput tinyint = 1	-- Set to 0 to show only first 4 columns
As
	set nocount on

	Declare @myError int
	set @myError = 0
	
	set @message = ''
	Exec @myError = Pogo.MTS_Master.dbo.GetAllMassTagDatabases @IncludeUnused, @IncludeDeleted, 
															@ServerFilter, 
															@message = @message output, 
															@VerboseColumnOutput = @VerboseColumnOutput

	Declare @UsageMessage varchar(512)
	Set @UsageMessage = Convert(varchar(3), @IncludeUnused) + ', ' + Convert(varchar(3), @IncludeDeleted)
	Exec PostUsageLogEntry 'GetAllMassTagDatabases', '', @UsageMessage

Done:
	return @myError

GO
GRANT EXECUTE ON [dbo].[GetAllMassTagDatabases] TO [DMS_SP_User]
GO
