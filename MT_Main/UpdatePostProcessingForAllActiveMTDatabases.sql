/****** Object:  StoredProcedure [dbo].[UpdatePostProcessingForAllActiveMTDatabases] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE UpdatePostProcessingForAllActiveMTDatabases
/****************************************************
** 
**	Desc:	For each active database listed in T_MT_Database_List
**			Calls the SP MasterUpdateQRProcessStart or MasterUpdatePeakMatchingPostProcessing
**			if it exists in the MT database.
**
**	Return values: 0: success, otherwise, error code
** 
**	Parameters:
**
**	Auth:	grk
**	Date:	09/03/2003
**			04/12/2004 grk - added interlock with T_Current_Activity update state
**			04/14/2004 grk - added log verbosity control
**			04/21/2004 grk - added logic to do GANET and Post Processing for DB in T_Current_Activity regardless of DB state
**			09/28/2004 mem - Updated #XMTDBNames populate query to exclude deleted databases
**			10/11/2005 mem - Now updating all DBs with state between 1 and 5, even if not present in T_Current_Activity; However, if the state is 3 or 4, then 'MasterUpdateQRProcessStart' is called instead of 'MasterUpdatePeakMatchingPostProcessing'
**			11/23/2005 mem - Added brackets around @CurrentMTDB as needed to allow for DBs with dashes in the name
**			03/13/2006 mem - Now calling VerifyUpdateEnabled
**			08/03/2006 mem - Fixed bug when verifying that each database exists on the server
**			11/03/2009 mem - Added parameter @DebugMode
**    
*****************************************************/
(
	@DebugMode tinyint = 0		-- When non-zero, then will use Select statements to show the each DB name and stored procedure called
)
As
	set nocount on
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @cmd nvarchar(255)
	declare @result int
	declare @UpdateEnabled tinyint

	declare @MTL_Name varchar(64)
	declare @MTL_State int
	declare @MTL_tag varchar(24)
	
	declare @message varchar(255)

	declare @SPRowCount int
	set @SPRowCount = 0

	declare @S nvarchar(1024),
			@CurrentMTDB varchar(255),
			@CurrentMTState int,
			@SPToExec varchar(255),
			@PreferredDBName varchar(255)
	
	declare @yesList varchar(1024)
	declare @noList varchar(1024)

	set @yesList = ''
	set @noList = ''
		
	declare @logVerbosity int -- 0 silent, 1 minimal, 2 verbose, 3 debug
	set @logVerbosity = 1

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled 'MS_Peak_Matching', 'UpdatePostProcessingForAllActiveMTDatabases', @AllowPausing = 0, @PostLogEntryIfDisabled = 0, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done

	Set @DebugMode = IsNull(@DebugMode, 0)
	
	---------------------------------------------------
	-- temporary table to hold list of databases to process
	---------------------------------------------------

	CREATE TABLE #XMTDBNames (
		MTDB_Name varchar(128),
		MT_State int,
		Processed tinyint
	) 

	---------------------------------------------------
	-- populate temporary table with list of mass tag
	-- databases that are in current activity table
	-- and have been successfully updated
	-- or are active and that are not
	-- presently being updated
	---------------------------------------------------

	INSERT INTO #XMTDBNames (MTDB_Name, MT_State, Processed)
	SELECT	MTL_Name, MTL_State, 0
	FROM	T_MT_Database_List
	WHERE
	(
		(MTL_State BETWEEN 1 AND 5) AND 
		NOT EXISTS
		(
			SELECT	*
			FROM	T_Current_Activity
			WHERE	(Update_State = 2) AND (Type = 'MT') AND (Database_Name = MTL_Name)
		) 
	) OR
		MTL_State <> 100 AND
		EXISTS
		(
			SELECT	*
			FROM	T_Current_Activity
			WHERE	(Update_State = 3) AND (Type = 'MT') AND (Database_Name = MTL_Name)
		)
	ORDER BY MTL_Name
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'could not load temporary table'
		goto done
	end

	-----------------------------------------------------------
	-- process each entry in current temporary table
	-----------------------------------------------------------
	
	declare @targetSPName varchar(64)

	declare @done int
	set @done = 0

	WHILE @done = 0 and @myError = 0  
	BEGIN --<a>
	
		-- get next available entry from current activity table
		-- (order by state so that production state DBs are updated first)
		--
		SELECT	TOP 1 @CurrentMTDB = MTDB_Name, @CurrentMTState = MT_State
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
			set @done = 1
		end
		else
		begin --<b>
			-- get database name tag
			--
			exec @MTL_tag = DatabaseNameTag @CurrentMTDB

		
			-- mark entry in temporary table as processed
			--
			UPDATE	#XMTDBNames
			SET		Processed = 1
			WHERE	(MTDB_Name = @CurrentMTDB)
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--
			if @myError <> 0 
			begin
				set @message = 'Could not update the mass tag database list temp table'
				set @myError = 51
				goto Done
			end

			-- Check if @CurrentMTDB exists
			--
			if Not Exists (SELECT * FROM master.dbo.sysdatabases WHERE [name] = @CurrentMTDB)
			Begin
				--
				-- skip further processing if database does not exist
				--

				If @logVerbosity > 1
				Begin
					set @message = 'Database "' + @CurrentMTDB + '" does not exist'
					execute PostLogEntry 'Error', @message, 'UpdatePostProcessingForAllActiveMTDatabases'
				End
			End
			Else
			Begin

				If @CurrentMTState = 3 or @CurrentMTState = 4
					Set @targetSPName = 'MasterUpdateQRProcessStart'
				Else
					Set @targetSPName = 'MasterUpdatePeakMatchingPostProcessing'
					
				-- Check if the target SP exists for @CurrentMTDB
				--
				Set @S = ''				
				Set @S = @S + ' SELECT @SPRowCount = COUNT(*)'
				Set @S = @S + ' FROM [' + @CurrentMTDB + ']..sysobjects'
				Set @S = @S + ' WHERE [name] = ''' + @targetSPName + ''''
							
				EXEC sp_executesql @S, N'@SPRowCount int OUTPUT', @SPRowCount OUTPUT

				If (@SPRowCount = 0)
				begin
					set @noList = @noList + ',' + @MTL_tag 
				end
				else
				begin --<c>
					set @yesList = @yesList + ',' + @MTL_tag 

					-- Call target SP in @CurrentMTDB
					--
					Set @SPToExec = '[' + @CurrentMTDB + ']..' + @targetSPName
					
					If @DebugMode <> 0
						Select @SPToExec
					
					Exec @myError = @SPToExec	
				end --<c>
			End
			
		end --<b>	
	
		-- Validate that updating is enabled, abort if not enabled
		exec VerifyUpdateEnabled 'MS_Peak_Matching', 'UpdatePostProcessingForAllActiveMTDatabases', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
		If @UpdateEnabled = 0
			Goto Done

	END --<a>

	-----------------------------------------------------------
	-- Note which MTDBs were and were not processed
	-----------------------------------------------------------
	--
	if @logVerbosity > 1
	begin
		set @message = 'Processed:(' + @yesList + ') Not processed:(' + @noList + ')'
		declare @msg varchar(500)
		set @msg = cast(@message as varchar(500))
		execute PostLogEntry 'Normal', @msg, 'UpdatePostProcessingForAllActiveMTDatabases'
	end


Done:
	-----------------------------------------------------------
	-- Exit
	-----------------------------------------------------------
	--
	if @myError <> 0 and @logVerbosity > 0
	begin
		set @message = 'Master Update Error ' + convert(varchar(32), @myError) + ' occurred'
		execute PostLogEntry 'Error', @message, 'UpdatePostProcessingForAllActiveMTDatabases'
	end

	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[UpdatePostProcessingForAllActiveMTDatabases] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[UpdatePostProcessingForAllActiveMTDatabases] TO [MTS_DB_Lite] AS [dbo]
GO
