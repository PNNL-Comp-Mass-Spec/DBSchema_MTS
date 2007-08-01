/****** Object:  StoredProcedure [dbo].[QCMSMSJobsTablePopulateOld] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.QCMSMSJobsTablePopulateOld
/****************************************************
**
**	Desc: 
**	Populates a temporary table with the jobs matching the given job filters in the specified database
**	The calling procedure must have already created the temporary table (#TmpQCJobList)
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**	  @DBName				-- Peptide or PMT Tag database name
**	  @message				-- Status/error message output
**
**		Auth:	mem
**		Date:	08/26/2005
**				11/10/2005 mem - Updated to preferably use Acq_Time_Start rather than Created_DMS for dataset date filtering
**			    11/23/2005 mem - Added brackets around @DBName as needed to allow for DBs with dashes in the name
**
*****************************************************/
(
	@DBName varchar(128) = '',
	@message varchar(512) = '' output,
	
	@InstrumentFilter varchar(1024) = '',			-- Single instrument name or instrument name match strings; use SP GetInstrumentNamesForDB to see the instruments for the jobs in a given DB
	@CampaignFilter varchar(1024) = '',
	@ExperimentFilter varchar(1024) = '',
	@DatasetFilter varchar(1024) = '',
	@OrganismDBFilter varchar(1024) = '',

	@DatasetDateMinimum varchar(32) = '',			-- Ignored if blank; note that this will be compared against the Dataset's Acquisition Start Time, if possible
	@DatasetDateMaximum varchar(32) = '',			-- Ignored if blank; note that this will be compared against the Dataset's Acquisition End Time, if possible

	@JobMinimum int = 0,							-- Ignored if 0
	@JobMaximum int = 0,							-- Ignored if 0
	
	@maximumJobCount int = 0						-- 0 means to return all rows
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0
	
	set @message = ''
	
	---------------------------------------------------
	-- Validate that DB exists on this server, determine its type,
	-- and look up its schema version
	---------------------------------------------------

	Declare @DBType tinyint				-- 1 if PMT Tag DB, 2 if Peptide DB
	Declare @DBSchemaVersion real
	
	Set @DBType = 0
	Set @DBSchemaVersion = 1
	
	Exec @myError = GetDBTypeAndSchemaVersion @DBName, @DBType OUTPUT, @DBSchemaVersion OUTPUT, @message = @message OUTPUT

	-- Make sure the type is 1 or 2 and that no errors occurred
	If @DBType = 0 Or @myError <> 0
	Begin
		If @myError = 0
			Set @myError = 20000

		If Len(@message) = 0
			Set @message = 'Database not found on this server: ' + @DBName
		Goto Done
	End
	Else
	If @DBType <> 1 AND @DBType <> 2
	Begin
		Set @myError = 20001
		Set @message = 'Database ' + @DBName + ' is not a Peptide DB or a PMT Tag DB and is therefore not appropriate for this procedure'
		Goto Done
	End
	Else
	If @DBSchemaVersion <= 1
	Begin
		Set @myError = 20002
		Set @message = 'Database ' + @DBName + ' has a DB Schema Version less than 2 and is therefore not supported by this procedure'
		Goto Done
	End
		
	---------------------------------------------------
	-- build the sql query to get the jobs
	---------------------------------------------------
	declare @sqlSelect varchar(2048)
	declare @sqlFromA varchar(2048)
	declare @sqlFromB varchar(1024)
	declare @sqlGroupBy varchar(2048)
	declare @sqlOrderBy varchar(2048)


	-- Construct the SELECT clause, optionally limiting the number of rows
	Set @sqlSelect = ''
	Set @sqlSelect = @sqlSelect + ' INSERT INTO #TmpQCJobList (Job)'


	If IsNull(@maximumJobCount,-1) <= 0
		Set @sqlSelect = @sqlSelect + ' SELECT'
	Else
		Set @sqlSelect = @sqlSelect + ' SELECT TOP ' + Convert(varchar(9), @maximumJobCount)

	Set @sqlSelect = @sqlSelect + ' Job'
	
	-- Construct the From clause
	-- The From clause has two parts, since we insert where clause elements between the two parts when we actually run the query
	
	Set @sqlFromA = 'FROM'
	Set @sqlFromB = ''
	
	If @DBType = 1
	Begin
		-- PMT Tag DB
		Set @sqlFromA = @sqlFromA + ' (SELECT IsNull(JobTable.Dataset_Acq_Time_Start, JobTable.Dataset_Created_DMS) AS Dataset_Date,'
		Set @sqlFromA = @sqlFromA +         ' JobTable.Dataset_ID, JobTable.Job, JobTable.Instrument,'
		Set @sqlFromA = @sqlFromA +         ' JobTable.Dataset AS Dataset_Name, JobTable.Completed AS Job_Date'
		Set @sqlFromA = @sqlFromA +  ' FROM DATABASE..T_Analysis_Description JobTable'
		Set @sqlFromA = @sqlFromA +  ' WHERE  JobTable.ResultType = ''Peptide_Hit'''
		Set @sqlFromA = @sqlFromA +     ' AND JobTable.State <> 5'				-- Exclude jobs marked as 'No Interest' in PMT Tag DBs

		-- Add the optional dataset range filters
		If Len(@DatasetDateMinimum) > 0
			Set @sqlFromA = @sqlFromA + ' AND (IsNull(JobTable.Dataset_Acq_Time_Start, JobTable.Dataset_Created_DMS) >= ''' + @DatasetDateMinimum + ''')'
		If Len(@DatasetDateMaximum) > 0
			Set @sqlFromA = @sqlFromA + ' AND (IsNull(JobTable.Dataset_Acq_Time_Start, JobTable.Dataset_Created_DMS) <= ''' + @DatasetDateMaximum + ''')'

		-- Add the optional job range filters
		If @JobMinimum > 0
			Set @sqlFromA = @sqlFromA + ' AND (JobTable.Job >= ' + Convert(varchar(12), @JobMinimum) + ')'
		If @JobMaximum > 0
			Set @sqlFromA = @sqlFromA + ' AND (JobTable.Job <= ' + Convert(varchar(12), @JobMaximum) + ')'

		-- Note: We'll add additional where clause elements later on
		Set @sqlFromB = @SqlFromB + ') AS LookupQ'

	End
	Else
	Begin
		-- Peptide DB
		Set @sqlFromA = @sqlFromA + ' (SELECT IsNull(DatasetTable.Acq_Time_Start, DatasetTable.Created_DMS) AS Dataset_Date,'
		Set @sqlFromA = @sqlFromA +         ' JobTable.Dataset_ID, JobTable.Job, JobTable.Instrument,'
		Set @sqlFromA = @sqlFromA +         ' JobTable.Dataset AS Dataset_Name, JobTable.Completed AS Job_Date'
		Set @sqlFromA = @sqlFromA +  ' FROM DATABASE..T_Analysis_Description JobTable'
		Set @sqlFromA = @sqlFromA +       ' INNER JOIN DATABASE..T_Datasets DatasetTable ON JobTable.Dataset_ID = DatasetTable.Dataset_ID'
		Set @sqlFromA = @sqlFromA +  ' WHERE  JobTable.ResultType = ''Peptide_Hit'''
		Set @sqlFromA = @sqlFromA +     ' AND JobTable.Process_State = 70'				-- Only include jobs with state 70 in Peptide DBs

		-- Add the optional dataset range filters
		If Len(@DatasetDateMinimum) > 0
			Set @sqlFromA = @sqlFromA + ' AND (IsNull(DatasetTable.Acq_Time_Start, DatasetTable.Created_DMS) >= ''' + @DatasetDateMinimum + ''')'
		If Len(@DatasetDateMaximum) > 0
			Set @sqlFromA = @sqlFromA + ' AND (IsNull(DatasetTable.Acq_Time_Start, DatasetTable.Created_DMS) <= ''' + @DatasetDateMaximum + ''')'

		-- Add the optional job range filters
		If @JobMinimum > 0
			Set @sqlFromA = @sqlFromA + ' AND (JobTable.Job >= ' + Convert(varchar(12), @JobMinimum) + ')'
		If @JobMaximum > 0
			Set @sqlFromA = @sqlFromA + ' AND (JobTable.Job <= ' + Convert(varchar(12), @JobMaximum) + ')'

		-- Note: We'll add additional where clause elements later on
		Set @sqlFromB = @SqlFromB + ') AS LookupQ'

	End
	

	-- We could define a where clause for LookupQ, using:
	--Set @sqlWhere = 'WHERE'

	-- Construct the Group By clause
    Set @sqlGroupBy = 'GROUP BY '
	Set @sqlGroupBy = @sqlGroupBy + '  Dataset_Date'
	Set @sqlGroupBy = @sqlGroupBy + ', Dataset_ID'
	Set @sqlGroupBy = @sqlGroupBy + ', Job'
	Set @sqlGroupBy = @sqlGroupBy + ', Instrument'
	Set @sqlGroupBy = @sqlGroupBy + ', Dataset_Name'
	Set @sqlGroupBy = @sqlGroupBy + ', Job_Date'

	-- Define the Order By clause
	Set @sqlOrderBy = 'ORDER BY Dataset_Date, Dataset_ID'


	---------------------------------------------------
	-- Customize the columns for the given database
	---------------------------------------------------

	set @sqlFromA = replace(@sqlFromA, 'DATABASE..', '[' + @DBName + ']..')
	

	---------------------------------------------------
	-- Parse filter parameters to create a proper
	-- SQL where clause containing a mix of 
	-- Where xx In ('A','B') and Where xx Like ('C%') statements
	---------------------------------------------------

	Declare @InstrumentWhere varchar(8000),
			@CampaignWhere varchar(8000),
			@ExperimentWhere varchar(8000),
			@DatasetWhere varchar(8000),
			@OrganismDBWhere varchar(8000)
			
	Set @InstrumentWhere = ''
	Set @CampaignWhere = ''
	Set @ExperimentWhere = ''
	Set @DatasetWhere = ''
	Set @OrganismDBWhere = ''
	
	Exec ConvertListToWhereClause @InstrumentFilter, 'JobTable.Instrument', @entryListWhereClause = @InstrumentWhere OUTPUT
	Exec ConvertListToWhereClause @CampaignFilter, 'JobTable.Campaign', @entryListWhereClause = @CampaignWhere OUTPUT
	Exec ConvertListToWhereClause @ExperimentFilter, 'JobTable.Experiment', @entryListWhereClause = @ExperimentWhere OUTPUT
	Exec ConvertListToWhereClause @DatasetFilter, 'JobTable.Dataset', @entryListWhereClause = @DatasetWhere OUTPUT
	Exec ConvertListToWhereClause @OrganismDBFilter, 'JobTable.Organism_DB_Name', @entryListWhereClause = @OrganismDBWhere OUTPUT

	-- We could append the various where clauses to @sqlWhere, but the string length
	-- could become too long; thus, we'll add it in when we combine the Sql to Execute
	-- However, we need to prepend them with AND

	If Len(@InstrumentWhere) > 0
		Set @InstrumentWhere = ' AND (' + @InstrumentWhere + ')'

	If Len(@CampaignWhere) > 0
		Set @CampaignWhere = ' AND (' + @CampaignWhere + ')'

	If Len(@ExperimentWhere) > 0
		Set @ExperimentWhere = ' AND (' + @ExperimentWhere + ')'

	If Len(@DatasetWhere) > 0
		Set @DatasetWhere = ' AND (' + @DatasetWhere + ')'

	If Len(@OrganismDBWhere) > 0
		Set @OrganismDBWhere = ' AND (' + @OrganismDBWhere + ')'
	

	---------------------------------------------------
	-- Populate #TmpQCJobList with the list of jobs
	---------------------------------------------------
	
	--print	@sqlSelect + ' ' + @sqlFromA + ' ' + @InstrumentWhere + @CampaignWhere + @ExperimentWhere + @DatasetWhere + @OrganismDBWhere + ' ' + @sqlFromB + ' ' + @sqlGroupBy + ' ' + @sqlOrderBy
	Exec (	@sqlSelect + ' ' + @sqlFromA + ' ' + @InstrumentWhere + @CampaignWhere + @ExperimentWhere + @DatasetWhere + @OrganismDBWhere + ' ' + @sqlFromB + ' ' + @sqlGroupBy + ' ' + @sqlOrderBy)
	--	
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
Done:
	return @myError

GO
