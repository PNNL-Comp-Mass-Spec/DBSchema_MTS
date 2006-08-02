SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[GetAllPeptideDatabases]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[GetAllPeptideDatabases]
GO

CREATE PROCEDURE dbo.GetAllPeptideDatabases
/****************************************************
**
**	Desc: Return list of all peptide tag databases in prism
**        
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**		@message   -- explanation of any error that occurred
**
**		Auth:	mem
**		Date:	10/24/2004 - Modelled after GetAllMassTagDatabases
**				12/06/2004 mem - Switched to use Pogo.MTS_Master..GetAllPeptideDatabases
**				05/13/2005 mem - Added parameter @VerboseColumnOutput
**    
*****************************************************/
	@message varchar(512) = '' output,
	@IncludeUnused tinyint = 0,			-- Set to 1 to include unused databases
	@IncludeDeleted tinyint = 0,		-- Set to 1 to include deleted databases
	@ServerFilter varchar(128) = '',	-- If supplied, then only examines the databases on the given Server
	@VerboseColumnOutput tinyint = 1	-- Set to 0 to show only first 3 columns
As

	set nocount on

	Declare @myError int
	set @myError = 0
	
	set @message = ''
	Exec @myError = Pogo.MTS_Master.dbo.GetAllPeptideDatabases @IncludeUnused, @IncludeDeleted, 
															@ServerFilter, 
															@message = @message output, 
															@VerboseColumnOutput = @VerboseColumnOutput

	Declare @UsageMessage varchar(512)
	Set @UsageMessage = Convert(varchar(3), @IncludeUnused) + ', ' + Convert(varchar(3), @IncludeDeleted)
	Exec PostUsageLogEntry 'GetAllPeptideDatabases', '', @UsageMessage

Done:
	return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[GetAllPeptideDatabases]  TO [DMS_SP_User]
GO

