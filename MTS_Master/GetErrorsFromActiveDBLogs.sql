/****** Object:  StoredProcedure [dbo].[GetErrorsFromActiveDBLogs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure [dbo].[GetErrorsFromActiveDBLogs]
/****************************************************
** 
**	Desc: Returns a combined report of errors (or all log entries) from 
**		  active DBs on the servers in V_Active_MTS_Servers
**
**	Return values: 0: success, otherwise, error code
** 
**	Parameters:
**
**	Auth:	mem
**	Date:	12/06/2004
**			12/13/2004 mem - Added the PRISM_RPT database
**			02/06/2005 mem - Added Master_Sequences_T3
**			02/24/2005 mem - Moved Master_Sequences to Albert
**			10/10/2005 mem - Removed PrismDev.Master_Sequences_T3
**			11/23/2005 mem - Added brackets around @CurrentDB as needed to allow for DBs with dashes in the name
**			05/13/2006 mem - Moved Master_Sequences from Albert to Daffy
**			11/21/2006 mem - Moved Master_Sequences from Daffy to ProteinSeqs
**			07/13/2007 mem - Increased the field sizes in #LE
**			02/19/2008 mem - Now populating T_MTS_DB_Errors with the errors found; use AckErrors to view these errors and optionally change them to ErrorIgnore
**			07/23/2008 mem - Moved Master_Sequences to Porky
**			02/27/2010 mem - Moved Master_Sequences to ProteinSeqs2
**          12/10/2019 mem - Moved Master_Sequences to Pogo
**    
*****************************************************/
(
	@ServerFilter varchar(128) = '',				-- If supplied, then only examines the databases on the given Server
	@errorsOnly int = 1,							-- If 1, then only returns error entries; ignored if @CacheErrorsOnly = 1
	@MaxLogEntriesPerDB int = 10,					-- Set to 0 to disable filtering number of entries for each DB; affects the errors returned in the resultset
	@CacheErrorsOnly tinyint = 0,					-- Set to 1 to populate T_MTS_DB_Errors but not return the errors as a resultset
	@message varchar(255) = '' OUTPUT
)
As	
	set nocount on
	
	Declare @myError int = 0
	Declare @myRowCount int = 0

	---------------------------------------------------
	-- Validate the inputs
	---------------------------------------------------
	
	Set @ServerFilter = IsNull(@ServerFilter, '')
	Set @errorsOnly = IsNull(@errorsOnly, 1)
	Set @MaxLogEntriesPerDB = IsNull(@MaxLogEntriesPerDB, 100)
	Set @CacheErrorsOnly = IsNull(@CacheErrorsOnly, 0)
	Set @message = ''

	If @CacheErrorsOnly <> 0
	Begin
		Set @errorsOnly = 1
	End
	
	Declare @SQL nvarchar(2048)
	Declare @result int = 0

	Declare @logVerbosity int -- 0 silent, 1 minimal, 2 verbose, 3 debug
	set @logVerbosity = 1

	if @logVerbosity > 1
	begin
		set @message = 'Begin GetErrorsFromActiveDBLogs'
		execute PostLogEntry 'Normal', @message, 'GetErrorsFromActiveDBLogs'
	end
	
	Declare @ProcessSingleServer tinyint
	
	If Len(@ServerFilter) > 0
		Set @ProcessSingleServer = 1
	Else
		Set @ProcessSingleServer = 0
	
	Declare @Server varchar(128)
	Declare @CurrentServerPrefix varchar(128)
	Declare @ServerID int

	Declare @CurrentDB varchar(255)
	Declare @DBNameMatch varchar(128)
	
	Declare @Continue int
	Declare @DBExists tinyint
	
	Declare @ServerDBsDone int
	Declare @processCount int			-- Count of servers processed

	---------------------------------------------------
	-- Temporary table to hold extracted log error entries
	---------------------------------------------------
	CREATE TABLE #LE (
		Server_Name varchar(128) NOT NULL,
		DBName varchar(256) NOT NULL,
		Entry_ID int,
		posted_by varchar(256) NULL,
		posting_time datetime,
		type varchar(128) NULL,
		message varchar(4096) NULL,
		Entered_By varchar(256) NULL,
		Entry_Rank int NULL
	)
	
	CREATE UNIQUE CLUSTERED INDEX [#IX_Tmp_LE] ON [dbo].[#LE] 
	(
		[Server_Name] ASC,
		[DBName] ASC,
		[Entry_ID] ASC
	)
		
	---------------------------------------------------
	-- Temporary table to hold list of databases to process
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
	Begin -- <a>

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
		Begin -- <b>

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
			-- Populate temporary table with MT databases
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
			-- Populate temporary table with Peptide databases
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
			-- Process each entry in #XMTDBNames
			-----------------------------------------------------------
			
			set @ServerDBsDone = 0

			WHILE @ServerDBsDone = 0 and @myError = 0  
			BEGIN -- <c>
			
				-- Get next available entry from #XMTDBNames
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
								
				-- Terminate loop if no more unprocessed entries in temporary table
				--
				if @myRowCount = 0
				begin
					set @ServerDBsDone = 1
				end
				else
				begin -- <d>
				
					-- Mark entry in temporary table as processed
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

					-- Skip further processing if database does not exist
					--
					if (@myRowCount = 0 or Len(IsNull(@DBNameMatch, '')) = 0)
					begin
						set @message = 'Database "' + @CurrentDB + '" does not exist on ' + @Server
						if @logVerbosity > 1
							execute PostLogEntry 'Error', @message, 'GetErrorsFromActiveDBLogs'
						set @message = ''
						set @DBExists = 0
					end
					else
					begin
						set @DBExists = 1
					end
					
					-- Get error log entries from the target DB; place in the #LE temporary table
					if @DBExists = 1
						Exec GetErrorsFromSingleDB @Server, @CurrentDB, @errorsOnly, @MaxLogEntriesPerDB, @message output
														
				end -- </d>
			   
			END -- </c>

			Set @processCount = @processCount + 1
			
		End -- </b>
			
	End -- </a>
	
	-----------------------------------------------------------
	-- Get errors from Pogo.Master_Sequences
	-----------------------------------------------------------

	Exec GetErrorsFromSingleDB 'Pogo', 'Master_Sequences', @errorsOnly, @MaxLogEntriesPerDB, @message output

	-----------------------------------------------------------
	-- Get errors from this DB (MTS_Master)
	-----------------------------------------------------------

	Set @Server = @@ServerName
	Set @CurrentDB = DB_Name()
	Exec GetErrorsFromSingleDB @Server, @CurrentDB, @errorsOnly, @MaxLogEntriesPerDB, @message output

	-----------------------------------------------------------
	-- Populate the Entry_Rank column
	-----------------------------------------------------------

	UPDATE #LE
	SET Entry_Rank = RankingQ.RowRank
	FROM #LE Target INNER JOIN (
		SELECT Server_Name, DBName, Entry_ID, 
			Row_Number() OVER (Partition By Server_Name, DBName Order By Entry_ID) AS RowRank
		FROM #LE
		) RankingQ ON 
			Target.Server_Name = RankingQ.Server_Name AND
		Target.DBName = RankingQ.DBName AND
		Target.Entry_ID = RankingQ.Entry_ID 
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	-----------------------------------------------------------
	-- Add errors to T_MTS_DB_Errors (if not already present)
	-----------------------------------------------------------
	
	INSERT INTO T_MTS_DB_Errors (
		Server_Name, Database_Name, Entry_ID, Posted_By, 
		Posting_Time, Type, Message, Entered_By)
	SELECT Src.Server_Name, Src.DBName, Src.Entry_ID, Src.Posted_By, 
	       Src.Posting_Time, Src.Type, Src.Message, Src.Entered_By
	FROM #LE Src LEFT OUTER JOIN T_MTS_DB_Errors Target ON
		  Src.Server_Name = Target.Server_Name AND
		  Src.DBName = Target.Database_Name AND
		  Src.Entry_ID = Target.Entry_ID AND
		  Src.Posting_Time = Target.Posting_Time
	WHERE Src.Type = 'Error' AND Target.Entry_ID Is Null
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	
	-----------------------------------------------------------
	-- Return the data
	-----------------------------------------------------------
	--
	If @CacheErrorsOnly = 0
	Begin
		SELECT Server_Name, DBName, Entry_ID, posted_by, 
               posting_time, type, message, Entered_By
		FROM #LE
		WHERE @MaxLogEntriesPerDB <= 0 OR Entry_Rank <= @MaxLogEntriesPerDB
		ORDER BY Server_Name, DBName, Entry_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0 
		begin
			set @message = 'Error returning data from #LE'
			set @myError = 50004
			goto Done
		end
	End
		
Done:
	-----------------------------------------------------------
	-- Exit
	-----------------------------------------------------------
	--

	-----------------------------------------------------------
	-- If there were errors, make log entry
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
GRANT EXECUTE ON [dbo].[GetErrorsFromActiveDBLogs] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetErrorsFromActiveDBLogs] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetErrorsFromActiveDBLogs] TO [MTS_DB_Lite] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[GetErrorsFromActiveDBLogs] TO [pnl\svc-dms] AS [dbo]
GO
