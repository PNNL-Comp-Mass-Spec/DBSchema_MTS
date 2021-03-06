/****** Object:  StoredProcedure [dbo].[QCMSMSSeqOccurrenceStats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE QCMSMSSeqOccurrenceStats
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
**	Auth:	mem
**	Date:	08/28/2005
**			11/23/2005 mem - Added brackets around @DBName as needed to allow for DBs with dashes in the name
**			03/01/2006 mem - Now calling ObtainSeqOccurrenceStats to populate #Tmp_Seq_Occurence_Stats, then returning the contents of #Tmp_Seq_Occurence_Stats
**			09/22/2010 mem - Added parameters @PeptideProphetMinimum, @MSGFThreshold, @ResultTypeFilter, and @PreviewSql
**
*****************************************************/
(
	@DBName varchar(128) = '',
	@returnRowCount varchar(32) = 'False',
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
	-- Cleanup the input parameters
	---------------------------------------------------

	-- Cleanup the True/False parameters
	Exec CleanupTrueFalseParameter @returnRowCount OUTPUT, 1

	Set @ResultTypeFilter = IsNull(@ResultTypeFilter, '')
	Set @previewSql = IsNull(@previewSql, 0)
	
	---------------------------------------------------
	-- Create temporary table #Tmp_Seq_Occurence_Stats
	---------------------------------------------------

	CREATE TABLE #Tmp_Seq_Occurence_Stats (
		Seq_ID int NOT NULL,
		Job_Count_Observed int NULL,
		Percent_Jobs_Observed real NULL,
		Avg_NET real NULL,						-- Populated by ObtainSeqOccurrenceStats, but not returned by this SP
		Cnt_NET real NULL,						-- Populated by ObtainSeqOccurrenceStats, but not returned by this SP
		StD_NET real NULL						-- Populated by ObtainSeqOccurrenceStats, but not returned by this SP
	)
	
	---------------------------------------------------
	-- Call ObtainSeqOccurrenceStats to populate #Tmp_Seq_Occurence_Stats
	---------------------------------------------------
	Exec ObtainSeqOccurrenceStats	@DBName = @DBName,
									@returnRowCount = @returnRowCount,
									@message = @message output,
									@InstrumentFilter = @InstrumentFilter,
									@CampaignFilter = @CampaignFilter,
									@ExperimentFilter = @ExperimentFilter,
									@DatasetFilter = @DatasetFilter,
									@OrganismDBFilter = @OrganismDBFilter,
									@DatasetDateMinimum = @DatasetDateMinimum,
									@DatasetDateMaximum = @DatasetDateMaximum,
									@JobMinimum = @JobMinimum,
									@JobMaximum = @JobMaximum,
									@DiscriminantScoreMinimum = @DiscriminantScoreMinimum,
									@CleavageStateMinimum = @CleavageStateMinimum,
									@XCorrMinimum = @XCorrMinimum,
									@DeltaCn2Minimum = @DeltaCn2Minimum,
									@RankXcMaximum = @RankXcMaximum,
									@FilterIDFilter = @FilterIDFilter,
									@PMTQualityScoreMinimum = @PMTQualityScoreMinimum,
									@maximumRowCount = @maximumRowCount,
									@PeptideProphetMinimum = @PeptideProphetMinimum,
									@MSGFThreshold = @MSGFThreshold,									
									@ResultTypeFilter = @ResultTypeFilter, 
									@PreviewSql = @PreviewSql

	
	---------------------------------------------------
	-- Obtain the Sequence Occurrence Stats from the given database
	---------------------------------------------------
	
	If @returnRowCount = 'true'
	Begin
		-- In order to return the row count, we wrap the sql text with Count (*) 
		-- and exclude the @sqlOrderBy text from the sql statement
		SELECT Seq_ID AS ResultSet_Row_Count 
		FROM #Tmp_Seq_Occurence_Stats
	End
	Else
	Begin
		SELECT Seq_ID, Job_Count_Observed, Percent_Jobs_Observed
		FROM #Tmp_Seq_Occurence_Stats
		ORDER BY Job_Count_Observed DESC, Seq_ID
	End
	--	
	SELECT @myError = @@error, @myRowCount = @@rowcount

	
	Declare @UsageMessage varchar(512)
	Set @UsageMessage = Convert(varchar(9), @myRowCount) + ' rows'
	Exec PostUsageLogEntry 'QCMSMSSeqOccurrenceStats', @DBName, @UsageMessage	
	
Done:
	return @myError

GO
GRANT EXECUTE ON [dbo].[QCMSMSSeqOccurrenceStats] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[QCMSMSSeqOccurrenceStats] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[QCMSMSSeqOccurrenceStats] TO [MTS_DB_Lite] AS [dbo]
GO
