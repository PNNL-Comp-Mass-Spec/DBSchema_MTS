/****** Object:  StoredProcedure [dbo].[RefreshCachedGeneralStatistics]    Script Date: 08/14/2006 20:23:22 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.RefreshCachedGeneralStatistics
/****************************************************
**
**	Desc: 
**	Updates the contents of T_General_Statistics_Cached
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**		@message   -- explanation of any error that occurred
**
**		Auth: mem
**		Date: 12/06/2004
**			  12/16/2004 mem - Now making entries in T_General_Statistics_Cached for entries that have a blank T_General_Statistics table
**			  08/02/2005 mem - Now checking for discrepancies between General_Statistics entries of DB_Schema_Version and the value stored in T_MTS_MT_DBs or T_MTS_Peptide_DBs
**			  11/23/2005 mem - Added brackets around @CurrentDB as needed to allow for DBs with dashes in the name
**    
*****************************************************/
	@ServerFilter varchar(128) = '',		-- If supplied, then only examines the databases on the given Server
	@message varchar(512) = '' output
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
	declare @CurrentServerPrefix varchar(128)

	declare @CurrentDB varchar(255)
	declare @Campaign varchar(128)
	declare @Organism varchar(128)
	declare @DBNameMatch varchar(128)
	
	declare @Continue int
	declare @ServerDBsDone int
	declare @processCount int			-- Count of servers processed

	declare @DBSchemaVersionGeneralStats real
	declare @DBSchemaVersion real

	---------------------------------------------------
	-- temporary table to hold list of databases to process
	---------------------------------------------------
	CREATE TABLE #DBNames (
		DBName varchar(128) NOT NULL,
		Campaign varchar(128) NULL,
		Organism varchar(128) NULL,
		Processed tinyint NOT NULL
	)

	CREATE UNIQUE INDEX #IX__TempTable__DBNames ON #DBNames(DBName)

	---------------------------------------------------
	-- temporary table to hold servers processed
	---------------------------------------------------
	CREATE TABLE #ServerNames (
		Server_Name varchar(64) NOT NULL
	)
	
	---------------------------------------------------
	-- temporary table to hold data so that we can update T_General_Statistics_Cached en masse
	---------------------------------------------------
	CREATE TABLE #GeneralStatisticsCached (
		[Server_Name] [varchar] (64) NOT NULL ,
		[DBName] [varchar] (128) NOT NULL ,
		[Category] [varchar] (128) NULL ,
		[Label] [varchar] (128) NULL ,
		[Value] [varchar] (255) NULL ,
		[Entry_ID] [int] NOT NULL 
	)

	---------------------------------------------------
	-- temporary table to hold list of PMT tag and peptide DBs defined in MTS_Master
	---------------------------------------------------
	CREATE TABLE #MTSMasterDBs (
		[Server_Name] [varchar] (64) NOT NULL ,
		[DBName] [varchar] (128) NOT NULL ,
		[DB_Schema_Version] [real] NOT NULL 
	)

	CREATE UNIQUE CLUSTERED INDEX #IX__TempTable__MTSMasterDBs ON #MTSMasterDBs([Server_Name], [DBName])

	-----------------------------------------------------------
	-- Populate #MTSMasterDBs
	-----------------------------------------------------------

	INSERT INTO #MTSMasterDBs (Server_Name, DBName, DB_Schema_Version)
	SELECT MTServers.Server_Name, MTDBs.MT_DB_Name, DB_Schema_Version
	FROM T_MTS_MT_DBs MTDBs INNER JOIN
		 T_MTS_Servers MTServers ON MTDBs.Server_ID = MTServers.Server_ID
	WHERE MTServers.Active = 1
	UNION
	SELECT MTServers.Server_Name, PDBs.Peptide_DB_Name, DB_Schema_Version
	FROM T_MTS_Peptide_DBs PDBs INNER JOIN
		 T_MTS_Servers MTServers ON PDBs.Server_ID = MTServers.Server_ID
	WHERE MTServers.Active = 1
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


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
			-- Clear #DBNames
			---------------------------------------------------

			DELETE FROM #DBNames
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount


			---------------------------------------------------
			-- populate temporary table with MT DBs to examine
			---------------------------------------------------

			Set @sql = ''
			Set @sql = @sql + ' INSERT INTO #DBNames (DBName, Campaign, Organism, Processed)'
			Set @sql = @sql + ' SELECT [Name], Campaign, Organism, 0 AS Processed'
			Set @sql = @sql + ' FROM ' + @CurrentServerPrefix + 'MT_Main.dbo.V_MT_Database_List_Report_Ex'
			Set @sql = @sql + ' WHERE (StateID <> 100)'
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
			-- populate temporary table with Peptide DBs to examine
			---------------------------------------------------
			
			Set @sql = ''
			Set @sql = @sql + ' INSERT INTO #DBNames (DBName, Organism, Processed)'
			Set @sql = @sql + ' SELECT [Name], Organism, 0 AS Processed'
			Set @sql = @sql + ' FROM ' + @CurrentServerPrefix + 'MT_Main.dbo.V_Peptide_Database_List_Report_Ex'
			Set @sql = @sql + ' WHERE (StateID <> 100)'
			--
			EXEC @result = sp_executesql @sql

			
			---------------------------------------------------
			-- Add the server name to #ServerNames
			---------------------------------------------------
			INSERT INTO #ServerNames (Server_Name) VALUES (@Server)
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			
			
			-----------------------------------------------------------
			-- process each entry in #DBNames
			-----------------------------------------------------------
			
			set @ServerDBsDone = 0

			WHILE @ServerDBsDone = 0 and @myError = 0  
			BEGIN --<a>
			
				-- get next available entry from #DBNames
				--
				SELECT	TOP 1 @CurrentDB = DBName, @Campaign = Campaign, @Organism = Organism
				FROM	#DBNames
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
						UPDATE	#DBNames
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
							goto NextPass

						-- Copy general statistics entries from target DB into #GeneralStatisticsCached
						--
						Set @Sql = ''				
						Set @Sql = @Sql + ' INSERT INTO #GeneralStatisticsCached'
						Set @Sql = @Sql + '  (Server_Name, DBName, Category, Label, Value, Entry_ID)'
						Set @Sql = @Sql + ' SELECT ''' + @Server + ''', ''' + @CurrentDB + ''', '
						Set @Sql = @Sql + '   Category, Label, Value, Entry_ID'
						Set @Sql = @Sql + ' FROM ' + @CurrentServerPrefix + '[' + @CurrentDB + '].dbo.V_General_Statistics_Report'
									
						EXEC sp_executesql @Sql	
						--
						SELECT @myError = @@error, @myRowCount = @@rowcount	
						--
						If @myRowCount = 0
						Begin
							-- No general statistics were found
							-- Add a few informational rows to #GeneralStatisticsCached anyway
							
							INSERT INTO #GeneralStatisticsCached (Server_Name, DBName, Category, Label, Value, Entry_ID)
							VALUES (@Server, @CurrentDB, 'Configuration Settings', 'DB_Schema_Version', '2.0', 1)
							
							INSERT INTO #GeneralStatisticsCached (Server_Name, DBName, Category, Label, Value, Entry_ID)
							VALUES (@Server, @CurrentDB, 'Configuration Settings', 'Campaign', @Campaign, 2)

							INSERT INTO #GeneralStatisticsCached (Server_Name, DBName, Category, Label, Value, Entry_ID)
							VALUES (@Server, @CurrentDB, 'Configuration Settings', 'Organism', @Organism, 3)
							
							INSERT INTO #GeneralStatisticsCached (Server_Name, DBName, Category, Label, Value, Entry_ID)
							VALUES (@Server, @CurrentDB, 'Configuration Settings', 'Peptide_DB_Name', 'Unknown', 4)

							INSERT INTO #GeneralStatisticsCached (Server_Name, DBName, Category, Label, Value, Entry_ID)
							VALUES (@Server, @CurrentDB, 'Configuration Settings', 'Organism_DB_File_Name', 'Unknown', 5)
								
						End
						Else
						Begin
							-- Validate the General_Statistics DB_Schema_Version against that in #MTSMasterDBs
							
							Set @DBSchemaVersion = 0
							SELECT TOP 1 @DBSchemaVersion = DB_Schema_Version
							FROM #MTSMasterDBs
							WHERE DBName = @CurrentDB AND Server_Name = @Server
							--
							SELECT @myError = @@error, @myRowCount = @@rowcount	
							
							If @myRowCount = 1
							Begin
								Set @DBSchemaVersionGeneralStats = 0
								
								SELECT TOP 1 @DBSchemaVersionGeneralStats = Convert(real, Value)
								FROM #GeneralStatisticsCached
								WHERE Server_Name = @Server AND DBName = @CurrentDB AND Label = 'DB_Schema_Version'
								--
								SELECT @myError = @@error, @myRowCount = @@rowcount	
								
								If @myRowCount = 1 
								Begin
									If @DBSchemaVersion <> @DBSchemaVersionGeneralStats
									Begin
										set @message = 'Error: DB Schema Version in ' + @Server + '.' + @CurrentDB + '.T_General_Statistics does not agree with value in MTS_Master'
										execute PostLogEntry 'Error', @message, 'RefreshCachedGeneralStatistics'
									End
								End
							End

						End
						
					end --<b>	
			NextPass:	   
			END --<a>
			
			Set @processCount = @processCount + 1
			
		End -- </B>
			
	End -- </A>
	

	---------------------------------------------------
	-- Delete the appropriate entries in T_General_Statistics_Cached,
	-- then add the new ones in #GeneralStatisticsCached
	---------------------------------------------------
	Declare @tranUpdateStats varchar(128)
	Set @tranUpdateStats = 'UpdateGeneralStatistics'
	
	Begin Transaction @tranUpdateStats
	
	If @ProcessSingleServer = 1
		DELETE T_General_Statistics_Cached
		FROM T_General_Statistics_Cached INNER JOIN #ServerNames ON
			T_General_Statistics_Cached.Server_Name = #ServerNames.Server_Name
	Else
		TRUNCATE TABLE T_General_Statistics_Cached
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	If @myError <> 0
	Begin
		set @message = 'Error clearing T_General_Statistics_Cached'
		Rollback Transaction @tranUpdateStats
		Goto Done
	End
	
	
	INSERT INTO T_General_Statistics_Cached
		(Server_Name, DBName, Category, Label, Value, Entry_ID)
	SELECT Server_Name, DBName, Category, Label, Value, Entry_ID
	FROM #GeneralStatisticsCached
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	If @myError <> 0
	Begin
		set @message = 'Error updating T_General_Statistics_Cached with new data '
		Rollback Transaction @tranUpdateStats
		Goto Done
	End
	
	Commit Transaction @tranUpdateStats

	
Done:
	-----------------------------------------------------------
	-- Exit
	-----------------------------------------------------------
	--
	if @myError <> 0
	begin
		If Len(@message) = 0
			set @message = 'Error updating T_General_Statistics_Cached; Error code: ' + convert(varchar(32), @myError)
		
		execute PostLogEntry 'Error', @message, 'RefreshCachedGeneralStatistics'
	end

	return @myError

GO
