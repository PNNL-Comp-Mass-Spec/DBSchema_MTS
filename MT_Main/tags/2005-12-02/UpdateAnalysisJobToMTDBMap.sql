SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[UpdateAnalysisJobToMTDBMap]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[UpdateAnalysisJobToMTDBMap]
GO

CREATE Procedure UpdateAnalysisJobToMTDBMap
/****************************************************
** 
**		Desc: Updates T_Analysis_Job_to_MT_DB_Map
**
**		Return values: 0: success, otherwise, error code
** 
**		Parameters:
**
**		Auth:	mem
**		Date:	07/6/2005
**				11/23/2005 mem - Added brackets around @MTL_Name as needed to allow for DBs with dashes in the name
**    
*****************************************************/
	@MTDBNameFilter varchar(128) = '',				-- If supplied, then only examines the Jobs in database @MTDBNameFilter
	@RowCountAdded int = 0 OUTPUT,
	@message varchar(255) = '' OUTPUT
As	
	set nocount on
	
	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	-- Validate or clear the input/output parameters
	Set @MTDBNameFilter = IsNull(@MTDBNameFilter, '')
	Set @message = ''
	Set @RowCountAdded = 0

	declare @result int
	declare @ProcessSingleDB tinyint
	declare @RowsDeleted int
	declare @RowsAdded int
	
	If Len(@MTDBNameFilter) > 0
		Set @ProcessSingleDB = 1
	Else
		Set @ProcessSingleDB = 0

	declare @MTL_Name varchar(128)
	declare @MTL_ID int
	declare @MTL_ID_Text nvarchar(11)
	declare @UniqueRowID int

	declare @DBSchemaVersion real
	set @DBSchemaVersion = 1.0

	declare @Continue int
	declare @processCount int			-- Count of MT databases processed
	declare @RowCountStart int
	declare @RowCountEnd int

	Set @RowCountStart = 0
	SELECT @RowCountStart = COUNT(*)
	FROM T_Analysis_Job_to_MT_DB_Map
	
	set @RowsDeleted = 0
	set @RowsAdded = 0
	
	declare @SQL nvarchar(1024)

	-----------------------------------------------------------
	-- Process each entry in T_MT_Database_List, using the
	--  jobs in T_Analysis_Description to populate T_Analysis_Job_to_MT_DB_Map
	-- Only use MT DB's with schema version 2 or higher
	--
	-- Alternatively, if @MTDBNameFilter is supplied, then only process it
	-----------------------------------------------------------
	
	CREATE TABLE #Temp_MTL_List (
		[MTL_ID] int NOT Null,
		[MTL_Name] varchar(128) NOT Null,
		[UniqueRowID] [int] IDENTITY
	)

	If @ProcessSingleDB = 0
	Begin
		INSERT INTO #Temp_MTL_List (MTL_ID, MTL_Name)
		SELECT MTL_ID, MTL_Name
		FROM T_MT_Database_List
		WHERE MTL_State < 10
		ORDER BY MTL_Name
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0 
		begin
			set @message = 'Error populating #Temp_MTL_List temporary table'
			set @myError = 50001
			goto Done
		end
	End
	Else
	Begin
		INSERT INTO #Temp_MTL_List (MTL_ID, MTL_Name)
		SELECT MTL_ID, MTL_Name
		FROM T_MT_Database_List
		WHERE MTL_Name = @MTDBNameFilter
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @myRowCount = 0
		Begin
			-- Invalid @MTDBNameFilter supplied
			Set @message = 'MT DB Name supplied is not present in T_MT_Database_List: ' + @MTDBNameFilter
			Set @myError = 50002
			Goto Done
		End
	End

	-----------------------------------------------------------
	-- Process each entry in #Temp_MTL_List
	-----------------------------------------------------------
	--
	set @processCount = 0
	set @UniqueRowID = -1
	set @Continue = 1
	--	
	While @Continue > 0 and @myError = 0
	Begin -- <A>

		SELECT TOP 1
			@MTL_ID = MTL_ID,
			@MTL_Name = MTL_Name,
			@UniqueRowID = UniqueRowID
		FROM  #Temp_MTL_List
		WHERE UniqueRowID > @UniqueRowID
		ORDER BY UniqueRowID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0 
		begin
			set @message = 'Could not get next entry from MT DB temporary table'
			set @myError = 50003
			goto Done
		end
		Set @continue = @myRowCount

		If @continue > 0
		Begin -- <B>

			Exec GetDBSchemaVersionByDBName @MTL_Name, @DBSchemaVersion OUTPUT
			
			If @DBSchemaVersion >= 2
			Begin
				Set @MTL_ID_Text = Convert(nvarchar(11), @MTL_ID)
				
				-- Find jobs in @MTL_Name that are in AJMDM, but do not have the correct MTL_ID
				-- If any jobs match, delete them
				--
				Set @sql = ''
				Set @sql = @sql + ' DELETE AJMDM'
				Set @sql = @sql + ' FROM T_Analysis_Job_to_MT_DB_Map AS AJMDM LEFT OUTER JOIN'
				Set @sql = @sql +   ' (SELECT Job FROM [' + @MTL_Name + '].dbo.T_Analysis_Description UNION'
				Set @sql = @sql +   '  SELECT Job FROM [' + @MTL_Name + '].dbo.T_FTICR_Analysis_Description) AS MTDB'
				Set @sql = @sql +   ' ON AJMDM.Job = MTDB.Job AND AJMDM.MTL_ID = ' + @MTL_ID_Text
				Set @sql = @sql + ' WHERE AJMDM.MTL_ID = ' + @MTL_ID_Text + ' AND MTDB.Job IS NULL'

				EXEC @result = sp_executesql @sql
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				Set @RowsDeleted = @RowsDeleted + @myRowCount

				-- Insert missing jobs from @MTL_Name into AJMDM
				--
				Set @sql = ''
				Set @sql = @sql + ' INSERT INTO T_Analysis_Job_to_MT_DB_Map (Job, MTL_ID, ResultType, Last_Affected)'
				Set @sql = @sql + ' SELECT MTDB.Job, ' + @MTL_ID_Text + ' AS MTL_ID, MTDB.ResultType, GetDate()'
				Set @sql = @sql +   ' FROM (SELECT Job, ResultType FROM [' + @MTL_Name + '].dbo.T_Analysis_Description UNION'
				Set @sql = @sql +        '  SELECT Job, ResultType FROM [' + @MTL_Name + '].dbo.T_FTICR_Analysis_Description) AS MTDB'
				Set @sql = @sql +   ' LEFT OUTER JOIN T_Analysis_Job_to_MT_DB_Map AS AJMDM ON'
				Set @sql = @sql +   ' MTDB.Job = AJMDM.Job AND AJMDM.MTL_ID = ' + @MTL_ID_Text
				Set @sql = @sql + ' WHERE AJMDM.Job IS NULL'

				EXEC @result = sp_executesql @sql
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				Set @RowsAdded = @RowsAdded + @myRowCount

				Set @processCount = @processCount + 1

			End
			
		End -- </B>
	End -- </A>

	Set @RowCountEnd = 0
	SELECT @RowCountEnd = COUNT(*)
	FROM T_Analysis_Job_to_MT_DB_Map
	--
	Set @RowCountAdded = @RowCountEnd - @RowCountStart

	Set @message = 'Total rows added: ' + Convert(varchar(9), @RowCountAdded)
	
	If @RowsDeleted <> 0 Or @RowsAdded <> 0
		Set @message = @message + ' (deleted ' + Convert(varchar(9), @RowsDeleted) + ' and added ' + Convert(varchar(9), @RowsAdded) + ')'
	Else
		Set @message = @message + ' (No changes were made to T_Analysis_Job_to_MT_DB_Map)'
		
Done:
	-----------------------------------------------------------
	-- Exit
	-----------------------------------------------------------
	--
	if @myError <> 0
	begin
		If Len(@message) = 0
			set @message = 'Error updating Job to MT DB mapping: ' + convert(varchar(32), @myError) + ' occurred'
	end

	return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

