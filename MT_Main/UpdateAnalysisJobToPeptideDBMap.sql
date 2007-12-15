/****** Object:  StoredProcedure [dbo].[UpdateAnalysisJobToPeptideDBMap] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure UpdateAnalysisJobToPeptideDBMap
/****************************************************
** 
**	Desc: Updates T_Analysis_Job_to_Peptide_DB_Map
**
**	Return values: 0: success, otherwise, error code
** 
**	Parameters:
**
**	Auth:	mem
**	Date:	10/23/2004
**			07/06/2005 mem - Updated to track all Peptide DBs that each job is present in
**			11/23/2005 mem - Added brackets around @PDB_Name as needed to allow for DBs with dashes in the name
**			12/12/2005 mem - Now populating Created and Last_Affected with the date/time listed in T_Analysis_Description
**						   - Added support for Peptide DBs with @DBSchemaVersion < 2
**			03/11/2006 mem - Now calling VerifyUpdateEnabled
**			09/07/2006 mem - Now populating column Process_State
**			11/28/2006 mem - Updated to return error 55000 if VerifyUpdateEnabled returns @UpdateEnabled = 0
**			11/13/2007 mem - Added @previewSql and @infoOnly
**    
*****************************************************/
(
	@PeptideDBNameFilter varchar(128) = '',				-- If supplied, then only examines the Jobs in database @PeptideDBNameFilter
	@infoOnly tinyint = 0,
	@previewSql tinyint = 0,
	@RowCountAdded int = 0 OUTPUT,
	@message varchar(255) = '' OUTPUT
)
As	
	set nocount on
	
	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	-- Validate or clear the input/output parameters
	Set @PeptideDBNameFilter = IsNull(@PeptideDBNameFilter, '')
	Set @infoOnly = IsNull(@infoOnly, 0)
	Set @previewSql = IsNull(@previewSql, 0)
	Set @message = ''
	Set @RowCountAdded = 0

	declare @result int
	Set @result = 0
	
	declare @UpdateEnabled tinyint
	declare @ProcessSingleDB tinyint
	declare @RowCountUpdated int
	declare @RowCountDeleted int
	
	If Len(@PeptideDBNameFilter) > 0
		Set @ProcessSingleDB = 1
	Else
		Set @ProcessSingleDB = 0

	declare @PDB_Name varchar(128)
	declare @PDB_ID int
	declare @PDB_ID_Text nvarchar(24)
	declare @UniqueRowID int

	declare @DBSchemaVersion real
	set @DBSchemaVersion = 1.0

	declare @Continue int
	declare @processCount int			-- Count of peptide databases processed

	set @RowCountUpdated = 0
	set @RowCountDeleted = 0

	declare @SQL nvarchar(3500)

	-----------------------------------------------------------
	-- Process each entry in T_Peptide_Database_List, using the
	--  jobs in T_Analysis_Description to populate T_Analysis_Job_to_Peptide_DB_Map
	--
	-- Alternatively, if @PeptideDBNameFilter is supplied, then only process it
	-----------------------------------------------------------
	
	CREATE TABLE #Temp_PDB_List (
		[PDB_ID] int NOT Null,
		[PDB_Name] varchar(128) NOT Null,
		[UniqueRowID] [int] IDENTITY
	)

	If @ProcessSingleDB = 0
	Begin
		INSERT INTO #Temp_PDB_List (PDB_ID, PDB_Name)
		SELECT PDB_ID, PDB_Name
		FROM T_Peptide_Database_List
		WHERE PDB_State < 10
		ORDER BY PDB_Name
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0 
		begin
			set @message = 'Error populating #Temp_PDB_List temporary table'
			set @myError = 50001
			goto Done
		end
	End
	Else
	Begin
		INSERT INTO #Temp_PDB_List (PDB_ID, PDB_Name)
		SELECT PDB_ID, PDB_Name
		FROM T_Peptide_Database_List
		WHERE PDB_Name = @PeptideDBNameFilter
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @myRowCount = 0
		Begin
			-- Invalid @PeptideDBNameFilter supplied
			Set @message = 'Peptide DB Name supplied is not present in T_Peptide_Database_List: ' + @PeptideDBNameFilter
			Set @myError = 50002
			Goto Done
		End
	End

	-- Create a temporary table to hold the job details for each database processed
	CREATE TABLE #Temp_PTDB_Jobs (
		[Job] [int] NOT NULL ,
		[ResultType] varchar(32) NULL ,
		[Created] [datetime] NOT NULL ,
		[Last_Affected] [datetime] NOT NULL ,
		[Process_State] int NOT NULL
	)

	-----------------------------------------------------------
	-- Process each entry in #Temp_PDB_List
	-----------------------------------------------------------
	--
	set @processCount = 0
	set @UniqueRowID = -1
	set @Continue = 1
	--	
	While @Continue > 0 and @myError = 0
	Begin -- <A>

		SELECT TOP 1
			@PDB_ID = PDB_ID,
			@PDB_Name = PDB_Name,
			@UniqueRowID = UniqueRowID
		FROM  #Temp_PDB_List
		WHERE UniqueRowID > @UniqueRowID
		ORDER BY UniqueRowID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0 
		begin
			set @message = 'Could not get next entry from peptide DB temporary table'
			set @myError = 50003
			goto Done
		end
		Set @continue = @myRowCount

		If @continue > 0
		Begin -- <B>

			-- Clear #Temp_PTDB_Jobs
			TRUNCATE TABLE #Temp_PTDB_Jobs

			-- Lookup the Schema Version
			Exec GetDBSchemaVersionByDBName @PDB_Name, @DBSchemaVersion OUTPUT
			
			-- Populate #TTmpJobInfo with the job stats for this DB	
			If @DBSchemaVersion < 2
			Begin
				Set @sql = ''
				Set @sql = @sql + ' INSERT INTO #Temp_PTDB_Jobs (Job, ResultType, Created, Last_Affected, Process_State)'
				Set @sql = @sql + ' SELECT Job, ''Peptide_Hit'' AS ResultType, Created, Created AS Last_Affected, IsNull(State, 0) AS Process_State'
				Set @sql = @sql + ' FROM [' + @PDB_Name + '].dbo.T_Analysis_Description'
				Set @sql = @sql + ' WHERE Analysis_Tool LIKE ''%sequest%'' AND NOT Created IS NULL'
			End
			Else
			Begin
				Set @sql = ''
				Set @sql = @sql + ' INSERT INTO #Temp_PTDB_Jobs (Job, ResultType, Created, Last_Affected, Process_State)'
				Set @sql = @sql + ' SELECT Job, ResultType, Created, IsNull(Last_Affected, Created), IsNull(Process_State, 0) AS Process_State'
				Set @sql = @sql + ' FROM [' + @PDB_Name + '].dbo.T_Analysis_Description'
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
				Set @message = 'Error looking up job info in ' + @PDB_Name
				execute PostLogEntry 'Error', @message, 'UpdateAnalysisJobToPeptideDBMap'
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
					FROM #Temp_PTDB_Jobs
					GROUP BY ResultType, Process_State
					ORDER BY ResultType, Process_State

				Set @PDB_ID_Text = Convert(nvarchar(24), @PDB_ID)
				
				-- Find jobs in #Temp_PTDB_Jobs that are in AJPDM, but do not have the correct PDB_ID
				-- If any jobs match, delete them
				--
				Set @sql = ''
				If @infoOnly <> 0 And @previewSql = 0
					Set @sql = @sql + ' SELECT AJPDM.Job AS Job_to_Delete'
				Else
					Set @sql = @sql + ' DELETE AJPDM'
					
				Set @sql = @sql + ' FROM T_Analysis_Job_to_Peptide_DB_Map AS AJPDM LEFT OUTER JOIN'
				Set @sql = @sql +      ' #Temp_PTDB_Jobs AS PTDB ON '
				Set @sql = @sql +      ' AJPDM.Job = PTDB.Job AND AJPDM.PDB_ID = ' + @PDB_ID_Text
				Set @sql = @sql + ' WHERE AJPDM.PDB_ID = ' + @PDB_ID_Text + ' AND PTDB.Job IS NULL'
				
				If @previewSql <> 0
					Print @sql
				Else
					EXEC @result = sp_executesql @sql
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				Set @RowCountDeleted = @RowCountDeleted + @myRowCount

				-- Insert missing jobs from #Temp_PTDB_Jobs into AJPDM
				--
				Set @sql = ''
				If @infoOnly <> 0 And @previewSql = 0
					Set @sql = @sql
				Else
					Set @sql = @sql + ' INSERT INTO T_Analysis_Job_to_Peptide_DB_Map (Job, PDB_ID, ResultType, Created, Last_Affected, Process_State)'
					
				Set @sql = @sql + ' SELECT PTDB.Job AS Job_to_Add, ' + @PDB_ID_Text + ' AS PDB_ID, PTDB.ResultType, PTDB.Created, PTDB.Last_Affected, IsNull(PTDB.Process_State, 0) AS Process_State'
				Set @sql = @sql + ' FROM #Temp_PTDB_Jobs AS PTDB LEFT OUTER JOIN'
				Set @sql = @sql +      ' T_Analysis_Job_to_Peptide_DB_Map AS AJPDM ON'
				Set @sql = @sql +      ' PTDB.Job = AJPDM.Job AND AJPDM.PDB_ID = ' + @PDB_ID_Text
				Set @sql = @sql + ' WHERE AJPDM.Job IS NULL'

				If @previewSql <> 0
					Print @sql
				Else
					EXEC @result = sp_executesql @sql
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				Set @RowCountAdded = @RowCountAdded + @myRowCount

				-- Update jobs in #Temp_PTDB_Jobs with differing Created, Last_Affected, or Process_State times
				--
				Set @sql = ''
				If @infoOnly <> 0 And @previewSql = 0
					Set @sql = @sql + ' SELECT PTDB.Job AS Job_to_Update, PTDB.Created, PTDB.Last_Affected, IsNull(PTDB.Process_State, 0) AS Process_State'
				Else
				Begin
					Set @sql = @sql + ' UPDATE T_Analysis_Job_to_Peptide_DB_Map'
					Set @sql = @sql + ' SET Created = PTDB.Created, '
					Set @sql = @sql +     ' Last_Affected = PTDB.Last_Affected,'
					Set @sql = @sql +     ' Process_State = IsNull(PTDB.Process_State, 0)'
				End
				
				Set @sql = @sql + ' FROM #Temp_PTDB_Jobs AS PTDB INNER JOIN'
				Set @sql = @sql +      ' T_Analysis_Job_to_Peptide_DB_Map AS AJPDM ON'
				Set @sql = @sql +      ' PTDB.Job = AJPDM.Job AND AJPDM.PDB_ID = ' + @PDB_ID_Text
				Set @sql = @sql + ' WHERE AJPDM.Created <> PTDB.Created OR '
				Set @sql = @sql +       ' AJPDM.Last_Affected <> PTDB.Last_Affected OR '
				Set @sql = @sql +       ' AJPDM.Process_State <> PTDB.Process_State'
				
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
			exec VerifyUpdateEnabled 'Peptide_DB_Update', 'UpdateAnalysisJobToPeptideDBMap', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
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
		Set @message = 'No changes were made to T_Analysis_Job_to_Peptide_DB_Map'
	
Done:
	-----------------------------------------------------------
	-- Exit
	-----------------------------------------------------------
	--
	if @myError <> 0
	begin
		If Len(@message) = 0
			set @message = 'Error updating Job to Peptide DB mapping: ' + convert(varchar(32), @myError) + ' occurred'
	end

	return @myError


GO
