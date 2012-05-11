/****** Object:  StoredProcedure [dbo].[ObtainSeqOccurrenceStats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE ObtainSeqOccurrenceStats
/****************************************************
**
**	Desc: 
**		Populates table #Tmp_Seq_Occurence_Stats with the occurrence rates 
**		  for the sequences matching the given filters and found in the given jobs
**
**		The calling procedure must create table #Tmp_Seq_Occurence_Stats before calling this SP
**
**
**		CREATE TABLE #Tmp_Seq_Occurence_Stats (
**			Seq_ID int NOT NULL,
**			Job_Count_Observed int NULL,
**			Percent_Jobs_Observed real NULL,
**			Avg_NET real NULL,						-- Populated by ObtainSeqOccurrenceStats, but not returned by this SP
**			Cnt_NET real NULL,						-- Populated by ObtainSeqOccurrenceStats, but not returned by this SP
**			StD_NET real NULL						-- Populated by ObtainSeqOccurrenceStats, but not returned by this SP
**		)
**
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	03/01/2006
**			09/22/2010 mem - Added parameters @PeptideProphetMinimum, @MSGFThreshold, @ResultTypeFilter, and @PreviewSql
**			01/06/2012 mem - Updated to use T_Peptides.Job
**
*****************************************************/
(
	@DBName varchar(128) = '',
	@returnRowCount varchar(32) = 'False',			-- If this is True, then #Tmp_Seq_Occurence_Stats will contain the row count in the Seq_ID column of the first row
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
	
	@DiscriminantScoreMinimum real = 0,				-- Ignored if 0
	@CleavageStateMinimum tinyint = 0,				-- Ignored if 0
	@XCorrMinimum real = 0,							-- Ignored if 0
	@DeltaCn2Minimum real = 0,						-- Ignored if 0
	@RankXcMaximum smallint = 0,					-- Ignored if 0

	@FilterIDFilter int = 117,						-- Ignored if 0; only appropriate for Peptide DBs
	@PMTQualityScoreMinimum int = 1,				-- Ignored if 0; only appropriate for PMT Tag DBs
	
	@maximumRowCount int = 255,						-- 0 means to return all rows; defaults to 255 to limit the number of sequences returned

	@PeptideProphetMinimum real = 0,				-- Ignored if 0
	@MSGFThreshold float = 1E-11,					-- Ignored if 0; example threshold is 1E-11 which means to keep peptides with MSGF < 1E-11
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
	-- Cleanup the input parameters
	---------------------------------------------------

	-- Cleanup the True/False parameters
	Exec CleanupTrueFalseParameter @returnRowCount OUTPUT, 1

	Set @ResultTypeFilter = IsNull(@ResultTypeFilter, '')
	Set @PreviewSql = IsNull(@PreviewSql, 0)
	

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
	
	---------------------------------------------------
	-- Populate the temporary table with the jobs matching the filters
	-- Note that we are sending 0 for @maximumJobCount
	---------------------------------------------------
	
	Exec @myError = QCMSMSJobsTablePopulate	@DBName, @message output, 
											@InstrumentFilter, @CampaignFilter, @ExperimentFilter, @DatasetFilter, 
											@OrganismDBFilter, @DatasetDateMinimum, @DatasetDateMaximum, 
											@JobMinimum, @JobMaximum, 
											0, -- @maximumJobCount
											@ResultTypeFilter, @PreviewSql
	If @myError <> 0
	Begin
		If Len(IsNull(@message, '')) = 0
			Set @message = 'Error calling QCMSMSJobTablePopulate'
		Goto Done
	End

	---------------------------------------------------
	-- Count the number of jobs in #TmpQCJobList
	---------------------------------------------------
	Declare @JobCount int
	
	SELECT @JobCount = Count(Job)
	FROM #TmpQCJobList
	--	
	SELECT @myError = @@error, @myRowCount = @@rowcount

	If IsNull(@JobCount, 0) = 0
	Begin
		Set @message = 'No jobs were found matching the given filter parameters'
		Goto Done
	End
	
	---------------------------------------------------
	-- build the sql query to get mass tag data
	---------------------------------------------------
	declare @sqlInsert varchar(1024)
	declare @sqlSelect2 varchar(1024)
	declare @sqlSelect varchar(2048)
	declare @sqlFrom varchar(2048)
	declare @sqlOrderBy varchar(2048)

	-- Construct the INSERT clause
	Set @sqlInsert = ' INSERT INTO #Tmp_Seq_Occurence_Stats (Seq_ID, Job_Count_Observed, Percent_Jobs_Observed, Avg_NET, Cnt_NET, StD_NET)'

	-- Construct the SELECT clause, optionally limiting the number of rows
	Set @sqlSelect = ''
	If IsNull(@maximumRowCount,-1) <= 0
		Set @sqlSelect = @sqlSelect + ' SELECT'
	Else
		Set @sqlSelect = @sqlSelect + ' SELECT TOP ' + Convert(varchar(9), @maximumRowCount)

	-- For each sequence, return the number of jobs it was observed in and the percentage of the total jobs containing the sequence
	Set @sqlSelect = @sqlSelect + ' Seq_ID,'
	Set @sqlSelect = @sqlSelect + ' Job_Count_Observed,'
	Set @sqlSelect = @sqlSelect + ' Round(Job_Count_Observed / Convert(real, ' + Convert(varchar(9), @JobCount) + ') * 100, 2) AS Percent_Jobs_Observed,'
	Set @sqlSelect = @sqlSelect + ' Avg_NET, Cnt_NET, StD_NET'

	-- Construct the From clause
	
	Set @sqlFrom = 'FROM'
	
	If @DBType = 1
	Begin
		-- PMT Tag DB
		Set @sqlFrom = @sqlFrom + ' (SELECT Pep.Mass_Tag_ID AS Seq_ID, COUNT(DISTINCT Pep.Job) AS Job_Count_Observed,'
		Set @sqlFrom = @sqlFrom +         ' AVG(Pep.GANET_Obs) As Avg_NET, COUNT(Pep.Peptide_ID) As Cnt_NET, StDev(Pep.GANET_Obs) As StD_NET'
		Set @sqlFrom = @sqlFrom +  ' FROM DATABASE..T_Analysis_Description JobTable'
		Set @sqlFrom = @sqlFrom +       ' INNER JOIN #TmpQCJobList ON JobTable.Job = #TmpQCJobList.Job'
		Set @sqlFrom = @sqlFrom +       ' INNER JOIN DATABASE..T_Peptides Pep ON JobTable.Job = Pep.Job'

		If @XCorrMinimum > 0 OR @DeltaCn2Minimum > 0 OR @RankXcMaximum > 0
			Set @sqlFrom = @sqlFrom +   ' INNER JOIN DATABASE..T_Score_Sequest SS ON Pep.Peptide_ID = SS.Peptide_ID'
		
		If @PMTQualityScoreMinimum > 0
			Set @sqlFrom = @sqlFrom +   ' INNER JOIN DATABASE..T_Mass_Tags MT ON Pep.Mass_Tag_ID = MT.Mass_Tag_ID'
			
		If @DiscriminantScoreMinimum > 0 Or @PeptideProphetMinimum > 0 Or @MSGFThreshold > 0
			Set @sqlFrom = @sqlFrom +   ' INNER JOIN DATABASE..T_Score_Discriminant SD ON Pep.Peptide_ID = SD.Peptide_ID'
			
		Set @sqlFrom = @sqlFrom +  ' WHERE  Pep.Max_Obs_Area_In_Job = 1'
		
		-- Add the optional score filters
		If @DiscriminantScoreMinimum > 0
			Set @sqlFrom = @sqlFrom + ' AND (SD.DiscriminantScoreNorm >= ' + Convert(varchar(12), @DiscriminantScoreMinimum) + ')'
			
		-- Note: X!Tandem jobs don't have peptide prophet values, so all X!Tandem data will get excluded if @PeptideProphetMinimum is used
		If @PeptideProphetMinimum > 0
			Set @sqlFrom = @sqlFrom + ' AND (IsNull(SD.Peptide_Prophet_Probability, 0)  >= ' + Convert(varchar(12), @PeptideProphetMinimum) + ')'

		If @MSGFThreshold > 0
			Set @sqlFrom = @sqlFrom + ' AND (IsNull(SD.MSGF_SpecProb, 1) <= ' + Convert(varchar(12), @MSGFThreshold) + ')'			
		
		If @CleavageStateMinimum > 0
			Set @sqlFrom = @sqlFrom + ' AND (MT.Cleavage_State_Max >= ' + Convert(varchar(6), @CleavageStateMinimum) + ')'
		If @XCorrMinimum > 0
			Set @sqlFrom = @sqlFrom + ' AND (SS.XCorr >= ' + Convert(varchar(12), @XCorrMinimum) + ')'
		If @DeltaCn2Minimum > 0
			Set @sqlFrom = @sqlFrom + ' AND (SS.DeltaCn2 >= ' + Convert(varchar(12), @DeltaCn2Minimum) + ')'
		If @RankXcMaximum > 0
			Set @sqlFrom = @sqlFrom + ' AND (SS.RankXc <= ' + Convert(varchar(12), @RankXcMaximum) + ')'
		If @PMTQualityScoreMinimum > 0
			Set @sqlFrom = @sqlFrom + ' AND (MT.PMT_Quality_Score >= ' + Convert(varchar(12), @PMTQualityScoreMinimum) + ')'

		Set @sqlFrom = @sqlFrom + ' GROUP BY Pep.Mass_Tag_ID) AS LookupQ'

	End
	Else
	Begin
		-- Peptide DB
		Set @sqlFrom = @sqlFrom + ' (SELECT Pep.Seq_ID, COUNT(DISTINCT Pep.Job) AS Job_Count_Observed,'
		Set @sqlFrom = @sqlFrom +         ' AVG(Pep.GANET_Obs) As Avg_NET, COUNT(Pep.Peptide_ID) As Cnt_NET, StDev(Pep.GANET_Obs) As StD_NET'
		Set @sqlFrom = @sqlFrom +  ' FROM DATABASE..T_Analysis_Description JobTable'
		Set @sqlFrom = @sqlFrom +       ' INNER JOIN #TmpQCJobList ON JobTable.Job = #TmpQCJobList.Job'

		Set @sqlFrom = @sqlFrom +       ' INNER JOIN DATABASE..T_Datasets DatasetTable ON JobTable.Dataset_ID = DatasetTable.Dataset_ID'
		Set @sqlFrom = @sqlFrom +       ' INNER JOIN DATABASE..T_Peptides Pep ON JobTable.Job = Pep.Job'

		If @XCorrMinimum > 0 OR @DeltaCn2Minimum > 0 OR @RankXcMaximum > 0
			Set @sqlFrom = @sqlFrom +   ' INNER JOIN DATABASE..T_Score_Sequest SS ON Pep.Peptide_ID = SS.Peptide_ID'
		
		If @FilterIDFilter > 0
			Set @sqlFrom = @sqlFrom +   ' INNER JOIN DATABASE..T_Peptide_Filter_Flags PFF ON Pep.Peptide_ID = PFF.Peptide_ID'
			
		If @DiscriminantScoreMinimum > 0 Or @PeptideProphetMinimum > 0 Or @MSGFThreshold > 0
			Set @sqlFrom = @sqlFrom +   ' INNER JOIN DATABASE..T_Score_Discriminant SD ON Pep.Peptide_ID = SD.Peptide_ID'
		
		Set @sqlFrom = @sqlFrom +  ' WHERE  Pep.Max_Obs_Area_In_Job = 1'

		-- Add the optional score filters
		If @DiscriminantScoreMinimum > 0
			Set @sqlFrom = @sqlFrom + ' AND (SD.DiscriminantScoreNorm >= ' + Convert(varchar(12), @DiscriminantScoreMinimum) + ')'
			
		-- Note: X!Tandem jobs don't have peptide prophet values, so all X!Tandem data will get excluded if @PeptideProphetMinimum is used
		If @PeptideProphetMinimum > 0
			Set @sqlFrom = @sqlFrom + ' AND (IsNull(SD.Peptide_Prophet_Probability, 0)  >= ' + Convert(varchar(12), @PeptideProphetMinimum) + ')'

		If @MSGFThreshold > 0
			Set @sqlFrom = @sqlFrom + ' AND (IsNull(SD.MSGF_SpecProb, 1) <= ' + Convert(varchar(12), @MSGFThreshold) + ')'			
		
		If @CleavageStateMinimum > 0
			Set @sqlFrom = @sqlFrom + ' AND (Pep.Cleavage_State >= ' + Convert(varchar(6), @CleavageStateMinimum) + ')'
		If @XCorrMinimum > 0
			Set @sqlFrom = @sqlFrom + ' AND (SS.XCorr >= ' + Convert(varchar(12), @XCorrMinimum) + ')'
		If @DeltaCn2Minimum > 0
			Set @sqlFrom = @sqlFrom + ' AND (SS.DeltaCn2 >= ' + Convert(varchar(12), @DeltaCn2Minimum) + ')'
		If @RankXcMaximum > 0
			Set @sqlFrom = @sqlFrom + ' AND (SS.RankXc <= ' + Convert(varchar(12), @RankXcMaximum) + ')'
		If @FilterIDFilter > 0
			Set @sqlFrom = @sqlFrom + ' AND (PFF.Filter_ID = ' + Convert(varchar(12), @FilterIDFilter) + ')'

		Set @sqlFrom = @sqlFrom + ' GROUP BY Pep.Seq_ID) AS LookupQ'

	End

	-- Define the Order By clause
	Set @sqlOrderBy = 'ORDER BY Job_Count_Observed DESC, Seq_ID'
	
	
	---------------------------------------------------
	-- Customize the columns for the given database
	---------------------------------------------------

	set @sqlFrom = replace(@sqlFrom, 'DATABASE..', '[' + @DBName + ']..')
	

	---------------------------------------------------
	-- Obtain the Sequence Occurrence Stats from the given database
	---------------------------------------------------
	
	If @returnRowCount = 'true'
	begin
		-- In order to return the row count, we wrap the sql text with Count (*) 
		-- and store the value in the Seq_ID column of #Tmp_Seq_Occurrence_Stats
		Set @sqlSelect2 = ''
		Set @sqlSelect2 = @sqlSelect2 + ' SELECT Count (*) As ResultSet_Row_Count, 0 AS Job_Count_Observed,'
		Set @sqlSelect2 = @sqlSelect2 + ' 0 AS Percent_Jobs_Observed, 0 AS Avg_NET, 0 AS Cnt_NET, 0 AS StD_NET'
		
		if @previewSql <> 0
			print @sqlInsert + @sqlSelect2 + ' FROM (' + @sqlSelect + ' ' + @sqlFrom + ') As CountQ'
		Else
			Exec (@sqlInsert + @sqlSelect2 + ' FROM (' + @sqlSelect + ' ' + @sqlFrom + ') As CountQ')
	end
	Else
	begin
		if @previewSql <> 0
			print		@sqlInsert + ' ' + @sqlSelect + ' ' + @sqlFrom + ' ' + @sqlOrderBy
		else
			Exec (		@sqlInsert + ' ' + @sqlSelect + ' ' + @sqlFrom + ' ' + @sqlOrderBy)
	end
	--	
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	Declare @UsageMessage varchar(512)
	Set @UsageMessage = Convert(varchar(9), @myRowCount) + ' rows'
	Exec PostUsageLogEntry 'ObtainSeqOccurrenceStatsWork', @DBName, @UsageMessage	

	
Done:
	return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[ObtainSeqOccurrenceStats] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[ObtainSeqOccurrenceStats] TO [MTS_DB_Lite] AS [dbo]
GO
