SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[QCMSMSSeqOccurrenceStats]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[QCMSMSSeqOccurrenceStats]
GO

CREATE PROCEDURE dbo.QCMSMSSeqOccurrenceStats
/****************************************************
**
**	Desc: 
**	Returns the occurrence rates for the sequences matching the given filters and found in the given jobs
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**	  @DBName				-- Peptide or PMT Tag database name
**	  @returnRowCount		-- Set to True to return a row count; False to return the results
**	  @message				-- Status/error message output
**
**		Auth:	mem
**		Date:	08/28/2005
**			    11/23/2005 mem - Added brackets around @DBName as needed to allow for DBs with dashes in the name
**
*****************************************************/
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
	
	@DiscriminantScoreMinimum real = 0.75,			-- Ignored if 0
	@CleavageStateMinimum tinyint = 0,				-- Ignored if 0
	@XCorrMinimum real = 0,							-- Ignored if 0
	@DeltaCn2Minimum real = 0,						-- Ignored if 0
	@RankXcMaximum smallint = 0,					-- Ignored if 0

	@FilterIDFilter int = 117,						-- Ignored if 0; only appropriate for Peptide DBs
	@PMTQualityScoreMinimum int = 1,				-- Ignored if 0; only appropriate for PMT Tag DBs
	
	@maximumRowCount int = 255						-- 0 means to return all rows; defaults to 255 to limit the number of sequences returned

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
											@JobMinimum, @JobMaximum, 0
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
	declare @sqlSelect varchar(2048)
	declare @sqlFrom varchar(2048)
	declare @sqlOrderBy varchar(2048)


	-- Construct the SELECT clause, optionally limiting the number of rows
	Set @sqlSelect = ''
	If IsNull(@maximumRowCount,-1) <= 0
		Set @sqlSelect = @sqlSelect + ' SELECT'
	Else
		Set @sqlSelect = @sqlSelect + ' SELECT TOP ' + Convert(varchar(9), @maximumRowCount)

	-- For each sequence, return the number of jobs it was observed in and the percentage of the total jobs containing the sequence
	Set @sqlSelect = @sqlSelect + ' Seq_ID, '
	Set @sqlSelect = @sqlSelect + ' Job_Count_Observed, Round(Job_Count_Observed / Convert(real, ' + Convert(varchar(9), @JobCount) + ') * 100, 2) AS Percent_Jobs_Observed'


	-- Construct the From clause
	
	Set @sqlFrom = 'FROM'
	
	If @DBType = 1
	Begin
		-- PMT Tag DB
		Set @sqlFrom = @sqlFrom + ' (SELECT Pep.Seq_ID, COUNT(DISTINCT Pep.Analysis_ID) AS Job_Count_Observed'
		Set @sqlFrom = @sqlFrom +  ' FROM DATABASE..T_Analysis_Description JobTable'
		Set @sqlFrom = @sqlFrom +       ' INNER JOIN #TmpQCJobList ON JobTable.Job = #TmpQCJobList.Job'
		Set @sqlFrom = @sqlFrom +       ' INNER JOIN DATABASE..T_Peptides Pep ON JobTable.Job = Pep.Analysis_ID'

		If @XCorrMinimum > 0 OR @DeltaCn2Minimum > 0 OR @RankXcMaximum > 0
			Set @sqlFrom = @sqlFrom +   ' INNER JOIN DATABASE..T_Score_Sequest SS ON Pep.Peptide_ID = SS.Peptide_ID'
		
		If @PMTQualityScoreMinimum > 0
			Set @sqlFrom = @sqlFrom +   ' INNER JOIN DATABASE..T_Mass_Tags MT ON Pep.Mass_Tag_ID = MT.Mass_Tag_ID'
			
		If @DiscriminantScoreMinimum > 0
			Set @sqlFrom = @sqlFrom +   ' INNER JOIN DATABASE..T_Score_Discriminant SD ON Pep.Peptide_ID = SD.Peptide_ID'
		
		If @CleavageStateMinimum > 0
			Set @sqlFrom = @sqlFrom +   ' INNER JOIN DATABASE..T_Mass_Tag_to_Protein_Map MTPM ON Pep.Mass_Tag_ID = MTPM.Mass_Tag_ID'
			
		Set @sqlFrom = @sqlFrom +  ' WHERE  JobTable.Job = #TmpQCJobList.Job'		-- This is always true, but is included to guarantee we have a where clause

		-- Add the optional score filters
		If @DiscriminantScoreMinimum > 0
			Set @sqlFrom = @sqlFrom + ' AND (SD.DiscriminantScoreNorm >= ' + Convert(varchar(12), @DiscriminantScoreMinimum) + ')'
		If @CleavageStateMinimum > 0
			Set @sqlFrom = @sqlFrom + ' AND (MTPM.Cleavage_State >= ' + Convert(varchar(6), @CleavageStateMinimum) + ')'
		If @XCorrMinimum > 0
			Set @sqlFrom = @sqlFrom + ' AND (SS.XCorr >= ' + Convert(varchar(12), @XCorrMinimum) + ')'
		If @DeltaCn2Minimum > 0
			Set @sqlFrom = @sqlFrom + ' AND (SS.DeltaCn2 >= ' + Convert(varchar(12), @DeltaCn2Minimum) + ')'
		If @RankXcMaximum > 0
			Set @sqlFrom = @sqlFrom + ' AND (SS.RankXc <= ' + Convert(varchar(12), @RankXcMaximum) + ')'
		If @PMTQualityScoreMinimum > 0
			Set @sqlFrom = @sqlFrom + ' AND (MT.PMT_Quality_Score >= ' + Convert(varchar(12), @PMTQualityScoreMinimum) + ')'

		-- Note: We'll add additional where clause elements later on
		Set @sqlFrom = @sqlFrom + ' GROUP BY Pep.Seq_ID) AS LookupQ'

	End
	Else
	Begin
		-- Peptide DB
		Set @sqlFrom = @sqlFrom + ' (SELECT Pep.Seq_ID, COUNT(DISTINCT Pep.Analysis_ID) AS Job_Count_Observed'
		Set @sqlFrom = @sqlFrom +  ' FROM DATABASE..T_Analysis_Description JobTable'
		Set @sqlFrom = @sqlFrom +       ' INNER JOIN #TmpQCJobList ON JobTable.Job = #TmpQCJobList.Job'

		Set @sqlFrom = @sqlFrom +       ' INNER JOIN DATABASE..T_Datasets DatasetTable ON JobTable.Dataset_ID = DatasetTable.Dataset_ID'
		Set @sqlFrom = @sqlFrom +       ' INNER JOIN DATABASE..T_Peptides Pep ON JobTable.Job = Pep.Analysis_ID'

		If @XCorrMinimum > 0 OR @DeltaCn2Minimum > 0 OR @RankXcMaximum > 0
			Set @sqlFrom = @sqlFrom +   ' INNER JOIN DATABASE..T_Score_Sequest SS ON Pep.Peptide_ID = SS.Peptide_ID'
		
		If @FilterIDFilter > 0
			Set @sqlFrom = @sqlFrom +   ' INNER JOIN DATABASE..T_Peptide_Filter_Flags PFF ON Pep.Peptide_ID = PFF.Peptide_ID'
			
		If @DiscriminantScoreMinimum > 0
			Set @sqlFrom = @sqlFrom +   ' INNER JOIN DATABASE..T_Score_Discriminant SD ON Pep.Peptide_ID = SD.Peptide_ID'
		
		If @CleavageStateMinimum > 0
			Set @sqlFrom = @sqlFrom +   ' INNER JOIN DATABASE..T_Peptide_to_Protein_Map PPM ON Pep.Peptide_ID = PPM.Peptide_ID'
			
		Set @sqlFrom = @sqlFrom +  ' WHERE  JobTable.Job = #TmpQCJobList.Job'		-- This is always true, but is included to guarantee we have a where clause

		-- Add the optional score filters
		If @DiscriminantScoreMinimum > 0
			Set @sqlFrom = @sqlFrom + ' AND (SD.DiscriminantScoreNorm >= ' + Convert(varchar(12), @DiscriminantScoreMinimum) + ')'
		If @CleavageStateMinimum > 0
			Set @sqlFrom = @sqlFrom + ' AND (PPM.Cleavage_State >= ' + Convert(varchar(6), @CleavageStateMinimum) + ')'
		If @XCorrMinimum > 0
			Set @sqlFrom = @sqlFrom + ' AND (SS.XCorr >= ' + Convert(varchar(12), @XCorrMinimum) + ')'
		If @DeltaCn2Minimum > 0
			Set @sqlFrom = @sqlFrom + ' AND (SS.DeltaCn2 >= ' + Convert(varchar(12), @DeltaCn2Minimum) + ')'
		If @RankXcMaximum > 0
			Set @sqlFrom = @sqlFrom + ' AND (SS.RankXc <= ' + Convert(varchar(12), @RankXcMaximum) + ')'
		If @FilterIDFilter > 0
			Set @sqlFrom = @sqlFrom + ' AND (PFF.Filter_ID = ' + Convert(varchar(12), @FilterIDFilter) + ')'

		-- Note: We'll add additional where clause elements later on
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
		-- and exclude the @sqlOrderBy text from the sql statement
		Exec ('SELECT Count (*) As ResultSet_Row_Count FROM (' + @sqlSelect + ' ' + @sqlFrom + ') As CountQ')
	end
	Else
	begin
		--print													 @sqlSelect + ' ' + @sqlFrom + ' ' + @sqlOrderBy
		Exec (													 @sqlSelect + ' ' + @sqlFrom + ' ' + @sqlOrderBy)
	end
	--	
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	Declare @UsageMessage varchar(512)
	Set @UsageMessage = Convert(varchar(9), @myRowCount) + ' rows'
	Exec PostUsageLogEntry 'QCMSMSSeqOccurrenceStats', @DBName, @UsageMessage	

	
Done:
	return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[QCMSMSSeqOccurrenceStats]  TO [DMS_SP_User]
GO

