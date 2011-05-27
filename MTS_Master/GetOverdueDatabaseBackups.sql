/****** Object:  StoredProcedure [dbo].[GetOverdueDatabaseBackups] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure dbo.GetOverdueDatabaseBackups
/****************************************************
** 
**		Desc: Returns a combined report of overdue database backups 
**			  on the servers in V_Active_MTS_Servers
**
**		Return values: 0: success, otherwise, error code
** 
**		Parameters:
**
**		Auth:	mem
**		Date:	12/06/2004
**    
*****************************************************/
	@ServerFilter varchar(128) = '',				-- If supplied, then only examines the databases on the given Server
	@message varchar(255) = '' OUTPUT
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
	-- temporary table to hold database names
	---------------------------------------------------
	CREATE TABLE #DBNames (
		[Server_Name] varchar(64) NOT NULL,
		[DBName] [varchar] (128) NOT NULL
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
			-- Populate #DBNames temporary table 
			---------------------------------------------------

			Set @Sql = ''				
			Set @Sql = @Sql + ' INSERT INTO #DBNames'
			Set @Sql = @Sql + '  (Server_Name, DBName)'
			Set @Sql = @Sql + ' SELECT ''' + @Server + ''', [Name]'
			Set @Sql = @Sql + ' FROM ' + @MTMain + 'V_Last_Active_DB_Backup_Overdue'
						
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
	SELECT * FROM #DBNames
	ORDER BY Server_Name, DBName
		--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 
	begin
		set @message = 'Error returning data from #DBNames'
		set @myError = 50004
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
			set @message = 'Error finding DBs with overdue backups; Error code: ' + convert(varchar(32), @myError)
		
		execute PostLogEntry 'Error', @message, 'GetOverdueDatabaseBackups'
	end

	return @myError

GO
GRANT EXECUTE ON [dbo].[GetOverdueDatabaseBackups] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetOverdueDatabaseBackups] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[GetOverdueDatabaseBackups] TO [MTS_DB_Lite] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetOverdueDatabaseBackups] TO [MTS_DB_Lite] AS [dbo]
GO
