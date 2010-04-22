/****** Object:  StoredProcedure [dbo].[GetGANETTaskActivity] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.GetGANETTaskActivity
/****************************************************
** 
**		Desc: 
**		Gets list of most recent GANET update tasks in each PMT Tag and Peptide DB
**
**		Return values: 0: success, otherwise, error code
** 
** 
**		Auth: grk
**		Date: 10/02/2003
**			  11/23/2005 mem - Added brackets around @CurrentDB as needed to allow for DBs with dashes in the name
**							 - Added support for Peptide DBs, using similar logic as RequestGANETUpdateTaskMaster
**    
*****************************************************/
AS
	SET NOCOUNT ON

	declare @myError int,
			@myRowCount int,
			@SPExecCount int,
			@SPRowCount int,
			@MTDBCount int,
			@done int,
			@message varchar(256)

	set @myError = 0
	set @myRowCount = 0
	set @SPRowCount = 0
	set @SPExecCount = 0
	set @done = 0


	-- Note: @S needs to be unicode (nvarchar) for compatibility with sp_executesql
	declare @S nvarchar(1024),
			@CurrentDB varchar(255),	
			@SPToExec varchar(255),
			@IsPeptideDB tinyint
				
	set @CurrentDB = ''
	set @message = ''
	set @IsPeptideDB = 0
	
	---------------------------------------------------
	-- temporary table to hold results
	---------------------------------------------------
	CREATE TABLE #XMTDBRel (
		[Database_Name] varchar(128),
		[Update State] varchar(50),
		Created datetime,
		Started datetime,
		Finished datetime,
		Processor varchar(64)
	) 

 	---------------------------------------------------
	-- temporary table to hold list of databases to process
	---------------------------------------------------
	CREATE TABLE #XDBNames (
		Database_Name varchar(128),
		Processed tinyint,
		IsPeptideDB tinyint
	) 

	---------------------------------------------------
	-- populate temporary table with list of mass tag
	-- databases that are not deleted
	---------------------------------------------------
	INSERT INTO #XDBNames
	SELECT	MTL_Name, 0 As Processed, 0 As IsPeptideDB
	FROM	T_MT_Database_List
	WHERE MTL_State <> 100
	ORDER BY MTL_Name
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'could not load temporary table with candidate mass tag databases'
		goto done
	end

	---------------------------------------------------
	-- add the peptide databases that are not deleted
	---------------------------------------------------
	INSERT INTO #XDBNames
	SELECT	PDB_Name, 0 As Processed, 1 As IsPeptideDB
	FROM	T_Peptide_Database_List
	WHERE PDB_State <> 100
	ORDER BY PDB_Name
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'could not load temporary table with candidate peptide databases'
		goto done
	end
	
	---------------------------------------------------
	-- step through the database list and examine V_NET_Update_Task_Summary in each one
	---------------------------------------------------
		
	WHILE @done = 0 and @myError = 0  
	BEGIN --<a>
		-- Get next available entry from XDBNames
		--
		SELECT	TOP 1 @CurrentDB = Database_Name, @IsPeptideDB = IsPeptideDB
		FROM	#XDBNames 
		WHERE	Processed = 0
		ORDER BY Database_Name
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--		
		if @myRowCount = 0
			set @Done = 1

		If @myRowCount > 0
		begin --<b>

			-- update Process_State entry for given DB to 1
			--
			UPDATE	#XDBNames
			SET		Processed = 1
			WHERE	(Database_Name = @CurrentDB)
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--
			if @myError <> 0 
			begin
				set @message = 'Could not update the database list temp table'
				set @myError = 51
				goto Done
			end

			-- Check if the database actually exists
			SELECT @SPRowCount = Count(*) 
			FROM master..sysdatabases AS SD
			WHERE SD.NAME = @CurrentDB

			If (@SPRowCount > 0)
			Begin --<c>
				-- verify that database has appropriate infrastructure
				--
				Set @S = ''				
				Set @S = @S + ' SELECT @SPRowCount = COUNT(*)'
				Set @S = @S + ' FROM [' + @CurrentDB + ']..sysobjects'
				Set @S = @S + ' WHERE name = ''V_NET_Update_Task_Summary '''
							
				EXEC sp_executesql @S, N'@SPRowCount int OUTPUT', @SPRowCount OUTPUT

				If (@SPRowCount = 0)
				  Begin 
					Set @S = ''				
					-- update entry in results tables as having no infrastructure
					--
					INSERT INTO #XMTDBRel ([Database_Name], [Update State], Created, Started, Finished, Processor)
					Values (@CurrentDB, 'No Infrastructure', Null, Null, Null, Null)
					--
					SELECT @myError = @@error, @myRowCount = @@rowcount
					--
					if @myError <> 0 
					begin
						set @message = 'Could not update results table with default entry'
						set @myError = 51
						goto Done
					end
				  End 
				Else
				  Begin 
					-- update entry in results tables with results
					--
					set @S = N'INSERT INTO #XMTDBRel ([Database_Name], [Update State], Created, Started, Finished, Processor)'
					set @S = @S + ' SELECT TOP 1 ''' + @CurrentDB + ''' as Database_Name,'
					set @S = @S + ' Processing_State_Name, Task_Created, Task_Start,'
					set @S = @S + ' Task_Finish, Task_AssignedProcessorName'
					set @S = @S + ' FROM'
					set @S = @S + ' [' + @CurrentDB + ']..V_NET_Update_Task_Summary  ' 
					set @S = @S + ' ORDER BY Task_ID DESC '
					exec sp_executesql @S		
				  End 
			End --<c>
		end --</b>
	END -- </a>

Done:
	select * from #XMTDBRel ORDER BY [Database_Name]
	

	RETURN 


GO
GRANT EXECUTE ON [dbo].[GetGANETTaskActivity] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetGANETTaskActivity] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetGANETTaskActivity] TO [MTS_DB_Lite] AS [dbo]
GO
