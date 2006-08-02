SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[GetAllMassTagDatabases]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[GetAllMassTagDatabases]
GO

CREATE PROCEDURE dbo.GetAllMassTagDatabases
/****************************************************
**
**	Desc: Return list of all mass tag databases in MT_Main
**		  on each server listed in V_Active_MTS_Servers
**		  Also returns status information about the DBs
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
**			 12/06/2004 mem - Ported to MTS_Master
**			 12/15/2004 mem - Added [DB ID] column
**			 05/13/2005 mem - Added parameter @VerboseColumnOutput
**			 08/02/2005 mem - Added [DB Schema Version] column
**    
*****************************************************/
	@IncludeUnused tinyint = 0,				-- Set to 1 to include unused databases
	@IncludeDeleted tinyint = 0,			-- Set to 1 to include deleted databases
	@ServerFilter varchar(128) = '',		-- If supplied, then only examines the databases on the given Server
	@message varchar(512)='' output,
	@VerboseColumnOutput tinyint = 1
As	
	set nocount on
	
	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	-- Validate or clear the input/output parameters
	Set @ServerFilter = IsNull(@ServerFilter, '')
	Set @message = ''

	declare @Sql nvarchar(1024)
	declare @sqlWhereClause nvarchar(256)
	
	declare @result int
	set @result = 0

	declare @ProcessSingleServer tinyint
	
	If Len(@ServerFilter) > 0
		Set @ProcessSingleServer = 1
	Else
		Set @ProcessSingleServer = 0

	declare @Server varchar(128)
	declare @ServerID int
	declare @MTMain varchar(128)

	declare @Continue int
	declare @processCount int			-- Count of servers processed

	---------------------------------------------------
	-- temporary table to hold database stats
	---------------------------------------------------
	CREATE TABLE #DBStats (
		[Name] [varchar] (128) NOT NULL,
		[Description] [varchar] (2048) NULL,
		[Organism] [varchar] (64) NULL,
		[Campaign] [varchar] (64) NULL,
		[State] [varchar] (64) NULL,
		[Created] [datetime] NULL,
		[Last Update] [datetime] NULL,
		[Server Name] [varchar] (64) NOT NULL,
		[DB ID] [int] NOT NULL,
		[DB Schema Version] real NOT NULL
	)
		
	-----------------------------------------------------------
	-- Process each server in V_Active_MTS_Servers
	-----------------------------------------------------------
	--
	set @processCount = 0
	set @ServerID = -1
	set @Continue = 1
	--	
	While @Continue > 0 and @myError = 0
	Begin -- <A>

		SELECT TOP 1
			@ServerID = Server_ID,
			@Server = Server_Name
		FROM  V_Active_MTS_Servers
		WHERE Server_ID > @ServerID
		ORDER BY Server_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0 
		begin
			set @message = 'Could not get next entry from V_Active_MTS_Servers'
			set @myError = 50001
			goto Done
		end
		Set @continue = @myRowCount

		If @continue > 0 And (@ProcessSingleServer = 0 Or Lower(@Server) = Lower(@ServerFilter))
		Begin -- <B>

			-- If @Server is actually this server, then we do not need to prepend table names with the text
			If Lower(@Server) = Lower(@@ServerName)
				Set @MTMain = 'MT_Main.dbo.'
			Else
				Set @MTMain = @Server + '.MT_Main.dbo.'

			---------------------------------------------------
			-- Populate #DBStats temporary table 
			---------------------------------------------------

			Set @Sql = ''				
			Set @sqlWhereClause = ''
			
			Set @Sql = @Sql + ' INSERT INTO #DBStats'
			Set @Sql = @Sql + '  ([Name], Description, Organism, Campaign, State, '
			Set @Sql = @Sql + '   Created, [Last Update], [Server Name], [DB ID], [DB Schema Version])'
			Set @Sql = @Sql + ' SELECT [Name], Description, Organism, Campaign, State, '
			Set @Sql = @Sql + '   Created, [Last Update], ''' + @Server + ''', MTL_ID, DB_Schema_Version'
			Set @Sql = @Sql + ' FROM ' + @MTMain + 'V_MT_Database_List_Report_Ex'

			If @IncludeUnused = 0
			Begin
				If Len(@sqlWhereClause) > 0
					Set @sqlWhereClause = @sqlWhereClause + ' AND '
				set @sqlWhereClause = @sqlWhereClause + '(StateID NOT IN (10,15))'
			End

			If @IncludeDeleted = 0
			Begin
				If Len(@sqlWhereClause) > 0
					Set @sqlWhereClause = @sqlWhereClause + ' AND '
				set @sqlWhereClause = @sqlWhereClause + '(StateID <> 100)'
			End
			
			If Len(@sqlWhereClause) > 0
				set @Sql = @Sql + ' WHERE ' + @sqlWhereClause

			EXEC sp_executesql @Sql	
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount	

			Set @processCount = @processCount + 1
			
		End -- </B>
			
	End -- </A>
	
	-----------------------------------------------------------
	-- Return the data
	-----------------------------------------------------------
	--
	If @VerboseColumnOutput <> 0
		SELECT * FROM #DBStats
		ORDER BY [Name], [Server Name]
	Else
		SELECT [Name], Description, Organism, Campaign
		FROM #DBStats
		ORDER BY [Name], [Server Name]
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 
	begin
		set @message = 'Error returning data from #DBStats'
		set @myError = 50002
		goto Done
	end
	
Done:
	-----------------------------------------------------------
	-- Exit
	-----------------------------------------------------------
	--
	if @myError <> 0
	begin
		If Len(@message) = 0
			set @message = 'Error preparing list of PMT databases; Error code: ' + convert(varchar(32), @myError)
		
		execute PostLogEntry 'Error', @message, 'GetAllMassTagDatabases'
	end

	return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[GetAllMassTagDatabases]  TO [DMS_SP_User]
GO

GRANT  EXECUTE  ON [dbo].[GetAllMassTagDatabases]  TO [MTUser]
GO

GRANT  EXECUTE  ON [dbo].[GetAllMassTagDatabases]  TO [pogo\MTS_DB_Dev]
GO

GRANT  EXECUTE  ON [dbo].[GetAllMassTagDatabases]  TO [MTS_DB_Lite]
GO

