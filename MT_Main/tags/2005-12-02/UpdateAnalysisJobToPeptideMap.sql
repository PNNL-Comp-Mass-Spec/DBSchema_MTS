SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[UpdateAnalysisJobToPeptideMap]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[UpdateAnalysisJobToPeptideMap]
GO

CREATE Procedure UpdateAnalysisJobToPeptideMap
/****************************************************
** 
**		Desc: Updates T_Analysis_Job_to_Peptide_Map
**
**		Return values: 0: success, otherwise, error code
** 
**		Parameters:
**
**		Auth:	mem
**		Date:	10/23/2004
**				07/06/2005 mem - Updated to track all Peptide DBs that each job is present in
**				11/23/2005 mem - Added brackets around @PDB_Name as needed to allow for DBs with dashes in the name
**    
*****************************************************/
	@PeptideDBNameFilter varchar(128) = '',				-- If supplied, then only examines the Jobs in database @PeptideDBNameFilter
	@RowCountAdded int = 0 OUTPUT,
	@message varchar(255) = '' OUTPUT
As	
	set nocount on
	
	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	-- Validate or clear the input/output parameters
	Set @PeptideDBNameFilter = IsNull(@PeptideDBNameFilter, '')
	Set @message = ''
	Set @RowCountAdded = 0

	declare @result int
	declare @ProcessSingleDB tinyint
	declare @RowsDeleted int
	declare @RowsAdded int
	
	If Len(@PeptideDBNameFilter) > 0
		Set @ProcessSingleDB = 1
	Else
		Set @ProcessSingleDB = 0

	declare @PDB_Name varchar(128)
	declare @PDB_ID int
	declare @PDB_ID_Text nvarchar(11)
	declare @UniqueRowID int

	declare @DBSchemaVersion real
	set @DBSchemaVersion = 1.0

	declare @Continue int
	declare @processCount int			-- Count of peptide databases processed
	declare @RowCountStart int
	declare @RowCountEnd int

	Set @RowCountStart = 0
	SELECT @RowCountStart = COUNT(*)
	FROM T_Analysis_Job_to_Peptide_DB_Map
	
	set @RowsDeleted = 0
	set @RowsAdded = 0

	declare @SQL nvarchar(1024)

	-----------------------------------------------------------
	-- Process each entry in T_Peptide_Database_List, using the
	--  jobs in T_Analysis_Description to populate T_Analysis_Job_to_Peptide_DB_Map
	-- Only use peptide DB's with schema version 2 or higher
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

			Exec GetDBSchemaVersionByDBName @PDB_Name, @DBSchemaVersion OUTPUT
			
			If @DBSchemaVersion >= 2
			Begin
				Set @PDB_ID_Text = Convert(nvarchar(11), @PDB_ID)
				
				-- Find jobs in @PDB_Name that are in AJPDM, but do not have the correct PDB_ID
				-- If any jobs match, delete them
				--
				Set @sql = ''
				Set @sql = @sql + ' DELETE AJPDM'
				Set @sql = @sql + ' FROM T_Analysis_Job_to_Peptide_DB_Map AS AJPDM LEFT OUTER JOIN'
				Set @sql = @sql + ' [' + @PDB_Name + '].dbo.T_Analysis_Description AS PTDB ON '
				Set @sql = @sql +   ' AJPDM.Job = PTDB.Job AND AJPDM.PDB_ID = ' + @PDB_ID_Text
				Set @sql = @sql + ' WHERE AJPDM.PDB_ID = ' + @PDB_ID_Text + ' AND PTDB.Job IS NULL'
				
				EXEC @result = sp_executesql @sql
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				Set @RowsDeleted = @RowsDeleted + @myRowCount

				-- Insert missing jobs from @PDB_Name into AJPDM
				--
				Set @sql = ''
				Set @sql = @sql + ' INSERT INTO T_Analysis_Job_to_Peptide_DB_Map (Job, PDB_ID, ResultType, Last_Affected)'
				Set @sql = @sql + ' SELECT PTDB.Job, ' + @PDB_ID_Text + ' AS PDB_ID, PTDB.ResultType, GetDate()'
				Set @sql = @sql + ' FROM [' + @PDB_Name + '].dbo.T_Analysis_Description AS PTDB LEFT OUTER JOIN'
				Set @sql = @sql +   ' T_Analysis_Job_to_Peptide_DB_Map AS AJPDM ON'
				Set @sql = @sql +   ' PTDB.Job = AJPDM.Job AND AJPDM.PDB_ID = ' + @PDB_ID_Text
				Set @sql = @sql + ' WHERE AJPDM.Job IS NULL'

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
	FROM T_Analysis_Job_to_Peptide_DB_Map
	--
	Set @RowCountAdded = @RowCountEnd - @RowCountStart

	Set @message = 'Total rows added: ' + Convert(varchar(9), @RowCountAdded)
	
	If @RowsDeleted <> 0 Or @RowsAdded <> 0
		Set @message = @message + ' (deleted ' + Convert(varchar(9), @RowsDeleted) + ' and added ' + Convert(varchar(9), @RowsAdded) + ')'
	Else
		Set @message = @message + ' (No changes were made to T_Analysis_Job_to_Peptide_DB_Map)'
	
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
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

