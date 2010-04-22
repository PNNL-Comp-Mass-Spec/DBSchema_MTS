/****** Object:  StoredProcedure [dbo].[GetPeakMatchingTaskActivity] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.GetPeakMatchingTaskActivity
/****************************************************
** 
**		Desc: 
**		gets count of peak matching tasks in each state for each MTDB in list
**
**		Return values: 0: success, otherwise, error code
** 
** 
**		Auth: grk
**		Date: 10/02/2003
**			  11/23/2005 mem - Added brackets around @CurrentMTDB as needed to allow for DBs with dashes in the name
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
			@CurrentMTDB varchar(255),	
			@SPToExec varchar(255)
				
	set @CurrentMTDB = ''
	set @message = ''
	
	---------------------------------------------------
	-- temporary table to hold results
	---------------------------------------------------
	CREATE TABLE #XMTDBRel (
		[Mass Tag DB] varchar(64),
		New int,                                    
		Processing int,                                    
		Success int,                                            
		Failure int,                                            
		Holding int                                         
	) 

 	---------------------------------------------------
	-- temporary table to hold list of databases to process
	---------------------------------------------------
	CREATE TABLE #XMTDBNames (
		MTDB_Name varchar(128),
		Processed tinyint
	) 

	---------------------------------------------------
	-- populate temporary table with list of mass tag
	-- databases that are not deleted
	---------------------------------------------------
	INSERT INTO #XMTDBNames (MTDB_Name, Processed)
	SELECT     MTL_Name, 0
	FROM         T_MT_Database_List
	WHERE     (MTL_State in (2, 5))
	ORDER BY MTL_Name
	--
	SELECT @myError = @@error, @MTDBCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'could not load temporary table'
		goto done
	end

	---------------------------------------------------
	-- step through the mass tag database list and call
	---------------------------------------------------
		
	WHILE @done = 0 and @myError = 0  
	BEGIN
		-- Get next available entry from XMTDBNames
		--
		SELECT	TOP 1 @CurrentMTDB = MTDB_Name
		FROM	#XMTDBNames 
		WHERE	Processed = 0
		ORDER BY MTDB_Name
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--		
		if @myRowCount = 0
			Goto Done
		
		-- update Process_State entry for given MTDB to 1
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
		
		-- verify that database has appropriate infrastructure
		--
		Set @S = ''				
		Set @S = @S + ' SELECT @SPRowCount = COUNT(*)'
		Set @S = @S + ' FROM [' + @CurrentMTDB + ']..sysobjects'
		Set @S = @S + ' WHERE name = ''V_Peak_Matching_Tasks'''
					
		EXEC sp_executesql @S, N'@SPRowCount int OUTPUT', @SPRowCount OUTPUT

		If (@SPRowCount = 0)
			Begin 
		Set @S = ''				
				-- update entry in results tables as having no infrastructure
				--
				INSERT INTO #XMTDBRel ([Mass Tag DB], New, Processing, Success, Failure, Holding)
				Values (@CurrentMTDB, 0, 0, 0, 0, 0)
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
				set @S = N'INSERT INTO #XMTDBRel ([Mass Tag DB], New, Processing, Success, Failure, Holding) '
				set @S = @S + 'SELECT ''' + @CurrentMTDB + ''' as MTDBName, '
				set @S = @S + 'SUM(CASE WHEN State = ''New'' THEN 1 ELSE 0 END) AS New,  '
				set @S = @S + 'SUM(CASE WHEN State = ''Processing'' THEN 1 ELSE 0 END) AS Processing, '
				set @S = @S + 'SUM(CASE WHEN State = ''Success'' THEN 1 ELSE 0 END) AS Success, '
				set @S = @S + 'SUM(CASE WHEN State = ''Failure'' THEN 1 ELSE 0 END) AS Failure,  '
				set @S = @S + 'SUM(CASE WHEN State = ''Holding'' THEN 1 ELSE 0 END) AS Holding '
				set @S = @S + 'FROM '
				set @S = @S + '[' + @CurrentMTDB + ']..V_Peak_Matching_Tasks '

				exec sp_executesql @S		
			End 
	END

Done:
	UPDATE #XMTDBRel
	SET New=0, Processing=0, Success=0, Failure=0, Holding=0
	WHERE New Is Null AND Processing Is Null AND Success Is Null AND Failure Is Null
	
	select * from #XMTDBRel ORDER BY [Mass Tag DB]
	

	RETURN 

GO
GRANT EXECUTE ON [dbo].[GetPeakMatchingTaskActivity] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetPeakMatchingTaskActivity] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetPeakMatchingTaskActivity] TO [MTS_DB_Lite] AS [dbo]
GO
