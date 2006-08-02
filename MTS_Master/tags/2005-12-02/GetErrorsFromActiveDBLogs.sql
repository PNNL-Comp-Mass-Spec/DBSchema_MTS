SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[GetErrorsFromActiveDBLogs]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[GetErrorsFromActiveDBLogs]
GO

CREATE Procedure dbo.GetErrorsFromActiveDBLogs
/****************************************************
** 
**		Desc: Returns a combined report of errors (or all log entries) from 
**			  active DBs on the servers in V_Active_MTS_Servers
**
**		Return values: 0: success, otherwise, error code
** 
**		Parameters:
**
**		Auth:	mem
**		Date:	12/06/2004
**				12/13/2004 mem - Added the PRISM_RPT database
**				02/06/2005 mem - Added Master_Sequences_T3
**				02/24/2005 mem - Moved Master_Sequences to Albert
**				10/10/2005 mem - Removed PrismDev.Master_Sequences_T3
**				11/23/2005 mem - Added brackets around @CurrentDB as needed to allow for DBs with dashes in the name
**    
*****************************************************/
	@ServerFilter varchar(128) = '',				-- If supplied, then only examines the databases on the given Server
	@errorsOnly int = 1,							-- If 1, then only returns error entries
	@MaxLogEntriesPerDB int = 100,					-- Set to 0 to disable filtering number of 
	@message varchar(255) = '' OUTPUT
