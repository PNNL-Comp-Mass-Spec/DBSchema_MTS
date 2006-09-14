/****** Object:  StoredProcedure [dbo].[GetAnalysisJobToDBMap] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.GetAnalysisJobToDBMap
/****************************************************
**
**	Desc:	Return list of analysis jobs present in either Peptide DBs
**			or MT DBs on the various MTS servers
**        
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	08/31/2006
**    
*****************************************************/
(
	@DBType tinyint = 1,					-- If 1, then assumes a PMT tag DB (MT_) and queries V_Analysis_Job_to_MT_DB_Map
											-- If 2, then assumes a Peptide DB (PT_) and queries V_Analysis_Job_to_Peptide_DB_Map
											-- Assumes 1 if invalid DBType
	@SummaryList tinyint = 1,				-- Set to 1 to include one row for each job, showing the first and last DB the job is in; set to 0 to show all DBs that the given job is in
	@IncludeDMSInfo tinyint = 0,			-- Set to 1 to link into DMS to return information; will also have the effect of hiding job numbers not present in DMS
	@JobMinimum int = 0,					-- Minimum job number; set both @JobMinimum and @JobMaximum to 0 to return all jobs
	@JobMaximum int = 0,					-- Maximum job number
	@DBNameFilter varchar(2048) = '',		-- Filter: Comma separated list of DB Names or list of DB name match criteria containing a wildcard character (%)
											-- Examples: 'PT_BSA_A54, PT_Mouse_A66'
											--			 'PT_BSA%'
											--			 'PT_Mouse_A66, PT_BSA%'
	@ServerFilter varchar(128) = '',		-- If supplied, then only examines the databases on the given Server
	@MaximumRowCount int = 0,				-- Set to > 0 to limit the number of rows returned (will return newer jobs first)
	@message varchar(512)='' output,
	@PreviewSql tinyint = 0
)
As	
	Set nocount on
	
	Declare @myError int
	Declare @myRowCount int
	Set @myError = 0
	Set @myRowCount = 0

	---------------------------------------------------
	-- Validate or clear the input/output parameters
	---------------------------------------------------
	Set @DBType = IsNull(@DBType, 1)
	Set @SummaryList = IsNull(@SummaryList, 1)
	Set @IncludeDMSInfo = IsNull(@IncludeDMSInfo, 0)
	Set @JobMinimum = IsNull(@JobMinimum, 0)
	Set @JobMaximum = IsNull(@JobMaximum, 0)
	Set @DBNameFilter = IsNull(@DBNameFilter, '')
	Set @ServerFilter = IsNull(@ServerFilter, '')
	Set @MaximumRowCount = IsNull(@MaximumRowCount, 0)
	Set @PreviewSql = IsNull(@PreviewSql, 0)
	
	Set @message = ''

	if @DBType < 1 or @DBType > 2
		Set @DBType = 1
		
	If @JobMinimum > @JobMaximum
		Set @JobMaximum = 2000000000

	Declare @SourceView varchar(256)	
	Declare @Sql varchar(1024)
	Declare @SqlWhereClause varchar(8000)
	Declare @SqlOrderBy varchar(128)

	Set @Sql = ''
	Set @sqlWhereClause = ''
	
	Declare @result int
	Set @result = 0


	---------------------------------------------------
	-- Parse @DBNameFilter to create a proper
	-- SQL where clause containing a mix of 
	-- Where xx In ('A','B') and Where xx Like ('C%') statements
	---------------------------------------------------

	Declare @DBNameWhereClauseA varchar(4000)
	Declare @DBNameWhereClauseB varchar(4000)
	Set @DBNameWhereClauseA = ''
	Set @DBNameWhereClauseB = ''

	If @SummaryList = 0
		Exec ConvertListToWhereClause @DBNameFilter, 'J.DB_Name', @entryListWhereClause = @DBNameWhereClauseA OUTPUT
	Else
	Begin
		Exec ConvertListToWhereClause @DBNameFilter, 'J.DB_Name_First', @entryListWhereClause = @DBNameWhereClauseA OUTPUT
		Exec ConvertListToWhereClause @DBNameFilter, 'J.DB_Name_Last', @entryListWhereClause = @DBNameWhereClauseB OUTPUT
	End
		
	-----------------------------------------------------------
	-- Construct the Sql to query V_Analysis_Job_to_MT_DB_Map
	-- or V_Analysis_Job_to_MT_DB_Map_Summary
	-----------------------------------------------------------
	--
	If @SummaryList = 0
	Begin
		If @DBType = 1
			Set @SourceView = 'V_Analysis_Job_to_MT_DB_Map'
		Else
			Set @SourceView = 'V_Analysis_Job_to_Peptide_DB_Map'
	End
	Else
	Begin
		If @DBType = 1
			Set @SourceView = 'V_Analysis_Job_to_MT_DB_Map_Summary'
		Else
			Set @SourceView = 'V_Analysis_Job_to_Peptide_DB_Map_Summary'
	End

	If @MaximumRowCount = 0
	Begin
		Set @Sql = 'SELECT J.*'
		Set @SqlOrderBy = 'ORDER BY J.Job'
	End
	Else
	Begin
		Set @Sql = 'SELECT TOP ' + Convert(varchar(12), @MaximumRowCount) + ' J.*'
		Set @SqlOrderBy = 'ORDER BY J.Job Desc'
	End
	
	If @IncludeDMSInfo <> 0
	Begin
		Set @Sql = @Sql + ', D.Dataset, D.Experiment, D.DS_Created as Dataset_Created'
	End
	
	Set @Sql = @Sql + ' FROM ' + @SourceView + ' AS J'
	
	If @IncludeDMSInfo <> 0
		Set @Sql = @Sql + ' INNER JOIN MT_Main.dbo.V_DMS_Analysis_Job_Import D ON J.Job = D.Job'
		
	If Len(@DBNameWhereClauseA) > 0
	Begin
		If @SummaryList = 0
			Set @sqlWhereClause = 'WHERE (' + @DBNameWhereClauseA + ')'
		Else
			Set @sqlWhereClause = 'WHERE ((' + @DBNameWhereClauseA + ') OR (' + @DBNameWhereClauseB + '))'
	End
	
	If @JobMinimum <> 0 OR @JobMaximum <> 0
	Begin
		If Len(@sqlWhereClause) = 0
			Set @sqlWhereClause = 'WHERE'
		Else
			Set @sqlWhereClause = @sqlWhereClause + ' AND'
			
		Set @sqlWhereClause = @sqlWhereClause + ' J.Job BETWEEN ' + Convert(varchar(12), @JobMinimum) + ' AND ' + Convert(varchar(12), @JobMaximum)
	End
	
	If Len(@ServerFilter) > 0
	Begin
		If Len(@sqlWhereClause) = 0
			Set @sqlWhereClause = 'WHERE'
		Else
			Set @sqlWhereClause = @sqlWhereClause + ' AND'
			
		Set @sqlWhereClause = @sqlWhereClause + ' J.Server_Name = ''' + @ServerFilter + ''''
	End

	-----------------------------------------------------------
	-- Return the data
	-----------------------------------------------------------
	--
	If @PreviewSql <> 0
		Print @Sql + ' ' + @sqlWhereClause + ' ' + @SqlOrderBy
	Else
		Exec (@Sql + ' ' + @sqlWhereClause + ' ' + @SqlOrderBy)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 
	begin
		Set @message = 'Error returning data from ' + @SourceView
		Set @myError = 50002
		goto Done
	end
	
Done:
	-----------------------------------------------------------
	-- Exit
	-----------------------------------------------------------
	--
	if @myError <> 0
	begin
		If Len(@message) = 0
			Set @message = 'Error in GetAnalysisJobToDBMap; Error code: ' + convert(varchar(32), @myError)
		
		execute PostLogEntry 'Error', @message, 'GetAnalysisJobToDBMap'
	end

	return @myError


GO
GRANT EXECUTE ON [dbo].[GetAnalysisJobToDBMap] TO [DMS_SP_User]
GO
