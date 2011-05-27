/****** Object:  StoredProcedure [dbo].[QCMSMSMetricByJobWork] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE QCMSMSMetricByJobWork
/****************************************************
**
**	Desc: 
**		Uses @SeqIDList and @MetricID to return a metric value
**		 for all jobs matching the given job filters in the specified database
**		This procedure can only be used with Peptide databases
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**	  @DBName				-- Peptide or PMT Tag database name
**	  @returnRowCount		-- Set to True to return a row count; False to return the results
**	  @message				-- Status/error message output
**
**	Auth:	mem
**	Date:	08/29/2005
**			11/10/2005 mem - Updated to preferably use Acq_Time_Start rather than Created_DMS for dataset date filtering
**		    11/23/2005 mem - Added brackets around @DBName as needed to allow for DBs with dashes in the name
**			10/07/2008 mem - Now returning jobs that don't have any peptides passing the filters (reporting a value of 0 for those jobs)
**			09/22/2010 mem - Added parameter @ResultTypeFilter
**			10/06/2010 mem - Now returning column Dataset_Rating
**
*****************************************************/
(
	@DBName varchar(128) = '',
	@returnRowCount varchar(32) = 'False',
	@message varchar(512) = '' output,
	
	@InstrumentFilter varchar(128) = '',			-- Single instrument name or instrument name match strings; use SP GetInstrumentNamesForDB to see the instruments for the jobs in a given DB
	@CampaignFilter varchar(1024) = '',
	@ExperimentFilter varchar(1024) = '',
	@DatasetFilter varchar(1024) = '',
	@OrganismDBFilter varchar(1024) = '',

	@DatasetDateMinimum varchar(32) = '',			-- Ignored if blank
	@DatasetDateMaximum varchar(32) = '',			-- Ignored if blank
	@JobMinimum int = 0,							-- Ignored if 0
	@JobMaximum int = 0,							-- Ignored if 0
	
	@maximumRowCount int = 0,						-- 0 means to return all rows
	
	@MetricID tinyint = 0,							-- 0 means area, 1 means S/N
	@UseNaturalLog tinyint = 1,
	@SeqIDList varchar(7000),						-- Required: Comma separated list of Seq_ID values to match
	@MeanSquareError float = 0 output,

	@ResultTypeFilter varchar(32) = 'XT_Peptide_Hit',	-- Peptide_Hit is Sequest, XT_Peptide_Hit is X!Tandem, IN_Peptide_Hit is Inspect
	@PreviewSql tinyint = 0
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
	If @DBType <> 2
	Begin
		Set @myError = 20001
		Set @message = 'Database ' + @DBName + ' is not a Peptide DB and is therefore not appropriate for this procedure'
		Goto Done
	End
	Else
	If @DBSchemaVersion <= 1
	Begin
		Set @myError = 20002
		Set @message = 'Database ' + @DBName + ' has a DB Schema Version less than 1 and is therefore not supported by this procedure'
		Goto Done
	End
		
	---------------------------------------------------
	-- Cleanup the input parameters
	---------------------------------------------------

	-- Cleanup the True/False parameters
	Exec CleanupTrueFalseParameter @returnRowCount OUTPUT, 1

	Set @ResultTypeFilter = IsNull(@ResultTypeFilter, '')
	Set @previewSql = IsNull(@previewSql, 0)

	-- Force @maximumRowCount to be negative if @returnRowCount is true
	If @returnRowCount = 'true'
		Set @maximumRowCount = -1

	---------------------------------------------------
	-- Create the jobs temporary table
	---------------------------------------------------
	
--	If exists (select * from dbo.sysobjects where id = object_id(N'[#TmpQCJobList]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
--		drop table [#TmpQCJobList]

	CREATE TABLE #TmpQCJobList (
		Job int NOT NULL 
	)

	CREATE UNIQUE CLUSTERED INDEX [#IX_TmpQCJobList] ON #TmpQCJobList(Job)

	CREATE TABLE #TmpQueryResults (
		Dataset_Date datetime NULL,
		Dataset_ID int NOT NULL,
		Job int NOT NULL,
		Instrument varchar(64) NULL,
		Dataset_Name varchar(128) NOT NULL,
		Dataset_Rating varchar(64) NOT NULL,
		Job_Date datetime NULL,
		Value int NULL
	)

	CREATE UNIQUE CLUSTERED INDEX [#IX_TmpQueryResults] ON #TmpQueryResults(Job)
	
	---------------------------------------------------
	-- Populate the temporary table with the jobs matching the filters
	---------------------------------------------------
	
	Exec @myError = QCMSMSJobsTablePopulate	@DBName, @message output, 
											@InstrumentFilter, @CampaignFilter, @ExperimentFilter, @DatasetFilter, 
											@OrganismDBFilter, @DatasetDateMinimum, @DatasetDateMaximum, 
											@JobMinimum, @JobMaximum, @maximumRowCount,
											@ResultTypeFilter, @PreviewSql
	If @myError <> 0
	Begin
		If Len(IsNull(@message, '')) = 0
			Set @message = 'Error calling QCMSMSJobTablePopulate'
		Goto Done
	End


	---------------------------------------------------
	-- Create the temporary table to hold the metric data for each sequence in each job
	---------------------------------------------------
	
--	If exists (select * from dbo.sysobjects where id = object_id(N'[#TmpQCMetricData]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
--		drop table [#TmpQCMetricData]

	CREATE TABLE #TmpQCMetricData (
		Job int NOT NULL,
		Seq_ID int NOT NULL,
		Metric float NULL,			-- This originally contains the raw value, but is soon-after updated to the logarithm of the raw value (if @UseNaturalLog = 1)
		A2 float NULL,				-- A2 = Metric - GlobalMean; The result is used to compute Peptide Means
		A3 float NULL,				-- A3 = Metric - PeptideMeans; The result is used to compute Sample Means
		A4Squared float NULL		-- A4Squared = (A3 - SampleMeans)^2; The result is used to compute Mean Square Error
	)

	CREATE UNIQUE CLUSTERED INDEX [#IX_TmpQCMetricData] ON #TmpQCMetricData(Job, Seq_ID)


	---------------------------------------------------
	-- Create the temporary tables to hold the peptide means and the sample means
	---------------------------------------------------

--	If exists (select * from dbo.sysobjects where id = object_id(N'[#TmpQCMetricPeptideMeans]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
--		drop table [#TmpQCMetricPeptideMeans]
--	If exists (select * from dbo.sysobjects where id = object_id(N'[#TmpQCMetricSampleMeans]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
--		drop table [#TmpQCMetricSampleMeans]

	CREATE TABLE #TmpQCMetricPeptideMeans (
		Seq_ID int NOT NULL,
		Mean float NULL
	)
	CREATE UNIQUE CLUSTERED INDEX [#IX_TmpQCMetricPeptideMeans] ON #TmpQCMetricPeptideMeans(Seq_ID)

	CREATE TABLE #TmpQCMetricSampleMeans (
		Job int NOT NULL,
		Mean float NULL
	)
	CREATE UNIQUE CLUSTERED INDEX [#IX_TmpQCMetricSampleMeans] ON #TmpQCMetricSampleMeans(Job)


	---------------------------------------------------
	-- Build the sql query to populate #TmpQCMetricData
	---------------------------------------------------
	declare @Sql varchar(1024)
	declare @sqlWhere varchar(7100)
	declare @sqlGroupBy varchar(128)

	Set @Sql = ''
	Set @Sql = @Sql + ' INSERT INTO #TmpQCMetricData (Job, Seq_ID, Metric)'
	Set @Sql = @Sql + ' SELECT JobTable.Job, Pep.Seq_ID,'
	
	If @MetricID = 0
		Set @Sql = @Sql + ' MAX(DSSIC.Peak_Area)'
	Else
		Set @Sql = @Sql + ' MAX(DSSIC.Peak_SN_Ratio)'

	Set @Sql = @Sql +  ' FROM DATABASE.dbo.T_Analysis_Description JobTable'
	Set @Sql = @Sql +       ' INNER JOIN #TmpQCJobList ON JobTable.Job = #TmpQCJobList.Job'

	Set @Sql = @Sql +       ' INNER JOIN DATABASE.dbo.T_Datasets DatasetTable ON JobTable.Dataset_ID = DatasetTable.Dataset_ID'
	Set @Sql = @Sql +       ' INNER JOIN DATABASE.dbo.T_Peptides Pep ON JobTable.Job = Pep.Analysis_ID'

    Set @Sql = @Sql +       ' INNER JOIN DATABASE.dbo.T_Dataset_Stats_SIC DSSIC WITH (NOLOCK) ON'
    Set @Sql = @Sql +         ' DatasetTable.SIC_Job = DSSIC.Job AND Pep.Scan_Number = DSSIC.Frag_Scan_Number'
    Set @Sql = @Sql +       ' INNER JOIN DATABASE.dbo.T_Dataset_Stats_Scans DSS_OptimalPeakApex WITH (NOLOCK) ON'
    Set @Sql = @Sql +         ' DSSIC.Job = DSS_OptimalPeakApex.Job AND DSSIC.Optimal_Peak_Apex_Scan_Number = DSS_OptimalPeakApex.Scan_Number'

	-- Define the where clause using @SeqIDList
	Set @sqlWhere = 'WHERE Pep.Seq_ID In (' + @SeqIDList + ')'

	-- Construct the Group By clause
    Set @sqlGroupBy = 'GROUP BY JobTable.Job, Pep.Seq_ID'

	---------------------------------------------------
	-- Customize the columns for the given database
	---------------------------------------------------

	set @Sql = replace(@Sql, 'DATABASE.dbo.', '[' + @DBName + '].dbo.')

	---------------------------------------------------
	-- Run the query to populate #TmpQCMetricData
	---------------------------------------------------
	if @previewSql <> 0
		Print (@Sql + ' ' + @sqlWhere + ' ' + @sqlGroupBy)
	Else
		Exec (@Sql + ' ' + @sqlWhere + ' ' + @sqlGroupBy)
	--	
	SELECT @myError = @@error, @myRowCount = @@rowcount


	If @previewSql = 0
	Begin -- <a>
		If @myRowCount = 0
		Begin
			Set @message = 'No data was matched using the query; unable to continue'
			Set @myError = 50000
			Goto Done
		End


		---------------------------------------------------
		-- Process the data
		-- This procedure was developed by Don Daly with the
		--  assistance of Kevin Anderson and Jason Gilmore
		--  in July 2005
		---------------------------------------------------

		Declare @GlobalMean float,
				@GlobalSumA4Squared float,
				@GlobalCount int,
				@SampleCount int,
				@SeqIDCount int,
				@DegOfFreedom int,
				@Divisor float
				
		-- Delete any rows where Metric is <= 0
		-- Necessary since we don't want to process values <= 0 (and, we can't take the logarithm of 0 or negative values when @UseNaturalLog = 1)
		DELETE FROM #TmpQCMetricData
		WHERE Metric <= 0
		--	
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		-- Take the natural log of the data if @UseNaturalLog = 1
		If @UseNaturalLog <> 0
			UPDATE #TmpQCMetricData
			SET Metric = Log(Metric)

		-- Compute the global mean of the data
		Set @GlobalMean = 0
		SELECT @GlobalMean = Avg(Metric)
		FROM #TmpQCMetricData
		--	
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @myError <> 0
		Begin
			Set @message = 'Error computing the global mean of the data; Error Code = ' + Convert(varchar(9), @myError)
			Goto Done
		End
		
		If IsNull(@GlobalMean, 0) = 0
		Begin
			Set @message = 'Global mean is 0; cannot continue with the data processing'
			Set @myError = 50001
			Goto Done
		End

		-- Compute A2
		UPDATE #TmpQCMetricData
		SET A2 = Metric - @GlobalMean
		
		-- Compute the mean of A2 for each peptide (across jobs) and store in #TmpQCMetricPeptideMeans
		INSERT INTO #TmpQCMetricPeptideMeans (Seq_ID, Mean)
		SELECT Seq_ID, Avg(A2)
		FROM #TmpQCMetricData
		GROUP BY Seq_ID

		-- Compute A3
		UPDATE #TmpQCMetricData
		SET A3 = MD.Metric - PM.Mean
		FROM #TmpQCMetricData MD INNER JOIN #TmpQCMetricPeptideMeans PM ON MD.Seq_ID = PM.Seq_ID

		-- Compute the mean of A3 for each job (across peptides) and store in #TmpQCMetricSampleMeans
		INSERT INTO #TmpQCMetricSampleMeans (Job, Mean)
		SELECT Job, Avg(A3)
		FROM #TmpQCMetricData
		GROUP BY Job

		-- Compute A4Squared
		UPDATE #TmpQCMetricData
		SET A4Squared = Square((MD.A3 - SM.Mean))
		FROM #TmpQCMetricData MD INNER JOIN #TmpQCMetricSampleMeans SM ON MD.Job = SM.Job

		
		-- Compute the Global Stats using A4Squared
		SELECT	@GlobalSumA4Squared = SUM(A4Squared), 
				@GlobalCount = COUNT(A4Squared),
				@SampleCount = COUNT(DISTINCT Job),
				@SeqIDCount = COUNT(DISTINCT Seq_ID)
		FROM #TmpQCMetricData

		Set @DegOfFreedom = 1
		Set @Divisor = @GlobalCount-@SeqIDCount-@SampleCount-@DegOfFreedom
		
		If IsNull(@Divisor, 0) <> 0
			Set @MeanSquareError = @GlobalSumA4Squared / @Divisor
		Else
			Set @MeanSquareError = 0
	End -- </a>
	
	---------------------------------------------------
	-- Build the query to return the results, linking into the job table to obtain the associated job info
	---------------------------------------------------

	declare @SqlInsert varchar(255)
	declare @JobQuery varchar(2048)
	declare @sqlOrderBy varchar(2048)

	declare @sqlAddMissingJobs varchar(2048)
	
	Set @JobQuery = ''
	Set @JobQuery = @JobQuery + ' SELECT IsNull(DatasetTable.Acq_Time_Start, DatasetTable.Created_DMS) AS Dataset_Date,'
	Set @JobQuery = @JobQuery +		  ' JobTable.Dataset_ID, JobTable.Job,JobTable.Instrument,'
	Set @JobQuery = @JobQuery +       ' JobTable.Dataset AS Dataset_Name, IsNull(DS.Rating, '''') AS Dataset_Rating,'
	Set @JobQuery = @JobQuery +       ' JobTable.Completed AS Job_Date, 0 as Value'
	Set @JobQuery = @JobQuery +  ' FROM DATABASE.dbo.T_Analysis_Description JobTable'
	Set @JobQuery = @JobQuery +       ' INNER JOIN DATABASE.dbo.T_Datasets DatasetTable ON JobTable.Dataset_ID = DatasetTable.Dataset_ID'
	Set @JobQuery = @JobQuery +       ' INNER JOIN #TmpQCJobList ON JobTable.Job = #TmpQCJobList.Job'
	Set @JobQuery = @JobQuery +       ' LEFT OUTER JOIN MT_Main.dbo.T_DMS_Dataset_Info_Cached DS ON JobTable.Dataset_ID = DS.ID'
		
	Set @Sql = ''
	Set @Sql = @Sql + ' SELECT IsNull(DatasetTable.Acq_Time_Start, DatasetTable.Created_DMS) AS Dataset_Date,'
	Set @Sql = @Sql +		  ' JobTable.Dataset_ID,JobTable.Job, JobTable.Instrument,'
	Set @Sql = @Sql +		  ' JobTable.Dataset AS Dataset_Name, IsNull(DS.Rating, '''') AS Dataset_Rating,'	
	Set @Sql = @Sql +		  ' JobTable.Completed AS Job_Date, SM.Mean AS Value'
	Set @Sql = @Sql +  ' FROM DATABASE.dbo.T_Analysis_Description JobTable'
	Set @Sql = @Sql +       ' INNER JOIN DATABASE.dbo.T_Datasets DatasetTable ON JobTable.Dataset_ID = DatasetTable.Dataset_ID'
	Set @Sql = @Sql +       ' INNER JOIN #TmpQCMetricSampleMeans SM ON JobTable.Job = SM.Job'
	Set @Sql = @Sql +       ' LEFT OUTER JOIN MT_Main.dbo.T_DMS_Dataset_Info_Cached DS ON JobTable.Dataset_ID = DS.ID'
	
	Set @sqlOrderBy = 'ORDER BY IsNull(DatasetTable.Acq_Time_Start, DatasetTable.Created_DMS), JobTable.Dataset_ID'


	---------------------------------------------------
	-- Customize the columns for the given database
	---------------------------------------------------
	set @JobQuery = replace(@JobQuery, 'DATABASE.dbo.', '[' + @DBName + '].dbo.')
	set @Sql = replace(@Sql, 'DATABASE.dbo.', '[' + @DBName + '].dbo.')
	
	
	Set @SqlInsert = 'INSERT INTO #TmpQueryResults (Dataset_Date, Dataset_ID, Job, Instrument, Dataset_Name, Dataset_Rating, Job_Date, Value) '

	Set @sqlAddMissingJobs = @SqlInsert
	Set @sqlAddMissingJobs = @sqlAddMissingJobs + ' ' + @JobQuery
	Set @sqlAddMissingJobs = @sqlAddMissingJobs + ' WHERE NOT JobTable.Job IN ( SELECT Job FROM #TmpQueryResults )'

	---------------------------------------------------
	-- Return the results
	---------------------------------------------------
		
	If @PreviewSql <> 0
	Begin
		print 	@SqlInsert + ' ' + @Sql
		print	@sqlAddMissingJobs
	End
	Else
	Begin
		-- Populate #TmpQueryResults
		Exec (@SqlInsert + ' ' + @Sql)
		
		-- Append any missing jobs to #TmpQueryResults
		Exec (@sqlAddMissingJobs)

		If @returnRowCount = 'true'
		begin
			-- Old method:
			-- In order to return the row count, we wrap the sql text with Count (*) 
			-- and exclude the @sqlOrderBy text from the sql statement
			--Exec ('SELECT Count (*) As ResultSet_Row_Count FROM (' + @Sql + ') As CountQ')

			SELECT COUNT(*) As ResultSet_Row_Count
			FROM #TmpQueryResults
		end
		Else
		begin
			-- Old method:
			--Exec (	 @Sql + ' ' + @sqlOrderBy)

			SELECT Dataset_Date, Dataset_ID, Job, Instrument, Dataset_Name, Dataset_Rating, Job_Date, Value 
			FROM #TmpQueryResults
			ORDER BY Dataset_Date, Dataset_ID
		end
		--	
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		Declare @UsageMessage varchar(512)
		Set @UsageMessage = Convert(varchar(9), @myRowCount) + ' rows'
		Exec PostUsageLogEntry 'QCMSMSMetricByJobWork', @DBName, @UsageMessage	

	End
	

Done:
	return @myError

GO
GRANT EXECUTE ON [dbo].[QCMSMSMetricByJobWork] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[QCMSMSMetricByJobWork] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[QCMSMSMetricByJobWork] TO [MTS_DB_Lite] AS [dbo]
GO
