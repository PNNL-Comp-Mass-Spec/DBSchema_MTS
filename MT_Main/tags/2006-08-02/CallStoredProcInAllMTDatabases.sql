SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[CallStoredProcInAllMTDatabases]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[CallStoredProcInAllMTDatabases]
GO

CREATE PROCEDURE dbo.CallStoredProcInAllMTDatabases
/****************************************************
**
**	Desc: 
**		For each database listed in T_MT_Database_List
**      Calls the Stored Procedure specified by
**      @StoredProcNameToCall
**
**		Auth: mem
**		Date: 06/21/2003
**			  06/23/2003 mem - added check to assure @StoredProcNameToCall exists
**			                   added CheckForExistenceOnly option
**			  11/23/2005 mem - Added brackets around @CurrentMTDB as needed to allow for DBs with dashes in the name
**
*****************************************************/
	@StoredProcNameToCall varchar(128)='RefreshAnalysesDescriptionStorage',
	@CheckForExistenceOnly tinyint=0,										-- If 1, then only checks if SP exists; does not Execute it
	@message varchar(512)='' Output
AS
	set nocount on

	declare @myError int,
			@myRowCount int,
			@SPExecCount int,
			@SPRowCount int,
			@MTDBCount int,
			@done int

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
	set @SPToExec = ''
	set @message = ''
	
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
	INSERT INTO #XMTDBNames
	SELECT	MTL_Name, 0
	FROM	T_MT_Database_List
	WHERE MTL_State <> 100
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
	-- @StoredProcNameToCall in each one
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

		-- Pause 1 second in an attempt to avoid Error Msg 924
		-- (Database 'MT_XXX' is already open and can only have one user at a time)
--		WaitFor DELAY '00:00:01'
		
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

		-- Check if @SPToExec exists for @CurrentMTDB

		Set @S = ''				
		Set @S = @S + ' SELECT @SPRowCount = COUNT(*)'
		Set @S = @S + ' FROM [' + @CurrentMTDB + ']..sysobjects'
		Set @S = @S + ' WHERE id = OBJECT_ID(N''[' + @CurrentMTDB + ']..[' + @StoredProcNameToCall + ']'')  '
							
		EXEC sp_executesql @S, N'@SPRowCount int OUTPUT', @SPRowCount OUTPUT

		If (@SPRowCount = 0)
			Select @StoredProcNameToCall + ' not found in ' + @CurrentMTDB
		Else
			Begin
				
				if @CheckForExistenceOnly = 1
					Select @StoredProcNameToCall + ' was found in ' + @CurrentMTDB
				else
					begin
						-- Call RequestPeakMatchingTask in @CurrentMTDB
						Set @SPToExec = '[' + @CurrentMTDB + ']..' + @StoredProcNameToCall
							
						Select @SPToExec
		
						Exec @myError = @SPToExec
					end

				Set @SPExecCount = @SPExecCount + 1
			End		
	END
	
	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	-- Update @message if it is currently blank
	If Len(@message) = 0
	Begin
		If @CheckForExistenceOnly = 1
			Set @message = 'SP ' + @StoredProcNameToCall + ' found in ' + convert(varchar(9), @SPExecCount) + ' of the ' + convert(varchar(9), @MTDBCount) + ' MTDBs'
		Else
			Begin
				if @SPExecCount = @MTDBCount
					Set @message = 'Called SP ' + @StoredProcNameToCall + ' in all ' + convert(varchar(9), @MTDBCount) + ' MTDBs'
				else
					Set @message = 'Error: called SP ' + @StoredProcNameToCall + ' in only ' + convert(varchar(9), @SPExecCount) + ' of the ' + convert(varchar(9), @MTDBCount) + ' MTDBs'
			End
	End
		
	Select @message

	Return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[CallStoredProcInAllMTDatabases]  TO [DMS_SP_User]
GO

