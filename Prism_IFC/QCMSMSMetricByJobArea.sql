/****** Object:  StoredProcedure [dbo].[QCMSMSMetricByJobArea] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE QCMSMSMetricByJobArea
/****************************************************
**
**	Desc: 
**	Uses @SeqIDList and @MetricID to return a metric value representing 
**	 area for all jobs matching the given job filters in the specified database
**  This procedure can only be used with Peptide databases
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
**			10/07/2008 mem - Added parameter @PreviewSql
**			09/22/2010 mem - Added parameter @ResultTypeFilter
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
	-- Call QCMSMSMetricByJobWork to do all the work
	---------------------------------------------------

	Exec @myError = QCMSMSMetricByJobWork	@DBName, @returnRowCount, @message output,
											@InstrumentFilter, @CampaignFilter, @ExperimentFilter, @DatasetFilter, @OrganismDBFilter,
											@DatasetDateMinimum, @DatasetDateMaximum, @JobMinimum, @JobMaximum,
											@maximumRowCount, @MetricID = 0, @UseNaturalLog = @UseNaturalLog,
											@SeqIDList = @SeqIDList, @MeanSquareError = @MeanSquareError output,
											@ResultTypeFilter = @ResultTypeFilter, @PreviewSql = @PreviewSql
	--
	Declare @UsageMessage varchar(512)
	Set @UsageMessage = Convert(varchar(9), @myRowCount) + ' rows'
	Exec PostUsageLogEntry 'QCMSMSMetricByJobArea', @DBName, @UsageMessage	

	
Done:
	return @myError

GO
GRANT EXECUTE ON [dbo].[QCMSMSMetricByJobArea] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[QCMSMSMetricByJobArea] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[QCMSMSMetricByJobArea] TO [MTS_DB_Lite] AS [dbo]
GO
