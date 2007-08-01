/****** Object:  StoredProcedure [dbo].[CleanupLogAllActiveDatabases] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE CleanupLogAllActiveDatabases
/****************************************************
** 
**	Desc: Calls the log cleanup stored procedure for the active databases
**
**	Return values: 0: success, otherwise, error code
** 
**	Parameters:
**
**	Auth:	grk
**	Date:	04/16/2004
**			08/13/2005 mem - Consolidated processing of both Peptide and MT databases in this procedure
**						   - Added call to MoveHistoricLogEntries in Master_Sequences and in MT_Main
**			11/23/2005 mem - Added brackets around @CurrentMTDB as needed to allow for DBs with dashes in the name
**			07/15/2006 mem - Updated list of database states to process to include state 7
**						   - Updated to use Sql Server 2005 system views if possible
**    
*****************************************************/
As	
	set nocount on
	
	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	declare @cmd nvarchar(255)
	declare @result int
	
	declare @message varchar(255)

	declare @SPRowCount int
	set @SPRowCount = 0

	declare @S nvarchar(1024),
			@CurrentDB varchar(255),
			@SPToExec varchar(255),
			@PreferredDBName varchar(255)
			
	declare @DBCountProcessed int
	declare @DBCountSkipped int

	set @DBCountProcessed = 0
	set @DBCountSkipped = 0
	
	declare @logVerbosity int -- 0 silent, 1 minimal, 2 verbose, 3 debug
	set @logVerbosity = 1

	if @logVerbosity > 1
	begin
		set @message = 'Begin processing cleanup logs'
		execute PostLogEntry 'Normal', @message, 'CleanupLogAllActiveDatabases'
	end

	---------------------------------------------------
	-- Determine whether or not we're running Sql Server 2005 or newer
	---------------------------------------------------
	Declare @VersionMajor int
	Declare @UseSystemViews tinyint
	
	exec GetServerVersionInfo @VersionMajor output

	If @VersionMajor >= 9
		set @UseSystemViews = 1
	else
		set @UseSystemViews = 0

	---------------------------------------------------
	-- Create temporary table to hold list of databases to process
	---------------------------------------------------

	CREATE TABLE #XDBNames (
		DatabaseName varchar(128),
		Processed tinyint
	) 

	---------------------------------------------------
	-- Populate the temporary table with list of
	-- active databases
	---------------------------------------------------
	
	-- First add the Peptide Databases
	INSERT INTO #XDBNames
	SELECT PDB_Name, 0
	FROM T_Peptide_Database_List
	WHERE PDB_State IN (2, 5, 7)
	ORDER BY PDB_Name
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Error populating temporary table #XDBNames'
		goto done
	end

	-- Now add the PMT Tag Databases
	INSERT INTO #XDBNames
	SELECT MTL_Name, 0
	FROM T_MT_Database_List
	WHERE MTL_State IN (2, 5, 7)
	ORDER BY MTL_Name
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	-- Now add MT_Main and the Master_Sequences DB
	-- Note that the DB will be skipped if not present
	INSERT INTO #XDBNames VALUES ('MT_Main', 0)
	INSERT INTO #XDBNames VALUES ('Master_Sequences', 0)

	-----------------------------------------------------------
	-- Process each entry in the temporary table
	-----------------------------------------------------------
	
	declare @targetSPName varchar(64)
	set @targetSPName = 'MoveHistoricLogEntries'

	declare @done int
	set @done = 0

	WHILE @done = 0 and @myError = 0  
	BEGIN --<a>
	
		-- Get next available entry from the temporary table
		--
		SELECT TOP 1 @CurrentDB = DatabaseName
		FROM #XDBNames 
		WHERE Processed = 0
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
			set @done = 1
		else
		begin --<b>
			-- mark entry in temporary table as processed
			--
			UPDATE #XDBNames
			SET Processed = 1
			WHERE DatabaseName = @CurrentDB
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--
			if @myError <> 0 
			begin
				set @message = 'Could not update the mass tag database list temp table'
				set @myError = 51
				goto Done
			end
			
			-- Verify that @CurrentDB exists
			--
			If @UseSystemViews = 1
				SELECT @PreferredDBName = [name]
				FROM master.sys.databases
				WHERE [name] = @CurrentDB
			Else
				SELECT @PreferredDBName = [name]
				FROM master.dbo.sysdatabases
				WHERE [name] = @CurrentDB
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--
			if @myError <> 0 
			begin
				set @message = 'Could not check existence of database'
				set @myError = 53
				goto Done
			end
			
			--
			-- Continue if database exists
			--
			if @myRowCount > 0
			begin
				-- Check if the target SP exists for @CurrentDB
				--
				If @UseSystemViews = 1
				Begin
					Set @S = ''				
					Set @S = @S + ' SELECT @SPRowCount = COUNT(*)'
					Set @S = @S + ' FROM [' + @PreferredDBName + '].sys.procedures'
					Set @S = @S + ' WHERE [name] = ''' + @targetSPName + ''''
				End
				Else
				Begin
					Set @S = ''				
					Set @S = @S + ' SELECT @SPRowCount = COUNT(*)'
					Set @S = @S + ' FROM [' + @PreferredDBName + '].dbo.sysobjects'
					Set @S = @S + ' WHERE [name] = ''' + @targetSPName + ''''
				End
											
				EXEC sp_executesql @S, N'@SPRowCount int OUTPUT', @SPRowCount OUTPUT

				If (@SPRowCount = 0)
					set @DBCountSkipped = @DBCountSkipped + 1
				else
				begin --<c>
					set @DBCountProcessed = @DBCountProcessed + 1

					-- Call target SP in @CurrentDB
					--
					Set @SPToExec = '[' + @CurrentDB + '].dbo.' + @targetSPName
					
					Exec @myError = @SPToExec	
				end
			end
		end --<b>	
	END --<a>

Done:
	-----------------------------------------------------------
	-- if there were errors, make log entry
	-----------------------------------------------------------
	--
	if @myError <> 0 and @logVerbosity > 0
	begin
		set @message = 'Log cleanup error ' + convert(varchar(12), @myError) + ' occurred'
		execute PostLogEntry 'Error', @message, 'CleanupLogAllActiveDatabases'
	end

	if @DBCountSkipped > 0 and @logVerbosity > 0
	begin
		set @message = 'Found ' + convert(varchar(12), @DBCountSkipped) + ' databases missing SP ' + @targetSPName
		execute PostLogEntry 'Error', @message, 'CleanupLogAllActiveDatabases'
	end
	
	-----------------------------------------------------------
	-- Log count of databases processed
	-----------------------------------------------------------
	--
	if @logVerbosity > 0
	begin
		set @message = 'Moved old log entries to MT_HistoricLog; processed ' + convert(varchar(12), @DBCountProcessed) + ' databases'
		execute PostLogEntry 'Normal', @message, 'CleanupLogAllActiveDatabases'
	end

	-----------------------------------------------------------
	-- Announce end of master sub process
	-----------------------------------------------------------
	
	if @logVerbosity > 1
	begin
		set @message = 'Complete processing'
		execute PostLogEntry 'Normal', @message, 'CleanupLogAllActiveDatabases'
	end

	return @myError

GO
