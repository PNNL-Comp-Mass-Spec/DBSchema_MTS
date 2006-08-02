SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[UpdateNETForAllActiveMTDatabases]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[UpdateNETForAllActiveMTDatabases]
GO

CREATE PROCEDURE UpdateNETForAllActiveMTDatabases
/****************************************************
** 
**		Desc:
**		For each active database listed in T_MT_Database_List
**      Calls the 'MasterUpdateNET' SP if it exists.
**
**		Return values: 0: success, otherwise, error code
** 
**		Parameters:
**
**		Auth:	grk
**		Date:	10/10/2003
**				04/12/2004 grk - added interlock with T_Current_Activity update state
**				04/14/2004 grk - added log verbosity control
**				04/21/2004 grk - added logic to do GANET and Post Processing for DB in T_Current_Activity regardless of DB state
**				09/28/2004 mem - Updated #XMTDBNames populate query to exclude deleted databases
**				11/23/2005 mem - Added brackets around @CurrentMTDB as needed to allow for DBs with dashes in the name
**    
*****************************************************/
As
	set nocount on
	
	declare @myError int
	set @myError = 0

	declare @myRowCount int
	set @myRowCount = 0

	declare @cmd nvarchar(255)
	declare @result int

	declare @MTL_Name varchar(64)
	declare @MTL_State int
	declare @MTL_tag varchar(24)
	
	declare @message varchar(255)

	declare @SPRowCount int
	set @SPRowCount = 0

	declare @S nvarchar(1024),
			@CurrentMTDB varchar(255),
			@SPToExec varchar(255),
			@PreferredDBName varchar(255)
			
	declare @yesList varchar(1024)
	declare @noList varchar(1024)

	set @yesList = ''
	set @noList = ''
	
	declare @logVerbosity int -- 0 silent, 1 minimal, 2 verbose, 3 debug
	set @logVerbosity = 1

	if @logVerbosity > 1
	begin
		set @message = 'Begin processing master NET update'
		execute PostLogEntry 'Normal', @message, 'UpdateNETForAllActiveMTDatabases'
	end

	---------------------------------------------------
	-- temporary table to hold list of databases to process
	---------------------------------------------------

	CREATE TABLE #XMTDBNames (
		MTDB_Name varchar(128),
		Processed tinyint
	) 
	
	---------------------------------------------------
	-- populate temporary table with list of mass tag
	-- databases that are in current activity table
	-- and have been successfully updated
	-- or are active and that are not
	-- presently being updated
	---------------------------------------------------
	
	INSERT INTO #XMTDBNames
	SELECT	MTL_Name, 0
	FROM	T_MT_Database_List
	WHERE
	(
		MTL_State IN (2, 5) AND 
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
	-- process each entry in temporary table
	-----------------------------------------------------------
	
	declare @targetSPName varchar(64)
	set @targetSPName = 'MasterUpdateNET'

	declare @done int
	set @done = 0

	WHILE @done = 0 and @myError = 0  
	BEGIN --<a>
	
		-- get next available entry from temporary table
		--
		SELECT	TOP 1 @CurrentMTDB = MTDB_Name
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
				SELECT	[name]
				FROM master.dbo.sysdatabases
				WHERE [name] = @CurrentMTDB
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
				-- skip further processing if database does not exist
				--
				if @myRowCount = 0 and @logVerbosity > 1
					begin
						set @message = 'Database "' + @CurrentMTDB + '" does not exist'
						execute PostLogEntry 'Error', @message, 'UpdateNETForAllActiveMTDatabases'
						goto NextPass
					end
				
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
					
					Select @SPToExec
					
					Exec @myError = @SPToExec	
				end --<c>
			end --<b>	
	NextPass:	   
	END --<a>

Done:
	-----------------------------------------------------------
	-- if there were errors, make log entry
	-----------------------------------------------------------
	--
	if @myError <> 0 and @logVerbosity > 0
	begin
		set @message = 'Master Update Error ' + convert(varchar(32), @myError) + ' occurred'
		execute PostLogEntry 'Error', @message, 'UpdateNETForAllActiveMTDatabases'
	end

	-----------------------------------------------------------
	-- Note which MTDB were and were not processed
	-----------------------------------------------------------
	--
	if @logVerbosity > 1
	begin
		set @message = 'Processed:(' + @yesList + ') Not processed:(' + @noList + ')'
		declare @msg varchar(500)
		set @msg = cast(@message as varchar(500))
		execute PostLogEntry 'Normal', @message, 'UpdateNETForAllActiveMTDatabases'
	end

	-----------------------------------------------------------
	-- Announce end of master sub process
	-----------------------------------------------------------
	
	if @logVerbosity > 1
	begin
		set @message = 'Complete processing master NET update'
		execute PostLogEntry 'Normal', @message, 'UpdateNETForAllActiveMTDatabases'
	end

	return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[UpdateNETForAllActiveMTDatabases]  TO [DMS_SP_User]
GO