As	
	set nocount on
	
	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	-- Validate or clear the input/output parameters
	Set @ServerFilter = IsNull(@ServerFilter, '')
	Set @MaxLogEntriesPerDB = IsNull(@MaxLogEntriesPerDB, 100)
	Set @message = ''

	declare @SQL nvarchar(1024)
	declare @result int
	set @result = 0

	declare @logVerbosity int -- 0 silent, 1 minimal, 2 verbose, 3 debug
	set @logVerbosity = 1

	if @logVerbosity > 1
	begin
		set @message = 'Begin GetErrorsFromActiveDBLogs'
		execute PostLogEntry 'Normal', @message, 'GetErrorsFromActiveDBLogs'
	end
	
	declare @ProcessSingleServer tinyint
	
	If Len(@ServerFilter) > 0
		Set @ProcessSingleServer = 1
	Else
		Set @ProcessSingleServer = 0

	declare @MaxRowCountText nvarchar(40)
	if @MaxLogEntriesPerDB <=0
		set @MaxRowCountText = N' '
	else
		set @MaxRowCountText = N' TOP ' + Convert(nvarchar(24), @MaxLogEntriesPerDB) + N' '
	
	declare @Server varchar(128)
	declare @CurrentServerPrefix varchar(128)
	declare @ServerID int

	declare @CurrentDB varchar(255)
	declare @DBNameMatch varchar(128)
	
	declare @Continue int
	declare @ServerDBsDone int
	declare @processCount int			-- Count of servers processed

	---------------------------------------------------
	-- temporary table to hold extracted log error entries
	---------------------------------------------------
	CREATE TABLE #LE (
		[Server_Name] varchar(64) NOT NULL,
		[DBName] [varchar] (128) NOT NULL,
		[Entry_ID] [int],
		[posted_by] [varchar] (64) NULL,
		[posting_time] [datetime],
		[type] [varchar] (32) NULL,
		[message] [varchar] (500) NULL
	)

	---------------------------------------------------
	-- temporary table to hold list of databases to process
	---------------------------------------------------
	CREATE TABLE #XMTDBNames (
		DBName varchar(128),
		Processed tinyint
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
				Set @CurrentServerPrefix = ''
			Else
				Set @CurrentServerPrefix = @Server + '.'

			---------------------------------------------------
			-- Clear #XMTDBNames and add MT_Main, Prism_IFC, and Prism_RPT
			---------------------------------------------------
			--
			DELETE FROM #XMTDBNames
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			INSERT INTO #XMTDBNames (DBName, Processed) VALUES ('MT_Main', 0)
			INSERT INTO #XMTDBNames (DBName, Processed) VALUES ('Prism_IFC', 0)
			INSERT INTO #XMTDBNames (DBName, Processed) VALUES ('Prism_RPT', 0)

			---------------------------------------------------
			-- populate temporary table with MT databases
			-- in current activity table
			---------------------------------------------------

			Set @sql = ''
			Set @sql = @sql + ' INSERT INTO #XMTDBNames (DBName, Processed)'
			Set @sql = @sql + ' SELECT CA.Database_Name, 0 AS Processed'
			Set @sql = @sql + ' FROM ' + @CurrentServerPrefix + 'MT_Main.dbo.T_Current_Activity AS CA INNER JOIN '
			Set @sql = @sql +     @CurrentServerPrefix + 'MT_Main.dbo.T_MT_Database_List AS MT ON '
			Set @sql = @sql + '   CA.Database_ID = MT.MTL_ID AND CA.Type = ''MT'''
			Set @sql = @sql + ' WHERE (MT.MTL_State <> 100)'
			Set @sql = @sql + ' ORDER BY CA.Database_Name'
			--
			EXEC @result = sp_executesql @sql
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--
			if @myError <> 0
			begin
				set @message = 'could not load temporary table'
				goto done
			end

			---------------------------------------------------
			-- populate temporary table with Peptide databases
			-- in current activity table
			---------------------------------------------------

			Set @sql = ''
			Set @sql = @sql + ' INSERT INTO #XMTDBNames (DBName, Processed)'
			Set @sql = @sql + ' SELECT CA.Database_Name, 0 AS Processed'
			Set @sql = @sql + ' FROM ' + @CurrentServerPrefix + 'MT_Main.dbo.T_Current_Activity AS CA INNER JOIN '
			Set @sql = @sql +     @CurrentServerPrefix + 'MT_Main.dbo.T_Peptide_Database_List AS PT ON '
			Set @sql = @sql + '   CA.Database_ID = PT.PDB_ID AND CA.Type = ''PT'''
			Set @sql = @sql + ' WHERE (PT.PDB_State <> 100)'
			Set @sql = @sql + ' ORDER BY CA.Database_Name'
			--
			EXEC @result = sp_executesql @sql
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--
			if @myError <> 0
			begin
				set @message = 'could not load temporary table'
				goto done
			end


			-----------------------------------------------------------
			-- process each entry in #XMTDBNames
			-----------------------------------------------------------
			
			set @ServerDBsDone = 0

			WHILE @ServerDBsDone = 0 and @myError = 0  
			BEGIN --<a>
			
				-- get next available entry from #XMTDBNames
				--
				SELECT	TOP 1 @CurrentDB = DBName
				FROM	#XMTDBNames 
				WHERE	Processed = 0
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				--
				if @myError <> 0 
				begin
					set @message = 'Could not get next entry from temporary table'
					set @myError = 39
					goto Done
				end
								
				-- terminate loop if no more unprocessed entries in temporary table
				--
				if @myRowCount = 0
					begin
						set @ServerDBsDone = 1
					end
				else
					begin --<b>
					
						-- mark entry in temporary table as processed
						--
						UPDATE	#XMTDBNames
						SET		Processed = 1
						WHERE	(DBName = @CurrentDB)
						--
						SELECT @myError = @@error, @myRowCount = @@rowcount
						--
						if @myError <> 0 
						begin
							set @message = 'Could not update the database list temp table'
							set @myError = 51
							goto Done
						end
						
						-- Check if @CurrentDB exists
						--
						Set @DBNameMatch = ''
						
						Set @sql = ''
						Set @sql = @sql + ' SELECT @DBNameMatch = [name]'
						Set @sql = @sql + ' FROM ' + @CurrentServerPrefix + 'master.dbo.sysdatabases'
						Set @sql = @sql + ' WHERE [name] = ''' + @CurrentDB + ''''
						--
						EXEC @result = sp_executesql @sql, N'@DBNameMatch varchar(128) OUTPUT', @DBNameMatch = @DBNameMatch OUTPUT
						--
						SELECT @myError = @@error, @myRowCount = @@rowcount
						--
						if @result <> 0 
						begin
							set @message = 'Could not check existence of database'
							set @myError = 53
							goto Done
						end
						--
						-- skip further processing if database does not exist
						--
						if (@myRowCount = 0 or Len(IsNull(@DBNameMatch, '')) = 0)
							begin
								set @message = 'Database "' + @CurrentDB + '" does not exist on ' + @Server
								if @logVerbosity > 1
									execute PostLogEntry 'Error', @message, 'GetErrorsFromActiveDBLogs'
								set @message = ''
								goto NextPass
							end

						-- get error entries for log from target DB into temporary table
						--
						Set @Sql = ''				
						Set @Sql = @Sql + ' INSERT INTO #LE'
						Set @Sql = @Sql + ' (Server_Name, DBName, Entry_ID, posted_by, posting_time, type, message)'
						Set @Sql = @Sql + ' SELECT ' + @MaxRowCountText + '''' + @Server + ''', ''' + @CurrentDB + ''', '
						Set @Sql = @Sql + '   Entry_ID, posted_by, posting_time, type, message'
						Set @Sql = @Sql + ' FROM ' + @CurrentServerPrefix + '[' + @CurrentDB + '].dbo.T_Log_Entries'
						if @errorsOnly = 1
						begin
							Set @Sql = @Sql + ' WHERE type = ''error'''
						end
									
						EXEC sp_executesql @Sql	
						--
						SELECT @myError = @@error, @myRowCount = @@rowcount	
									
					end --<b>	
			NextPass:	   
			END --<a>

			Set @processCount = @processCount + 1
			
		End -- </B>
			
	End -- </A>
	
	-----------------------------------------------------------
	-- Get errors from Albert.Master_Sequences
	-----------------------------------------------------------

	Set @Sql = ''				
	Set @Sql = @Sql + ' INSERT INTO #LE'
	Set @Sql = @Sql + ' (Server_Name, DBName, Entry_ID, posted_by, posting_time, type, message)'
	Set @Sql = @Sql + ' SELECT ' + @MaxRowCountText + '''Albert'', ''Master_Sequences'', '
	Set @Sql = @Sql + '   Entry_ID, posted_by, posting_time, type, message'
	Set @Sql = @Sql + ' FROM Albert.Master_Sequences.dbo.T_Log_Entries'
	if @errorsOnly = 1
	begin
		Set @Sql = @Sql + ' WHERE type = ''error'''
	end
				
	EXEC sp_executesql @Sql	
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount	



	-----------------------------------------------------------
	-- Get errors from this DB (MTS_Master)
	-----------------------------------------------------------

	Set @Sql = ''				
	Set @Sql = @Sql + ' INSERT INTO #LE'
	Set @Sql = @Sql + ' (Server_Name, DBName, Entry_ID, posted_by, posting_time, type, message)'
	Set @Sql = @Sql + ' SELECT ' + @MaxRowCountText + '''' + @@ServerName + ''', ''' + DB_Name() + ''', '
	Set @Sql = @Sql + '   Entry_ID, posted_by, posting_time, type, message'
	Set @Sql = @Sql + ' FROM T_Log_Entries'
	if @errorsOnly = 1
	begin
		Set @Sql = @Sql + ' WHERE type = ''error'''
	end
				
	EXEC sp_executesql @Sql	
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount	
	

	-----------------------------------------------------------
	-- Return the data
	-----------------------------------------------------------
	--
	SELECT * FROM #LE
	ORDER BY Server_Name, DBName
		--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 
	begin
		set @message = 'Error returning data from #CurrentActivity'
		set @myError = 50004
		goto Done
	end
	
Done:
	-----------------------------------------------------------
	-- Exit
	-----------------------------------------------------------
	--

	-----------------------------------------------------------
	-- if there were errors, make log entry
	-----------------------------------------------------------
	--
	if @myError <> 0 and @logVerbosity > 0
	begin
		set @message = 'Error polling DB logs; Error code: ' + convert(varchar(32), @myError)
		execute PostLogEntry 'Error', @message, 'GetErrorsFromActiveDBLogs'
	end

	-----------------------------------------------------------
	-- Announce end of process
	-----------------------------------------------------------
	
	if @logVerbosity > 1
	begin
		set @message = 'Complete GetErrorsFromActiveDBLogs'
		execute PostLogEntry 'Normal', @message, 'GetErrorsFromActiveDBLogs'
	end

	return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[GetErrorsFromActiveDBLogs]  TO [DMS_SP_User]
GO

