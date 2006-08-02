SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[GetErrorsFromActiveDBLogs]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[GetErrorsFromActiveDBLogs]
GO

CREATE PROCEDURE dbo.GetErrorsFromActiveDBLogs
/****************************************************
** 
**	Desc:	For each entry in the current activity table
**			gets any log entries whose type is 'Error'.
**			Optionally gets all entries. 
**
**	Return values: 0: success, otherwise, error code
** 
**	Parameters:
**
**	Auth:	grk
**	Date:	04/16/2004
**			09/28/2004 mem - Updated #XMTDBNames populate query to exclude deleted databases
**			12/06/2004 mem - Added lookup of errors in PrismDev.Master_Sequences
**			11/23/2005 mem - Added brackets around @CurrentDB as needed to allow for DBs with dashes in the name
**						   - Removed call to PrismDev.Master_Sequences
**			03/20/2006 mem - Updated to use all databases with state < 10, plus any extra ones that might be in T_Current_Activity
**    
*****************************************************/
(
	@errorsOnly int = 1
)
As
	set nocount on
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @cmd nvarchar(255)
	declare @result int

	declare @DBNameMatch varchar(128)
	
	declare @message varchar(255)

	declare @SPRowCount int
	set @SPRowCount = 0

	declare @S nvarchar(1024),
			@CurrentDB varchar(255)

	declare @logVerbosity int -- 0 silent, 1 minimal, 2 verbose, 3 debug
	set @logVerbosity = 1

	if @logVerbosity > 1
	begin
		set @message = 'Begin GetErrorsFromActiveDBLogs'
		execute PostLogEntry 'Normal', @message, 'GetErrorsFromActiveDBLogs'
	end

	---------------------------------------------------
	-- temporary table to hold extracted log error entries
	---------------------------------------------------
	CREATE TABLE #LE (
		Entry_ID int,
		posted_by varchar(64),
		posting_time datetime,
		type varchar(32),
		message varchar (512),
		DBName varchar(128) 
	) 
	
	---------------------------------------------------
	-- temporary table to hold list of databases to process
	---------------------------------------------------
	CREATE TABLE #XMTDBNames (
		DBName varchar(128),
		Processed tinyint
	) 

	---------------------------------------------------
	-- add MT_Main to list of DB to have their logs combed
	---------------------------------------------------
	INSERT INTO #XMTDBNames (DBName, Processed)
	VALUES     ('MT_Main', 0)
	
	---------------------------------------------------
	-- populate temporary table with active MT databases
	---------------------------------------------------
	
	INSERT INTO #XMTDBNames (DBName, Processed)
	SELECT MT.MTL_Name, 0 AS Processed
	FROM T_MT_Database_List MT
	WHERE MT.MTL_State < 10
	UNION
	SELECT MT.MTL_Name, 0 AS Processed
	FROM T_Current_Activity CA INNER JOIN T_MT_Database_List MT ON 
	     CA.Database_ID = MT.MTL_ID AND CA.Type = 'MT'
	WHERE MT.MTL_State <> 100
	ORDER BY MT.MTL_Name
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

	INSERT INTO #XMTDBNames (DBName, Processed)
	SELECT PT.PDB_Name, 0 AS Processed
	FROM T_Peptide_Database_List PT
	WHERE (PT.PDB_State < 10)
	UNION
	SELECT PT.PDB_Name, 0 AS Processed
	FROM T_Current_Activity CA INNER JOIN T_Peptide_Database_List PT ON 
	     CA.Database_ID = PT.PDB_ID AND CA.Type = 'PT'
	WHERE (PT.PDB_State <> 100)
	ORDER BY PT.PDB_Name
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	-----------------------------------------------------------
	-- Process each entry in #XMTDBNames
	-----------------------------------------------------------
	
	declare @done int
	set @done = 0

	WHILE @done = 0 and @myError = 0  
	BEGIN --<a>
	
		-- get next available entry from temporary table
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
				set @done = 1
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
				SELECT	@DBNameMatch = [name]
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
				-- skip further processing if database does not exist
				--
				if @myRowCount = 0 and @logVerbosity > 1
					begin
						set @message = 'Database "' + @CurrentDB + '" does not exist'
						execute PostLogEntry 'Error', @message, 'GetErrorsFromActiveDBLogs'
						goto NextPass
					end

				-- get error entries for log from target DB into temporary table
				--
				Set @S = ''				
				Set @S = @S + ' INSERT INTO #LE (Entry_ID, posted_by, posting_time, type, message, DBName)'
				Set @S = @S + ' SELECT Entry_ID, posted_by, posting_time, type, message, ''' + @CurrentDB + ''''
				Set @S = @S + ' FROM [' + @CurrentDB + ']..T_Log_Entries'
				if @errorsOnly = 1
				begin
					Set @S = @S + ' WHERE type = ''error'''
				end
							
				EXEC sp_executesql @S					
			end --<b>	
	NextPass:	   
	END --<a>

	-----------------------------------------------------------
	-- return contents of temporary table
	-----------------------------------------------------------
	--
	SELECT DBName, Entry_ID, posted_by, type, message, posting_time
	FROM #LE
	ORDER BY DBName, Entry_ID DESC

Done:
	-----------------------------------------------------------
	-- if there were errors, make log entry
	-----------------------------------------------------------
	--
	if @myError <> 0 and @logVerbosity > 0
	begin
		set @message = 'Error ' + convert(varchar(32), @myError) + ' occurred'
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

