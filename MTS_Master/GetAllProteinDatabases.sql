/****** Object:  StoredProcedure [dbo].[GetAllProteinDatabases] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.GetAllProteinDatabases
/****************************************************
**
**	Desc: Return list of all ORF (protein) databases in MT_Main
**		  on each server listed in V_Active_MTS_Servers
**		  Also returns status information about the DBs
**        
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	12/15/2004
**			05/13/2005 mem - Added parameter @VerboseColumnOutput
**			07/25/2006 mem - Updated to exclude databases with state 15 in addition to state 100 when @IncludeDeleted = 0
**    
*****************************************************/
(
	@IncludeUnused tinyint = 0,				-- Set to 1 to include unused databases
	@IncludeDeleted tinyint = 0,			-- Set to 1 to include deleted databases
	@ServerFilter varchar(128) = '',		-- If supplied, then only examines the databases on the given Server
	@message varchar(512)='' output,
	@VerboseColumnOutput tinyint = 1
)
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
		[State] [varchar] (64) NULL,
		[Created] [datetime] NULL,
		[Server Name] [varchar] (64) NOT NULL,
		[DB ID] [int] NOT NULL
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
			Set @Sql = @Sql + '  ([Name], Description, Organism, State,'
			Set @Sql = @Sql + '   Created, [Server Name], [DB ID])'
			Set @Sql = @Sql + ' SELECT [Name], Description, Organism, State, '
			Set @Sql = @Sql + '   Created, ''' + @Server + ''', ODB_ID'
			Set @Sql = @Sql + ' FROM ' + @MTMain + 'V_ORF_Database_List_Report_Ex'

			If @IncludeUnused = 0
			Begin
				If Len(@sqlWhereClause) > 0
					Set @sqlWhereClause = @sqlWhereClause + ' AND '
				set @sqlWhereClause = @sqlWhereClause + '(StateID NOT IN (10, 15))'
			End

			If @IncludeDeleted = 0
			Begin
				If Len(@sqlWhereClause) > 0
					Set @sqlWhereClause = @sqlWhereClause + ' AND '
				set @sqlWhereClause = @sqlWhereClause + '(StateID NOT IN (15, 100))'
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
		SELECT [Name], Description, Organism
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
			set @message = 'Error preparing list of ORF (protein) databases; Error code: ' + convert(varchar(32), @myError)
		
		execute PostLogEntry 'Error', @message, 'GetAllProteinDatabases'
	end

	return @myError


GO
GRANT EXECUTE ON [dbo].[GetAllProteinDatabases] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetAllProteinDatabases] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetAllProteinDatabases] TO [MTS_DB_Lite] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[GetAllProteinDatabases] TO [MTUser] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[GetAllProteinDatabases] TO [pogo\MTS_DB_Dev] AS [dbo]
GO
