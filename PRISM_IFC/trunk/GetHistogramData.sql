/****** Object:  StoredProcedure [dbo].[GetHistogramData] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.GetHistogramData
/****************************************************
**
**	Desc:	Calls GenerateHistogram in the given database to return histogrammed data
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**	  @DBName				-- PMT Tag database name
**	  @message				-- Status/error message output
**
**	Auth:	mem
**	Date:	03/16/2006
**
*****************************************************/

(
	@DBName varchar(128) = '',					-- Must be a PMT Tag database, not a peptide database
	@message varchar(512) = '' output,
	@mode smallint = 0,							-- Mode 0 means GANET, 
												-- Mode 1 means Discriminant Score, 
												-- Mode 2 means XCorr, 
												-- Mode 3 means Peptide Length
												-- Mode 4 means PMT Quality Score
												-- Mode 5 means Hyperscore
												-- Mode 6 means Log EValue

	@PreviewSql tinyint = 0,					-- When 1, then returns the Sql that is generated, rather than the data (ignored if @HistogramCacheIDOverride > 0)
	@EstimateExecutionTime tinyint = 0,			-- When 1, then returns an estimate of the time the query will take to execute (in seconds) based on data in T_Histogram_Cache (ignored if @HistogramCacheIDOverride > 0)
	@ForceUpdate tinyint = 0,
	@HistogramCacheIDOverride int = 0,			-- Set to a positive value to recompute the histogram for a given Histogram Cache ID; if the data is unchanged, then updates the entry's date; if the data is changed, then makes a new identical entry
	@HistogramCacheID int = 0 output,

	@ScoreMinimum real = 0,						-- If @ScoreMinimum >= @ScoreMaximum then the score ranges are auto-defined
	@ScoreMaximum real = 0,
	@BinCount int = 100,
	@DiscriminantScoreMinimum real = 0,
	@PMTQualityScoreMinimum real = 0,
	@ChargeStateFilter smallint = 0,			-- If 0, then matches all charge states; set to a value > 0 to filter on a specific charge state
	@UseDistinctPeptides tinyint = 0,			-- When 0 then all peptide observations are used, when 1 then only distinct peptide observations are used
	@ResultTypeFilter varchar(32) = ''			-- Can be blank, Peptide_Hit, or XT_Peptide_Hit
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0
	
	set @message = ''
	set @HistogramCacheID = 0
	
	declare @stmt nvarchar(1024)
	declare @params nvarchar(1024)
	declare @result int

	---------------------------------------------------
	-- Validate that DB exists on this server, determine its type,
	-- and look up its schema version
	---------------------------------------------------

	Declare @DBType tinyint				-- 1 if PMT Tag DB, 2 if Peptide DB
	Declare @DBSchemaVersion real
	
	Set @DBType = 0
	Set @DBSchemaVersion = 1
	
	Exec @myError = GetDBTypeAndSchemaVersion @DBName, @DBType OUTPUT, @DBSchemaVersion OUTPUT, @message = @message OUTPUT

	-- Make sure the type is 1 and that no errors occurred
	If @DBType = 0 Or @myError <> 0
	Begin
		If @myError = 0
			Set @myError = 20000

		If Len(@message) = 0
			Set @message = 'Database not found on this server: ' + @DBName
		Goto Done
	End
	Else
	If @DBType <> 1
	Begin
		Set @myError = 20001
		Set @message = 'Database ' + @DBName + ' is not a PMT Tag DB and is therefore not appropriate for this procedure'
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
	-- Exec CleanupTrueFalseParameter @returnRowCount OUTPUT, 1

	---------------------------------------------------
	-- Call GenerateHistogram in the given database
	---------------------------------------------------

	set @stmt = N'exec [' + @DBName + N'].dbo.GenerateHistogram @mode, @PreviewSql, @EstimateExecutionTime, @ForceUpdate, @HistogramCacheIDOverride, @HistogramCacheID, @message, @ScoreMinimum, @ScoreMaximum, @BinCount, @DiscriminantScoreMinimum, @PMTQualityScoreMinimum, @ChargeStateFilter, @UseDistinctPeptides, @ResultTypeFilter'
	
	set @params = N'@mode smallint, @PreviewSql tinyint, @EstimateExecutionTime tinyint, @ForceUpdate tinyint, @HistogramCacheIDOverride int, @HistogramCacheID int output, @message varchar(255) output, @ScoreMinimum real, @ScoreMaximum real, @BinCount int, @DiscriminantScoreMinimum real, @PMTQualityScoreMinimum real, @ChargeStateFilter smallint, @UseDistinctPeptides tinyint, @ResultTypeFilter varchar(32)'
	
	print @stmt
	print @params
	
	exec @result = sp_executesql @stmt, @params, @mode = @mode, @PreviewSql = @PreviewSql, @EstimateExecutionTime = @EstimateExecutionTime, @ForceUpdate = @ForceUpdate, @HistogramCacheIDOverride = @HistogramCacheIDOverride, @HistogramCacheID = @HistogramCacheID output, @message = @message output, @ScoreMinimum = @ScoreMinimum,  @ScoreMaximum = @ScoreMaximum, @BinCount = @BinCount, @DiscriminantScoreMinimum = @DiscriminantScoreMinimum, @PMTQualityScoreMinimum = @PMTQualityScoreMinimum, @ChargeStateFilter = @ChargeStateFilter, @UseDistinctPeptides = @UseDistinctPeptides, @ResultTypeFilter = @ResultTypeFilter

	--	
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	Declare @UsageMessage varchar(512)
	Set @UsageMessage = Convert(varchar(9), @myRowCount) + ' rows'
	Exec PostUsageLogEntry 'GetHistogramData', @DBName, @UsageMessage	
	
Done:
	return @myError

GO
GRANT EXECUTE ON [dbo].[GetHistogramData] TO [DMS_SP_User]
GO
