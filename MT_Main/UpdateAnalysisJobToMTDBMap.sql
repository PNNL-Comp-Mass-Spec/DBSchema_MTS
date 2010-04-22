/****** Object:  StoredProcedure [dbo].[UpdateAnalysisJobToMTDBMap] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure UpdateAnalysisJobToMTDBMap
/****************************************************
** 
**	Desc: Updates T_Analysis_Job_to_MT_DB_Map
**
**	Return values: 0: success, otherwise, error code
** 
**	Parameters:
**
**	Auth:	mem
**	Date:	07/06/2005
**			11/23/2005 mem - Added brackets around @MTL_Name as needed to allow for DBs with dashes in the name
**			12/12/2005 mem - Now populating Created and Last_Affected with the date/time listed in T_Analysis_Description
**						   - Added support for PMT Tag DBs with @DBSchemaVersion < 2
**			03/10/2006 mem - Changed from T_Analysis_Description.Created to T_Analysis_Description.Created_PMT_Tag_DB
**			03/11/2006 mem - Now calling VerifyUpdateEnabled
**			09/07/2006 mem - Now populating column Process_State
**			11/28/2006 mem - Updated to return error 55000 if VerifyUpdateEnabled returns @UpdateEnabled = 0
**			11/13/2007 mem - Updated to use PMTs_Last_Affected instead of querying T_Mass_Tags to determine the most recently changed peptides for each analysis job
**						   - Added @previewSql and @infoOnly
**			03/11/2008 mem - Added parameters @DBStateMin and @DBStateMax
**    
*****************************************************/
(
	@MTDBNameFilter varchar(128) = '',			-- If supplied, then only examines the Jobs in database @MTDBNameFilter
	@infoOnly tinyint = 0,
	@previewSql tinyint = 0,
	@RowCountAdded int = 0 OUTPUT,
	@message varchar(255) = '' OUTPUT,
	@DBStateMin int = 0,						-- Ignored if @MTDBNameFilter contains a DB name
	@DBStateMax int = 9							-- Ignored if @MTDBNameFilter contains a DB name
)
As	
	set nocount on
	
	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	-- Validate or clear the input/output parameters
	Set @MTDBNameFilter = IsNull(@MTDBNameFilter, '')
	Set @infoOnly = IsNull(@infoOnly, 0)
	Set @previewSql = IsNull(@previewSql, 0)
	Set @message = ''
	Set @DBStateMin = IsNull(@DBStateMin, 0)
	Set @DBStateMax = IsNull(@DBStateMax, 9)
	
	Set @RowCountAdded = 0

	declare @result int
	Set @result = 0
	
	declare @UpdateEnabled tinyint
	declare @ProcessSingleDB tinyint
	declare @RowCountUpdated int
	declare @RowCountDeleted int
	
	If Len(@MTDBNameFilter) > 0
		Set @ProcessSingleDB = 1
	Else
		Set @ProcessSingleDB = 0

	declare @MTL_Name varchar(128)
	declare @MTL_ID int
	declare @MTL_ID_Text nvarchar(24)
	declare @UniqueRowID int

	declare @DBSchemaVersion real
	set @DBSchemaVersion = 1.0

	declare @Continue int
	declare @processCount int			-- Count of MT databases processed
	
	set @RowCountUpdated = 0
	set @RowCountDeleted = 0
	
	declare @SQL nvarchar(3500)

	-----------------------------------------------------------
	-- Process each entry in T_MT_Database_List, using the
	--  jobs in T_Analysis_Description to populate T_Analysis_Job_to_MT_DB_Map
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
		WHERE MTL_State >= @DBStateMin AND MTL_State <= @DBStateMax
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

	-- Create a temporary table to hold the job details for each database processed
	CREATE TABLE #Temp_PMTTagDB_Jobs (
		[Job] [int] NOT NULL ,
		[ResultType] varchar(32) NULL ,
		[Created] [datetime] NOT NULL ,
		[Last_Affected] [datetime] NOT NULL ,
		[Process_State] int NOT NULL
	)

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

			-- Clear #Temp_PMTTagDB_Jobs
			TRUNCATE TABLE #Temp_PMTTagDB_Jobs

			-- Lookup the Schema Version
			Exec GetDBSchemaVersionByDBName @MTL_Name, @DBSchemaVersion OUTPUT

			-- Populate #TTmpJobInfo with the job stats for this DB	
			If @DBSchemaVersion < 2
			Begin
				Set @sql = ''
				Set @sql = @sql + ' INSERT INTO #Temp_PMTTagDB_Jobs (Job, ResultType, Created, Last_Affected, Process_State)'
				Set @sql = @sql + ' SELECT TAD.Job, ''Peptide_Hit'' AS ResultType, TAD.Created,'
				Set @sql = @sql +        ' IsNull(LookupQ.Last_Affected, TAD.Created) AS Last_Affected, IsNull(State, 0) AS Process_State'
				Set @sql = @sql + ' FROM [' + @MTL_Name + '].dbo.T_Analysis_Description TAD LEFT OUTER JOIN'
				Set @sql = @sql +   ' ( SELECT TAD.Job, MAX(MT.Last_Affected) AS Last_Affected'
				Set @sql = @sql +     ' FROM [' + @MTL_Name + '].dbo.T_Mass_Tags MT INNER JOIN'
				Set @sql = @sql +          ' [' + @MTL_Name + '].dbo.T_Peptides P ON MT.Mass_Tag_ID = P.Mass_Tag_ID INNER JOIN'
				Set @sql = @sql +          ' [' + @MTL_Name + '].dbo.T_Analysis_Description TAD ON P.Analysis_ID = TAD.Job'
				Set @sql = @sql +     ' GROUP BY TAD.Job'
				Set @sql = @sql +   ' ) LookupQ ON TAD.Job = LookupQ.Job'
				Set @sql = @sql + ' WHERE TAD.Analysis_Tool LIKE ''%sequest%'' AND NOT Created IS NULL'
				Set @sql = @sql + ' UNION '
				Set @sql = @sql + ' SELECT FAD.Job, FAD.ResultType, FAD.Created,'
				Set @sql = @sql +        ' MAX(IsNull(PM.PM_Start, FAD.Created)) AS Last_Affected, IsNull(FAD.State, 0) AS Process_State'
				Set @sql = @sql + ' FROM [' + @MTL_Name + '].dbo.T_FTICR_Analysis_Description FAD LEFT OUTER JOIN'
				Set @sql = @sql +      ' [' + @MTL_Name + '].dbo.T_Peak_Matching_Task PM ON FAD.Job = PM.Job'
				Set @sql = @sql + ' WHERE FAD.Analysis_Tool NOT LIKE ''%TIC%'' AND NOT Created IS NULL'
				Set @sql = @sql + ' GROUP BY FAD.Job, FAD.ResultType, FAD.Created, FAD.State'
			End
			Else
			Begin
				Set @sql = ''
				Set @sql = @sql + ' INSERT INTO #Temp_PMTTagDB_Jobs (Job, ResultType, Created, Last_Affected, Process_State)'
				Set @sql = @sql + ' SELECT TAD.Job, TAD.ResultType, TAD.Created_PMT_Tag_DB AS Created, '
				Set @sql = @sql +        ' IsNull(TAD.PMTs_Last_Affected, TAD.Created_PMT_Tag_DB) AS Last_Affected,'
				Set @sql = @sql +        ' IsNull(TAD.State, 0) AS Process_State'
				Set @sql = @sql + ' FROM [' + @MTL_Name + '].dbo.T_Analysis_Description TAD'
				Set @sql = @sql + ' UNION '
				Set @sql = @sql + ' SELECT FAD.Job, FAD.ResultType, FAD.Created,'
				Set @sql = @sql +        ' MAX(IsNull(PM.PM_Start, FAD.Created)) AS Last_Affected,'
				Set @sql = @sql +        ' IsNull(FAD.State, 0) AS Process_State'
				Set @sql = @sql + ' FROM [' + @MTL_Name + '].dbo.T_FTICR_Analysis_Description FAD LEFT OUTER JOIN'
				Set @sql = @sql +      ' [' + @MTL_Name + '].dbo.T_Peak_Matching_Task PM ON FAD.Job = PM.Job'
				Set @sql = @sql + ' GROUP BY FAD.Job, FAD.ResultType, FAD.Created, FAD.State'
			End
			--
			If @previewSql <> 0
				Print @sql
			Else
				EXEC @result = sp_executesql @sql
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			
			If @result <> 0 OR @myError <> 0
			 Begin
				Set @message = 'Error looking up job info in ' + @MTL_Name
				execute PostLogEntry 'Error', @message, 'UpdateAnalysisJobToMTDBMap'
				set @message = ''
			 End
			Else
			 Begin -- <C>
			 
				If @infoOnly <> 0 And @previewSql = 0
					SELECT ResultType,
					       Process_State,
					       COUNT(*) AS Job_Count,
					       MIN(Created) AS Created_Min,
					       MAX(Created) AS Created_Max,
					       MIN(Last_Affected) AS Last_Affected_Min,
					       MAX(Last_Affected) AS Last_Affected_Max
					FROM #Temp_PMTTagDB_Jobs
					GROUP BY ResultType, Process_State
					ORDER BY ResultType, Process_State
					
				Set @MTL_ID_Text = Convert(nvarchar(24), @MTL_ID)
				
				-- Find jobs in #Temp_PMTTagDB_Jobs that are in AJMDM, but do not have the correct MTL_ID
				-- If any jobs match, delete them
				--
				Set @sql = ''
				If @infoOnly <> 0 And @previewSql = 0
					Set @sql = @sql + ' SELECT AJMDM.Job AS Job_to_Delete'
				Else
					Set @sql = @sql + ' DELETE AJMDM'

				Set @sql = @sql + ' FROM T_Analysis_Job_to_MT_DB_Map AS AJMDM LEFT OUTER JOIN'
				Set @sql = @sql +      ' #Temp_PMTTagDB_Jobs AS MTDB ON'
				Set @sql = @sql +      ' AJMDM.Job = MTDB.Job AND AJMDM.MTL_ID = ' + @MTL_ID_Text
				Set @sql = @sql + ' WHERE AJMDM.MTL_ID = ' + @MTL_ID_Text + ' AND MTDB.Job IS NULL'
				
				If @previewSql <> 0
					Print @sql
				Else
					EXEC @result = sp_executesql @sql
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				Set @RowCountDeleted = @RowCountDeleted + @myRowCount

				-- Insert missing jobs from #Temp_PMTTagDB_Jobs into AJMDM
				--
				Set @sql = ''
				If @infoOnly <> 0 And @previewSql = 0
					Set @sql = @sql
				Else
					Set @sql = @sql + ' INSERT INTO T_Analysis_Job_to_MT_DB_Map (Job, MTL_ID, ResultType, Created, Last_Affected, Process_State)'

				Set @sql = @sql + ' SELECT MTDB.Job AS Job_to_Add, ' + @MTL_ID_Text + ' AS MTL_ID, MTDB.ResultType, MTDB.Created, MTDB.Last_Affected, IsNull(MTDB.Process_State, 0) AS Process_State'
				Set @sql = @sql + ' FROM #Temp_PMTTagDB_Jobs AS MTDB LEFT OUTER JOIN'
				Set @sql = @sql +      ' T_Analysis_Job_to_MT_DB_Map AS AJMDM ON'
				Set @sql = @sql +      ' MTDB.Job = AJMDM.Job AND AJMDM.MTL_ID = ' + @MTL_ID_Text
				Set @sql = @sql + ' WHERE AJMDM.Job IS NULL'

				If @previewSql <> 0
					Print @sql
				Else
					EXEC @result = sp_executesql @sql
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				Set @RowCountAdded = @RowCountAdded + @myRowCount

				-- Update jobs in #Temp_PMTTagDB_Jobs with differing Created or Last_Affected times
				--
				Set @sql = ''
				If @infoOnly <> 0 And @previewSql = 0
					Set @sql = @sql + ' SELECT MTDB.Job AS Job_to_Update, MTDB.Created, MTDB.Last_Affected, IsNull(MTDB.Process_State, 0) AS Process_State'
				Else
				Begin
					Set @sql = @sql + ' UPDATE T_Analysis_Job_to_MT_DB_Map'
					Set @sql = @sql + ' SET Created = MTDB.Created,'
					Set @sql = @sql +     ' Last_Affected = MTDB.Last_Affected,'
					Set @sql = @sql +     ' Process_State = IsNull(MTDB.Process_State, 0)'
				End
				
				Set @sql = @sql + ' FROM #Temp_PMTTagDB_Jobs AS MTDB INNER JOIN'
				Set @sql = @sql +      ' T_Analysis_Job_to_MT_DB_Map AS AJMDM ON'
				Set @sql = @sql +      ' MTDB.Job = AJMDM.Job AND AJMDM.MTL_ID = ' + @MTL_ID_Text
				Set @sql = @sql + ' WHERE AJMDM.Created <> MTDB.Created OR '
				Set @sql = @sql +       ' AJMDM.Last_Affected <> MTDB.Last_Affected OR '
				Set @sql = @sql +       ' AJMDM.Process_State <> MTDB.Process_State'

				If @previewSql <> 0
					Print @sql
				Else
					EXEC @result = sp_executesql @sql
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				Set @RowCountUpdated = @RowCountUpdated + @myRowCount
				
				Set @processCount = @processCount + 1
			 End -- </C>
		End -- </B>

		If @previewSql = 0
		Begin
			-- Validate that updating is enabled, abort if not enabled
			exec VerifyUpdateEnabled 'PMT_Tag_DB_Update', 'UpdateAnalysisJobToMTDBMap', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
			If @UpdateEnabled = 0
			Begin
				-- Note: The calling procedure recognizes error 55000 as "Update Aborted"
				Set @myError = 55000
				Goto Done
			End
		End

	End -- </A>

	If @RowCountAdded <> 0 Or @RowCountUpdated <> 0 Or @RowCountDeleted <> 0
	Begin
		Set @message = ''
		Set @message = @message + 'Rows added: ' + Convert(varchar(9), @RowCountAdded) + '; '
		Set @message = @message + 'Rows updated: ' + Convert(varchar(9), @RowCountUpdated) + '; '
		Set @message = @message + 'Rows deleted: ' + Convert(varchar(9), @RowCountDeleted)
	End
	Else
		Set @message = 'No changes were made to T_Analysis_Job_to_MT_DB_Map'
	
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
GRANT VIEW DEFINITION ON [dbo].[UpdateAnalysisJobToMTDBMap] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[UpdateAnalysisJobToMTDBMap] TO [MTS_DB_Lite] AS [dbo]
GO
