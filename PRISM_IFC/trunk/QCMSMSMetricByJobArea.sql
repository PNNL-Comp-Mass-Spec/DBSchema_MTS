SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[QCMSMSMetricByJobArea]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[QCMSMSMetricByJobArea]
GO

CREATE PROCEDURE dbo.QCMSMSMetricByJobArea
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
**		Auth: mem
**		Date: 08/29/2005
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
	@MeanSquareError float = 0 output
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
											@SeqIDList = @SeqIDList, @MeanSquareError = @MeanSquareError output
	--
	Declare @UsageMessage varchar(512)
	Set @UsageMessage = Convert(varchar(9), @myRowCount) + ' rows'
	Exec PostUsageLogEntry 'QCMSMSMetricByJobArea', @DBName, @UsageMessage	

	
Done:
	return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[QCMSMSMetricByJobArea]  TO [DMS_SP_User]
GO

