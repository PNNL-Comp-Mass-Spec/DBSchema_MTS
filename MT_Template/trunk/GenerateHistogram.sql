/****** Object:  StoredProcedure [dbo].[GenerateHistogram] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.GenerateHistogram
/****************************************************
**
**	Desc: 
**		Generates a histogram for the GANET data,
**		Discriminant Score data, or XCorr data
**
**	Return values: 0 if no error; otherwise error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	01/07/2005
**			07/25/2005 mem - Added option to histogram peptide length data
**						   - Added option to filter the peptides on minimum discriminant score
**						   - Added option to return stats for distinct or non-distinct peptides
**			12/11/2005 mem - Added two new modes for XTandem data: Mode 4 for Hyperscore and Mode 5 for Log_EValue
**						   - Added parameter @ResultTypeFilter
**			01/18/2006 mem - Fixed bug involving determination of whether @BinSize is a power of 10
**			03/14/2006 mem - Now caching results in tables T_Histogram_Cache and T_Histogram_Cache_Data
**						   - Also, added mode 4 for PMT Quality Score
**			03/15/2006 mem - Now auto defining the bin count if @BinCount is less than 1
**			03/16/2006 mem - Updated PMT Quality Score histogram to use >= threshold rather than equals threshold; note that PMT Quality Score queries don't use @BinCount
**						   - Optimized the queries to run faster if @UseDistinctPeptides = 1 and @ResultTypeFilter = ''
**						   - Added parameter @ChargeStateFilter and rearranged the parameter order
**			03/19/2006 mem - Now using column Query_Speed_Category in T_Histogram_Cache
**			03/26/2006 mem - Now including the input parameter values when posting an error to T_Log_Entries
**			04/13/2006 mem - Fixed query bug involving NET histogram generation when @ResultTypeFilter <> ''
**    
*****************************************************/
(
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
	@message varchar(255) = '' output,

	@ScoreMinimum real = 0,						-- If @ScoreMinimum >= @ScoreMaximum then the score ranges are auto-defined
	@ScoreMaximum real = 0,
	@BinCount int = 0,
	@DiscriminantScoreMinimum real = 0,
	@PMTQualityScoreMinimum real = 0,
	@ChargeStateFilter smallint = 0,			-- If 0, then matches all charge states; set to a value > 0 to filter on a specific charge state
	@UseDistinctPeptides tinyint = 1,			-- When 0 then all peptide observations are used, when 1 then only distinct peptide observations are used
	@ResultTypeFilter varchar(32) = ''			-- Can be blank, Peptide_Hit, or XT_Peptide_Hit
)
AS
	set nocount on

	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Declare @Iteration int
	Declare @ScoreMinStart float
	Declare @BinSize float
	
	Declare @Sql varchar(8000)
	Declare @FromSql varchar(1024)
	Declare @BinSql varchar(8000)
	Declare @SqlFromCache varchar(1024)
	
	Declare @BinField varchar(128)
	Declare @DigitsOfPrecisionForRound tinyint
	Set @DigitsOfPrecisionForRound = 5

	Declare @ScoreMinimumInput real
	Declare @ScoreMaximumInput real
	
	Declare @CachedDataExists tinyint			-- 0 = Does not exist, 1 = Exists, 2 = Defined in T_Histogram_Cache but no data in T_Histogram_Cache_Data
	Declare @HistogramCacheState smallint
	Declare @ResultCount int
	Declare @MatchRowCount int
	
	Declare @LoopCount int
	Declare @CacheStateMinimum tinyint
	Declare @CacheStateMaximum tinyint
	Declare @AutoUpdate tinyint
	Set @AutoUpdate = 0

	Declare @QuerySpeedCategory smallint	
	Set @QuerySpeedCategory = 0
	
	Declare @ExecutionStartDate datetime
	Declare @ExecutionTimeSeconds real
	Declare @ExecutionTimeAvg real
	Declare @ExecutionTimeStDev real
	Declare @InputParams varchar(512)
	
	-----------------------------------------------------
	-- Validate the inputs
	-----------------------------------------------------
	Set @mode = IsNull(@mode, 0)
	If @mode < 0 Or @mode > 6
		Set @mode = 0

	Set @ScoreMinimum = IsNull(@ScoreMinimum, 0)
	Set @ScoreMaximum = IsNull(@ScoreMaximum, 0)
	Set @BinCount = IsNull(@BinCount, 100)

	Set @DiscriminantScoreMinimum = IsNull(@DiscriminantScoreMinimum, 0)
	Set @PMTQualityScoreMinimum = IsNull(@PMTQualityScoreMinimum, 0)
	Set @ChargeStateFilter = IsNull(@ChargeStateFilter, 0)
	Set @UseDistinctPeptides = IsNull(@UseDistinctPeptides, 0)
	Set @ResultTypeFilter = IsNull(@ResultTypeFilter, '')

	Set @PreviewSql = IsNull(@PreviewSql, 0)
	Set @EstimateExecutionTime = IsNull(@EstimateExecutionTime, 0)
	Set @ForceUpdate = IsNull(@ForceUpdate, 0)
	Set @HistogramCacheIDOverride = IsNull(@HistogramCacheIDOverride, 0)

	Set @HistogramCacheID = 0	
	Set @message = ''

	If @HistogramCacheIDOverride > 0
	Begin
		-----------------------------------------------------
		-- Lookup the settings for Histogram_Cache_ID @HistogramCacheIDOverride
		-----------------------------------------------------
		
		SELECT	@mode = Histogram_Mode,
				@ScoreMinimum = Score_Minimum,
				@ScoreMaximum = Score_Maximum,
				@BinCount = Bin_Count,
				@DiscriminantScoreMinimum = Discriminant_Score_Minimum,
				@PMTQualityScoreMinimum = PMT_Quality_Score_Minimum,
				@ChargeStateFilter = Charge_State_Filter,
				@UseDistinctPeptides = Use_Distinct_Peptides,
				@ResultTypeFilter = Result_Type_Filter,
				@AutoUpdate = Auto_Update
		FROM T_Histogram_Cache
		WHERE Histogram_Cache_ID = @HistogramCacheIDOverride
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		If @myError <> 0
		Begin
			Set @message = 'Error finding Cache ID ' + Convert(varchar(19), @HistogramCacheIDOverride) + ' in T_Histogram_Cache: error number = ' + Convert(varchar(19), @myError)
			EXEC PostLogEntry 'Error', @message, 'GenerateHistogram'
			Goto Done
		End

		If @myRowCount <> 1
		Begin
			Set @message = 'Cache ID ' + Convert(varchar(19), @HistogramCacheIDOverride) + ' was not found in T_Histogram_Cache'
			Goto Done
		End
	
		Set @PreviewSql = 0
	End
	
	-----------------------------------------------------
	-- Populate @ScoreMinimumInput and @ScoreMaximumInput
	-----------------------------------------------------
	Set @ScoreMinimumInput = @ScoreMinimum
	Set @ScoreMaximumInput = @ScoreMaximum
	
	-----------------------------------------------------
	-- Construct the Sql based on @mode
	-----------------------------------------------------
	if @mode = 0
	Begin
		-- NET Histogram
		Set @BinField = 'NET'
		Set @FromSql = ''
		Set @FromSql = @FromSql +     ' FROM ('
		If @UseDistinctPeptides = 0
		Begin
			Set @QuerySpeedCategory = 1
			
			Set @FromSql = @FromSql + '  SELECT P.GANET_Obs AS Value'
			Set @Fromsql = @FromSql + '  FROM T_Peptides P'
			Set @FromSql = @FromSql +     ' INNER JOIN T_Score_Discriminant SD ON P.Peptide_ID = SD.Peptide_ID'
			If Len(@ResultTypeFilter) > 0
				Set @FromSql = @FromSql + ' INNER JOIN T_Analysis_Description TAD ON P.Analysis_ID = TAD.Job'
			If @PMTQualityScoreMinimum > 0
				Set @FromSql = @FromSql + ' INNER JOIN T_Mass_Tags MT ON P.Mass_Tag_ID = MT.Mass_Tag_ID'
			
			Set @FromSql = @FromSql + '  WHERE NOT P.GANET_Obs Is Null'
			If Len(@ResultTypeFilter) > 0
				Set @FromSql = @FromSql + ' AND TAD.ResultType = ''' + @ResultTypeFilter + ''''
			If @DiscriminantScoreMinimum > 0
				Set @FromSql = @FromSql + ' AND SD.DiscriminantScoreNorm >= ' + Convert(varchar(12), @DiscriminantScoreMinimum)
			If @PMTQualityScoreMinimum > 0
				Set @FromSql = @FromSql + ' AND MT.PMT_Quality_Score >= ' + Convert(varchar(12), @PMTQualityScoreMinimum)
			If @ChargeStateFilter > 0
			Begin
				Set @QuerySpeedCategory = 2
				Set @FromSql = @FromSql + ' AND P.Charge_State = ' + Convert(varchar(6), @ChargeStateFilter)
			End

		End
		Else
		Begin
			Set @QuerySpeedCategory = 0
			
			Set @FromSql = @FromSql + '  SELECT Avg_GANET AS Value'
			Set @FromSql = @FromSql + '  FROM T_Mass_Tags_NET MTN'
			Set @FromSql = @FromSql +     ' INNER JOIN T_Mass_Tags MT ON MT.Mass_Tag_ID = MTN.Mass_Tag_ID'
			If Len(@ResultTypeFilter) > 0 Or @ChargeStateFilter > 0
			Begin
				Set @QuerySpeedCategory = 1
				
				Set @FromSql = @FromSql + ' INNER JOIN T_Peptides P ON MT.Mass_Tag_ID = P.Mass_Tag_ID'
				If Len(@ResultTypeFilter) > 0
				 Set @FromSql = @FromSql + ' INNER JOIN T_Analysis_Description TAD ON P.Analysis_ID = TAD.Job'
			End

			Set @FromSql = @FromSql + ' WHERE NOT MTN.Avg_GANET Is Null'
			If Len(@ResultTypeFilter) > 0
				Set @FromSql = @FromSql + ' AND TAD.ResultType = ''' + @ResultTypeFilter + ''''
			If @DiscriminantScoreMinimum > 0
				Set @FromSql = @FromSql + ' AND MT.High_Discriminant_Score >= ' + Convert(varchar(12), @DiscriminantScoreMinimum)
			If @PMTQualityScoreMinimum > 0
				Set @FromSql = @FromSql + ' AND MT.PMT_Quality_Score >= ' + Convert(varchar(12), @PMTQualityScoreMinimum)
			If @ChargeStateFilter > 0
			Begin
				Set @QuerySpeedCategory = 2
				Set @FromSql = @FromSql + ' AND P.Charge_State = ' + Convert(varchar(6), @ChargeStateFilter)
			End
			
			Set @FromSql = @FromSql + ' GROUP BY MT.Mass_Tag_ID, MTN.Avg_GANET'
		End
		
		Set @FromSql = @FromSql + ') LookupQ '
		
		If @ScoreMinimum >= @ScoreMaximum
		Begin
			Set @ScoreMinimum = 0
			Set @ScoreMaximum = 1
		End

		If @BinCount < 1
			Set @BinCount = 100
	End
	
	if @mode = 1
	Begin
		-- Discriminant Score Histogram
		Set @BinField = 'Discriminant_Score'
		Set @FromSql = ''
		Set @FromSql = @FromSql +     ' FROM ('
		
		If @UseDistinctPeptides <> 0 And Len(@ResultTypeFilter) = 0 And @ChargeStateFilter = 0
		Begin
			-- Fast query that only uses T_Mass_Tags
			Set @QuerySpeedCategory = 0
			
			Set @FromSql = @FromSql +  ' SELECT MT.High_Discriminant_Score AS Value'
			Set @FromSql = @FromSql +  ' FROM T_Mass_Tags MT'
			Set @FromSql = @FromSql +  ' WHERE NOT MT.High_Discriminant_Score Is Null'
			
			If @DiscriminantScoreMinimum > 0
				Set @FromSql = @FromSql + ' AND MT.High_Discriminant_Score >= ' + Convert(varchar(12), @DiscriminantScoreMinimum)
			If @PMTQualityScoreMinimum > 0
				Set @FromSql = @FromSql + ' AND MT.PMT_Quality_Score >= ' + Convert(varchar(12), @PMTQualityScoreMinimum)
		End
		Else
		Begin
			Set @QuerySpeedCategory = 1

			If @UseDistinctPeptides = 0
				Set @FromSql = @FromSql + ' SELECT SD.DiscriminantScoreNorm AS Value'
			Else
				Set @FromSql = @FromSql + ' SELECT MAX(SD.DiscriminantScoreNorm) AS Value'
			
			Set @Fromsql = @FromSql +     ' FROM T_Peptides P '
			Set @FromSql = @FromSql +     ' INNER JOIN T_Score_Discriminant SD ON P.Peptide_ID = SD.Peptide_ID'
			If Len(@ResultTypeFilter) > 0
				Set @FromSql = @FromSql + ' INNER JOIN T_Analysis_Description TAD ON P.Analysis_ID = TAD.Job'
			If @PMTQualityScoreMinimum > 0
				Set @FromSql = @FromSql + ' INNER JOIN T_Mass_Tags MT ON P.Mass_Tag_ID = MT.Mass_Tag_ID'

			Set @FromSql = @FromSql +     ' WHERE NOT SD.DiscriminantScoreNorm Is Null'
			If Len(@ResultTypeFilter) > 0
				Set @FromSql = @FromSql + ' AND TAD.ResultType = ''' + @ResultTypeFilter + ''''
			If @DiscriminantScoreMinimum > 0
				Set @FromSql = @FromSql + ' AND SD.DiscriminantScoreNorm >= ' + Convert(varchar(12), @DiscriminantScoreMinimum)
			If @PMTQualityScoreMinimum > 0
				Set @FromSql = @FromSql + ' AND MT.PMT_Quality_Score >= ' + Convert(varchar(12), @PMTQualityScoreMinimum)
			If @ChargeStateFilter > 0
			Begin
				Set @QuerySpeedCategory = 2
				Set @FromSql = @FromSql + ' AND P.Charge_State = ' + Convert(varchar(6), @ChargeStateFilter)
			End
			
			If @UseDistinctPeptides <> 0
				Set @FromSql = @FromSql + ' GROUP BY P.Mass_Tag_ID'
		End

		Set @FromSql = @FromSql + ') LookupQ '

		If @ScoreMinimum >= @ScoreMaximum
		Begin
			Set @ScoreMinimum = 0
			Set @ScoreMaximum = 1
		End
		
		If @BinCount < 1
			Set @BinCount = 100
	End
	
	if @mode = 2
	Begin
		-- Sequest XCorr Histogram
		Set @BinField = 'XCorr'
		Set @FromSql = ''
		Set @FromSql = @FromSql +     ' FROM ('

		If @UseDistinctPeptides <> 0 And Len(@ResultTypeFilter) = 0 And @ChargeStateFilter = 0
		Begin
			-- Fast query that only uses T_Mass_Tags
			Set @QuerySpeedCategory = 0
			
			Set @FromSql = @FromSql +  ' SELECT MT.High_Normalized_Score AS Value'
			Set @FromSql = @FromSql +  ' FROM T_Mass_Tags MT'
			Set @FromSql = @FromSql +  ' WHERE NOT MT.High_Normalized_Score Is Null'
			
			If @DiscriminantScoreMinimum > 0
				Set @FromSql = @FromSql + ' AND MT.High_Discriminant_Score >= ' + Convert(varchar(12), @DiscriminantScoreMinimum)
			If @PMTQualityScoreMinimum > 0
				Set @FromSql = @FromSql + ' AND MT.PMT_Quality_Score >= ' + Convert(varchar(12), @PMTQualityScoreMinimum)
		End
		Else
		Begin
			Set @QuerySpeedCategory = 1
			
			If @UseDistinctPeptides = 0
				Set @FromSql = @FromSql + '  SELECT SS.XCorr AS Value'
			Else
				Set @FromSql = @FromSql + '  SELECT MAX(SS.XCorr) AS Value'

			Set @FromSql = @FromSql + '  FROM T_Peptides P'
			Set @FromSql = @FromSql +     ' INNER JOIN T_Score_Sequest SS ON P.Peptide_ID = SS.Peptide_ID'
			If @DiscriminantScoreMinimum > 0
				Set @FromSql = @FromSql + ' INNER JOIN T_Score_Discriminant SD ON P.Peptide_ID = SD.Peptide_ID'
			If Len(@ResultTypeFilter) > 0
				Set @FromSql = @FromSql + ' INNER JOIN T_Analysis_Description TAD ON P.Analysis_ID = TAD.Job'
			If @PMTQualityScoreMinimum > 0
				Set @FromSql = @FromSql + ' INNER JOIN T_Mass_Tags MT ON P.Mass_Tag_ID = MT.Mass_Tag_ID'

			Set @FromSql = @FromSql +  ' WHERE NOT SS.XCorr Is Null'
			If Len(@ResultTypeFilter) > 0
				Set @FromSql = @FromSql + ' AND TAD.ResultType = ''' + @ResultTypeFilter + ''''
			If @DiscriminantScoreMinimum > 0
				Set @FromSql = @FromSql + ' AND SD.DiscriminantScoreNorm >= ' + Convert(varchar(12), @DiscriminantScoreMinimum)
			If @PMTQualityScoreMinimum > 0
				Set @FromSql = @FromSql + ' AND MT.PMT_Quality_Score >= ' + Convert(varchar(12), @PMTQualityScoreMinimum)
			If @ChargeStateFilter > 0
			Begin
				Set @QuerySpeedCategory = 2
				Set @FromSql = @FromSql + ' AND P.Charge_State = ' + Convert(varchar(6), @ChargeStateFilter)
			End

			If @UseDistinctPeptides <> 0
				Set @FromSql = @FromSql + ' GROUP BY P.Mass_Tag_ID'
		End
		
		Set @FromSql = @FromSql + ') LookupQ '

		If @ScoreMinimum >= @ScoreMaximum
		Begin
			Set @ScoreMinimum = 0
			Set @ScoreMaximum = 10
		End

		If @BinCount < 1
			Set @BinCount = 10
	End

	if @mode = 3
	Begin
		-- Peptide Length Histogram
		Set @BinField = 'Peptide_Length'
		Set @FromSql = ''
		Set @FromSql = @FromSql +     ' FROM ('

		If @UseDistinctPeptides <> 0 And Len(@ResultTypeFilter) = 0 And @ChargeStateFilter = 0
		Begin
			-- Fast query that only uses T_Mass_Tags
			Set @QuerySpeedCategory = 0
			
			Set @FromSql = @FromSql +  ' SELECT Len(MT.Peptide) AS Value'
			Set @FromSql = @FromSql +  ' FROM T_Mass_Tags MT'
			Set @FromSql = @FromSql +  ' WHERE NOT MT.Peptide Is Null'
			
			If @DiscriminantScoreMinimum > 0
				Set @FromSql = @FromSql + ' AND MT.High_Discriminant_Score >= ' + Convert(varchar(12), @DiscriminantScoreMinimum)
			If @PMTQualityScoreMinimum > 0
				Set @FromSql = @FromSql + ' AND MT.PMT_Quality_Score >= ' + Convert(varchar(12), @PMTQualityScoreMinimum)
		End
		Else
		Begin
			Set @QuerySpeedCategory = 1
			
			If @UseDistinctPeptides = 0
				Set @FromSql = @FromSql + '  SELECT Len(MT.Peptide) AS Value'
			Else
				Set @FromSql = @FromSql + '  SELECT MAX(Len(MT.Peptide)) AS Value'

			Set @FromSql = @FromSql + '  FROM T_Peptides P'
			Set @FromSql = @FromSql +     ' INNER JOIN T_Mass_Tags MT ON P.Mass_Tag_ID = MT.Mass_Tag_ID'
			If @DiscriminantScoreMinimum > 0
				Set @FromSql = @FromSql + ' INNER JOIN T_Score_Discriminant SD ON P.Peptide_ID = SD.Peptide_ID'
			If Len(@ResultTypeFilter) > 0
				Set @FromSql = @FromSql + ' INNER JOIN T_Analysis_Description TAD ON P.Analysis_ID = TAD.Job'

			Set @FromSql = @FromSql +  ' WHERE NOT MT.Peptide Is Null'
			If Len(@ResultTypeFilter) > 0
				Set @FromSql = @FromSql + ' AND TAD.ResultType = ''' + @ResultTypeFilter + ''''
			If @DiscriminantScoreMinimum > 0
				Set @FromSql = @FromSql + ' AND SD.DiscriminantScoreNorm >= ' + Convert(varchar(12), @DiscriminantScoreMinimum)
			If @PMTQualityScoreMinimum > 0
				Set @FromSql = @FromSql + ' AND MT.PMT_Quality_Score >= ' + Convert(varchar(12), @PMTQualityScoreMinimum)
			If @ChargeStateFilter > 0
			Begin
				Set @QuerySpeedCategory = 2
				Set @FromSql = @FromSql + ' AND P.Charge_State = ' + Convert(varchar(6), @ChargeStateFilter)
			End

			If @UseDistinctPeptides <> 0
				Set @FromSql = @FromSql + ' GROUP BY P.Mass_Tag_ID'
		End
		
		Set @FromSql = @FromSql + ') LookupQ '

		If @ScoreMinimum >= @ScoreMaximum
		Begin
			Set @ScoreMinimum = 0
			Set @ScoreMaximum = 100
		End

		If @BinCount < 1
			Set @BinCount = 100
	End

	if @mode = 4
	Begin
		-- PMT Quality Score
		Set @BinField = 'PMT_Quality_Score'

		Set @FromSql = ''
		Set @FromSql = @FromSql + ' FROM ('

		Set @FromSql = @FromSql +   ' SELECT ScoreListQ.PMT_Quality_Score AS Value, SUM(DataQ.Frequency) AS Frequency'
		Set @FromSql = @FromSql +   ' FROM (SELECT DISTINCT PMT_Quality_Score FROM T_Mass_Tags) ScoreListQ INNER JOIN'

        Set @FromSql = @FromSql +     ' ('

		If @UseDistinctPeptides <> 0 And Len(@ResultTypeFilter) = 0 And @ChargeStateFilter = 0
		Begin
			-- Fast query that only uses T_Mass_Tags
			Set @QuerySpeedCategory = 0
			
			Set @FromSql = @FromSql +  ' SELECT MT.PMT_Quality_Score, COUNT(*) AS Frequency'
			Set @FromSql = @FromSql +  ' FROM T_Mass_Tags MT'
			Set @FromSql = @FromSql +  ' WHERE NOT MT.PMT_Quality_Score Is Null'
			
			If @DiscriminantScoreMinimum > 0
				Set @FromSql = @FromSql + ' AND MT.High_Discriminant_Score >= ' + Convert(varchar(12), @DiscriminantScoreMinimum)
			If @PMTQualityScoreMinimum > 0
				Set @FromSql = @FromSql + ' AND MT.PMT_Quality_Score >= ' + Convert(varchar(12), @PMTQualityScoreMinimum)
		End
		Else
		Begin
			Set @QuerySpeedCategory = 1
			
			If @UseDistinctPeptides = 0
				Set @FromSql = @FromSql + ' SELECT MT.PMT_Quality_Score, COUNT(*) AS Frequency'
			Else
				Set @FromSql = @FromSql + ' SELECT MT.PMT_Quality_Score, COUNT(DISTINCT MT.Mass_Tag_ID) AS Frequency'

			Set @FromSql = @FromSql +     ' FROM T_Peptides P'
			Set @FromSql = @FromSql +     ' INNER JOIN T_Mass_Tags MT ON P.Mass_Tag_ID = MT.Mass_Tag_ID'
			If @DiscriminantScoreMinimum > 0
				Set @FromSql = @FromSql + ' INNER JOIN T_Score_Discriminant SD ON P.Peptide_ID = SD.Peptide_ID'
			If Len(@ResultTypeFilter) > 0
				Set @FromSql = @FromSql + ' INNER JOIN T_Analysis_Description TAD ON P.Analysis_ID = TAD.Job'

			Set @FromSql = @FromSql +  ' WHERE NOT MT.PMT_Quality_Score Is Null'
			If Len(@ResultTypeFilter) > 0
				Set @FromSql = @FromSql + ' AND TAD.ResultType = ''' + @ResultTypeFilter + ''''
			If @DiscriminantScoreMinimum > 0
				Set @FromSql = @FromSql + ' AND SD.DiscriminantScoreNorm >= ' + Convert(varchar(12), @DiscriminantScoreMinimum)
			If @PMTQualityScoreMinimum > 0
				Set @FromSql = @FromSql + ' AND MT.PMT_Quality_Score >= ' + Convert(varchar(12), @PMTQualityScoreMinimum)
			If @ChargeStateFilter > 0
			Begin
				Set @QuerySpeedCategory = 2
				Set @FromSql = @FromSql + ' AND P.Charge_State = ' + Convert(varchar(6), @ChargeStateFilter)
			End

		End
	
		Set @FromSql = @FromSql +      ' GROUP BY MT.PMT_Quality_Score'
			
		Set @FromSql = @FromSql +     ') DataQ ON DataQ.PMT_Quality_Score >= ScoreListQ.PMT_Quality_Score'
		Set @FromSql = @FromSql +   ' GROUP BY ScoreListQ.PMT_Quality_Score'
		Set @FromSql = @FromSql + ') LookupQ'		

		If @ScoreMinimum >= @ScoreMaximum
		Begin
			Set @ScoreMinimum = 0
			Set @ScoreMaximum = 10
		End
		
		-- Note: We do not use @BinCount for PMT Quality score queries
		Set @BinCount = 1
	End

	if @mode = 5
	Begin
		-- X!Tandem Hyperscore Histogram
		Set @BinField = 'Hyperscore'

		Set @QuerySpeedCategory = 1

		Set @FromSql = ''
		Set @FromSql = @FromSql +     ' FROM ('

		If @UseDistinctPeptides = 0
			Set @FromSql = @FromSql + '  SELECT X.Hyperscore AS Value'
		Else
			Set @FromSql = @FromSql + '  SELECT MAX(X.Hyperscore) AS Value'

		Set @FromSql = @FromSql + '  FROM T_Peptides P'
		Set @FromSql = @FromSql +     ' INNER JOIN T_Score_XTandem X ON P.Peptide_ID = X.Peptide_ID'
		If @DiscriminantScoreMinimum > 0
			Set @FromSql = @FromSql + ' INNER JOIN T_Score_Discriminant SD ON P.Peptide_ID = SD.Peptide_ID'
		If Len(@ResultTypeFilter) > 0
			Set @FromSql = @FromSql + ' INNER JOIN T_Analysis_Description TAD ON P.Analysis_ID = TAD.Job'
		If @PMTQualityScoreMinimum > 0
			Set @FromSql = @FromSql + ' INNER JOIN T_Mass_Tags MT ON P.Mass_Tag_ID = MT.Mass_Tag_ID'

		Set @FromSql = @FromSql +  ' WHERE NOT X.Hyperscore Is Null'
		If Len(@ResultTypeFilter) > 0
			Set @FromSql = @FromSql + ' AND TAD.ResultType = ''' + @ResultTypeFilter + ''''
		If @DiscriminantScoreMinimum > 0
			Set @FromSql = @FromSql + ' AND SD.DiscriminantScoreNorm >= ' + Convert(varchar(12), @DiscriminantScoreMinimum)
		If @PMTQualityScoreMinimum > 0
			Set @FromSql = @FromSql + ' AND MT.PMT_Quality_Score >= ' + Convert(varchar(12), @PMTQualityScoreMinimum)
		If @ChargeStateFilter > 0
		Begin
			Set @QuerySpeedCategory = 2
			Set @FromSql = @FromSql + ' AND P.Charge_State = ' + Convert(varchar(6), @ChargeStateFilter)
		End

		If @UseDistinctPeptides <> 0
			Set @FromSql = @FromSql + ' GROUP BY P.Mass_Tag_ID'

		Set @FromSql = @FromSql + ') LookupQ '

		If @ScoreMinimum >= @ScoreMaximum
		Begin
			Set @ScoreMinimum = 0
			Set @ScoreMaximum = 150
		End

		If @BinCount < 1
			Set @BinCount = 150
	End

	if @mode = 6
	Begin
		-- X!Tandem Log(E_Value) Histogram
		Set @BinField = 'Log_EValue'

		Set @QuerySpeedCategory = 1

		Set @FromSql = ''
		Set @FromSql = @FromSql +     ' FROM ('
		
		If @UseDistinctPeptides = 0
			Set @FromSql = @FromSql + '  SELECT X.Log_EValue AS Value'
		Else
			Set @FromSql = @FromSql + '  SELECT MIN(X.Log_EValue) AS Value'

		Set @FromSql = @FromSql + '  FROM T_Peptides P'
		Set @FromSql = @FromSql +     ' INNER JOIN T_Score_XTandem X ON P.Peptide_ID = X.Peptide_ID'
		If @DiscriminantScoreMinimum > 0
			Set @FromSql = @FromSql + ' INNER JOIN T_Score_Discriminant SD ON P.Peptide_ID = SD.Peptide_ID'
		If Len(@ResultTypeFilter) > 0
			Set @FromSql = @FromSql + ' INNER JOIN T_Analysis_Description TAD ON P.Analysis_ID = TAD.Job'
		If @PMTQualityScoreMinimum > 0
			Set @FromSql = @FromSql + ' INNER JOIN T_Mass_Tags MT ON P.Mass_Tag_ID = MT.Mass_Tag_ID'

		Set @FromSql = @FromSql +  ' WHERE NOT X.Log_EValue Is Null'
		If Len(@ResultTypeFilter) > 0
			Set @FromSql = @FromSql + ' AND TAD.ResultType = ''' + @ResultTypeFilter + ''''
		If @DiscriminantScoreMinimum > 0
			Set @FromSql = @FromSql + ' AND SD.DiscriminantScoreNorm >= ' + Convert(varchar(12), @DiscriminantScoreMinimum)
		If @PMTQualityScoreMinimum > 0
			Set @FromSql = @FromSql + ' AND MT.PMT_Quality_Score >= ' + Convert(varchar(12), @PMTQualityScoreMinimum)
		If @ChargeStateFilter > 0
		Begin
			Set @QuerySpeedCategory = 2
			Set @FromSql = @FromSql + ' AND P.Charge_State = ' + Convert(varchar(6), @ChargeStateFilter)
		End

		If @UseDistinctPeptides <> 0
			Set @FromSql = @FromSql + ' GROUP BY P.Mass_Tag_ID'

		Set @FromSql = @FromSql + ') LookupQ '

		If @ScoreMinimum >= @ScoreMaximum
		Begin
			Set @ScoreMinimum = -100
			Set @ScoreMaximum = 0
		End

		If @BinCount < 1
			Set @BinCount = 100

	End

	-----------------------------------------------------
	-- Define the bin size based on @ScoreMinimum, @ScoreMaximum, and @BinCount
	-----------------------------------------------------
	--
	Set @BinField = @BinField + '_Bin'
	
	Set @Iteration = 0
	Set @ScoreMinStart = @ScoreMinimum
	
	If @BinCount < 1
		Set @BinCount = 1
	
	-- Compute the Bin Width
	Set @BinSize = (@ScoreMaximum - @ScoreMinimum) / Convert(real, @BinCount)
	
	-- Defined @DigitsOfPrecisionForRound
	If @BinSize <= 1
	Begin
		Set @DigitsOfPrecisionForRound = Abs(Floor(log10(@BinSize)) - 2)
		If @DigitsOfPrecisionForRound > 5
			Set @DigitsOfPrecisionForRound = 5
		If @DigitsOfPrecisionForRound < 1
			Set @DigitsOfPrecisionForRound = 1
	End
	Else
		Set @DigitsOfPrecisionForRound = 1
	
	-- Round @BinSize
	Set @BinSize = Round(@BinSize, @DigitsOfPrecisionForRound)


	If @HistogramCacheIDOverride > 0
	Begin
		-----------------------------------------------------
		-- Updating an existing histogram cache ID
		-----------------------------------------------------
		Set @CachedDataExists = 1
		Set @HistogramCacheID = @HistogramCacheIDOverride
		Set @ForceUpdate = 1

		-- Count the number of data rows in T_Histogram_Cache_Data
		-- If 0, then we'll re-use @HistogramCacheID
		-- If positive, and if the new results don't match the old results,
		--  then we'll assign a new Histogram_Cache_ID value
		SELECT @MatchRowCount = COUNT(*)
		FROM T_Histogram_Cache_Data
		WHERE Histogram_Cache_ID = @HistogramCacheID
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		
		If @MatchRowCount = 0 
			Set @CachedDataExists = 2

	End
	Else
	Begin -- <a>
		-----------------------------------------------------
		-- See if data already exists in T_Histogram_Cache for the given mode and settings
		-----------------------------------------------------
		Set @CachedDataExists = 0
		Set @HistogramCacheID = 0
		
		If @EstimateExecutionTime <> 0
		Begin -- <b>
			-- Estimate the average execution time using @Mode and @QuerySpeedCategory
			Set @ExecutionTimeAvg = 0
			Set @ExecutionTimeStDev = 0
			Set @CacheStateMinimum = 1
			Set @CacheStateMaximum = 2
			
			Set @LoopCount = 0
			While @LoopCount < 3
			Begin
				SELECT	@HistogramCacheID = MAX(Histogram_Cache_ID),
						@ExecutionTimeAvg = Convert(real, AVG(Execution_Time_Seconds)),
						@ExecutionTimeStDev = Convert(real, IsNull(STDEV(Execution_Time_Seconds),0))
				FROM	T_Histogram_Cache
				WHERE	Histogram_Mode = @mode AND
						(Histogram_Cache_State BETWEEN @CacheStateMinimum AND @CacheStateMaximum) AND
						Query_Speed_Category = @QuerySpeedCategory
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error

				If @myRowCount = 1 And Not @HistogramCacheID Is Null
				Begin
					Set @CachedDataExists = 1
					Set @LoopCount = 3
				End
				Else
				Begin
					-- We're trying to estimate the execution time but didn't get a match
					-- On the first loop, change @CacheStateMinimum to 0 then query T_Histogram_Cache again
					If @LoopCount = 0
						Set @CacheStateMinimum = 0

					-- On the second loop, change @CacheStateMaximum to 100 then query T_Histogram_Cache again
					If @LoopCount = 1
						Set @CacheStateMaximum = 100
						
					Set @LoopCount = @LoopCount + 1
				End
			End

			-- Return the estimated average execution time and standard deviation for the given settings
			If @CachedDataExists = 1
				SELECT	Round(@ExecutionTimeAvg, 2)   AS Execution_Time_Avg, 
						Round(@ExecutionTimeStDev, 4) AS Execution_Time_StDev
			Else
				SELECT	Convert(real, -1) AS Execution_Time_Avg, 
						Convert(real, 0)  AS Execution_Time_StDev
			
			Goto Done

		End -- </b>
		Else
		Begin  -- <b>
			SELECT	@HistogramCacheID = MAX(Histogram_Cache_ID)
			FROM	T_Histogram_Cache INNER JOIN (
				SELECT  MAX(Query_Date) AS Query_Date_Max
				FROM	T_Histogram_Cache
				WHERE	Histogram_Mode = @mode AND
						Histogram_Cache_State IN (1,2) AND
						Score_Minimum = @ScoreMinimumInput AND 
						Score_Maximum = @ScoreMaximumInput AND 
						(Bin_Count = @BinCount OR @mode = 4) AND
						Discriminant_Score_Minimum = @DiscriminantScoreMinimum AND
						PMT_Quality_Score_Minimum = @PMTQualityScoreMinimum AND
						Charge_State_Filter = @ChargeStateFilter AND
						Use_Distinct_Peptides = @UseDistinctPeptides AND
						Result_Type_Filter = @ResultTypeFilter
				) DateQ ON T_Histogram_Cache.Query_Date = DateQ.Query_Date_Max
			WHERE	Histogram_Mode = @mode AND
					Histogram_Cache_State IN (1,2) AND
					Score_Minimum = @ScoreMinimumInput AND 
					Score_Maximum = @ScoreMaximumInput AND 
					(Bin_Count = @BinCount OR @mode = 4) AND
					Discriminant_Score_Minimum = @DiscriminantScoreMinimum AND
					PMT_Quality_Score_Minimum = @PMTQualityScoreMinimum AND
					Charge_State_Filter = @ChargeStateFilter AND
					Use_Distinct_Peptides = @UseDistinctPeptides AND
					Result_Type_Filter = @ResultTypeFilter
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			
			If @myRowCount = 1 And Not @HistogramCacheID Is Null
			Begin
				Set @CachedDataExists = 1
				
				SELECT  @HistogramCacheState = Histogram_Cache_State,
						@AutoUpdate = Auto_Update
				FROM T_Histogram_Cache
				WHERE Histogram_Cache_ID = @HistogramCacheID
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error
				
				If @HistogramCacheState = 2
					Set @ForceUpdate = 1
			End
		End -- </b>
	End -- </a>

	-----------------------------------------------------
	-- Define @SqlFromCache; we append @HistogramCacheID later since it might not yet be known
	-----------------------------------------------------
	Set @SqlFromCache = ''
	Set @SqlFromCache = @SqlFromCache + ' SELECT Bin AS ' + @BinField + ', Frequency'
	Set @SqlFromCache = @SqlFromCache + ' FROM T_Histogram_Cache_Data'
	Set @SqlFromCache = @SqlFromCache + ' WHERE Histogram_Cache_ID = '
	
	If @CachedDataExists = 0 Or @ForceUpdate <> 0
	Begin
		-- Note that the SQL for Mode 4 will have been created above
		
		If @mode = 4
		Begin
			-----------------------------------------------------
			-- Construct the Sql to obtain the PMT Quality Score data
			-----------------------------------------------------
			Set @Sql = ''
			Set @Sql = @Sql + ' SELECT TOP 100 Percent Value, Frequency '
			Set @Sql = @Sql +   @FromSql
			Set @Sql = @Sql + ' WHERE Value BETWEEN '
			Set @Sql = @Sql +       Convert(varchar(9), @ScoreMinimum) + ' AND ' + Convert(varchar(9), @ScoreMaximum)
			Set @Sql = @Sql + ' ORDER BY Value'	
				
		End
		Else
		Begin
			-----------------------------------------------------
			-- Check whether @BinSize is a power of 10
			-----------------------------------------------------
			If log10(@BinSize) = Round(log10(@BinSize),0) And @BinSize <= 1
			Begin
				-- @BinSize is 1, 0.1, 0.01, 0.001, etc.
				-- We can use the Round function to bin the data
				Set @BinSql = 'Round(Value, ' + Convert(varchar(9), Convert(int, Abs(log10(@BinSize)))) + ')'
			End
			Else
			Begin
				-- @BinSize is not a power of 10
				-- Need to use a Case statement to bin the data
				-- If there are over 100 bins, this could easily result in @BinSql being more than 7250 characters
				-- We abort the loop if this happens
				Set @BinSql = ' CASE WHEN Value IS NULL THEN 0'
				While @ScoreMinStart < @ScoreMaximum And @Iteration <= @BinCount And Len(@BinSql) < 7250
				Begin
					Set @BinSql = @BinSql + ' WHEN Value BETWEEN '
					Set @BinSql = @BinSql + Convert(varchar(9), @ScoreMinStart) + ' AND '
					
					Set @BinSql = @BinSql + Convert(varchar(9), @ScoreMinStart + @BinSize) + ' THEN ' + Convert(varchar(9), @ScoreMinStart)
					
					Set @Iteration = @Iteration + 1
					Set @ScoreMinStart = @ScoreMinimum + @Iteration * @BinSize
				End
				
				Set @BinSql = @BinSql + ' ELSE 0 END'
			End	

			-----------------------------------------------------
			-- Construct the Sql to obtain the histogram data
			-----------------------------------------------------
			Set @Sql = ''
			Set @Sql = @Sql + ' SELECT TOP 100 Percent Convert(varchar(12), Round(Value, ' + Convert(varchar(3), @DigitsOfPrecisionForRound) + ')) AS Bin, COUNT(*) AS Frequency'
			Set @Sql = @Sql + ' FROM (SELECT ' + @BinSql + ' AS Value '
			Set @Sql = @Sql +         @FromSql
			Set @Sql = @Sql +       ' WHERE Value BETWEEN '
			Set @Sql = @Sql +       Convert(varchar(9), @ScoreMinimum) + ' AND ' + Convert(varchar(9), @ScoreMaximum)
			Set @Sql = @Sql +      ') AS StatsQ'
			Set @Sql = @Sql + ' GROUP BY Value'
			Set @Sql = @Sql + ' ORDER BY Value'	
		
		End
	End

	-- Fill @InputParams with the input parameters
	-- This text is used if an error occurs
	Set @InputParams = ''
	Set @InputParams = @InputParams + '@Mode=' + convert(varchar(9), @mode) + ';'
	Set @InputParams = @InputParams + '@ScoreMinimum=' + convert(varchar(12), @ScoreMinimum) + ';'
	Set @InputParams = @InputParams + '@ScoreMaximum=' + convert(varchar(12), @ScoreMaximum) + ';'
	Set @InputParams = @InputParams + '@BinCount=' + convert(varchar(9), @BinCount) + ';'
	Set @InputParams = @InputParams + '@DiscriminantScoreMinimum=' + convert(varchar(12), @DiscriminantScoreMinimum) + ';'
	Set @InputParams = @InputParams + '@PMTQualityScoreMinimum=' + convert(varchar(9), @PMTQualityScoreMinimum) + ';'
	Set @InputParams = @InputParams + '@ChargeStateFilter=' + convert(varchar(9), @ChargeStateFilter) + ';'
	Set @InputParams = @InputParams + '@UseDistinctPeptides=' + convert(varchar(9), @UseDistinctPeptides) + ';'
	Set @InputParams = @InputParams + '@ResultTypeFilter=' + @ResultTypeFilter
	
	If @PreviewSql = 0
	Begin -- <a>
		If @CachedDataExists = 0 Or @ForceUpdate <> 0
		Begin -- <b>
			-- Populate a temporary table with the histogram data
			
			CREATE TABLE #TmpHistogramData (
				Bin float,
				Frequency int
			)
			
			Set @Sql = 'INSERT INTO #TmpHistogramData (Bin, Frequency) ' + @Sql

			Set @ExecutionStartDate = GetDate()
			Exec (@Sql)
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			Set @ResultCount = @myRowCount
			
			If @myError <> 0
			Begin
				Set @message = 'Error populating #TmpHistogramData with the histogram data: error number = ' + Convert(varchar(19), @myError) + '; ' + @InputParams
				EXEC PostLogEntry 'Error', @message, 'GenerateHistogram'
				Goto Done
			End

			Set @ExecutionTimeSeconds = Round(DateDiff(MS, @ExecutionStartDate, GetDate()) / 1000.0, 2)
			
			If @CachedDataExists = 1
			Begin -- <c>
				-- Cached data exists but the user specified ForceCacheUpdate 
				--  (or @HistogramCacheState = 2 or @HistogramCacheIDOverride > 0)
				-- See if the data in T_Histogram_Cache_Data matches the data in #TmpHistogramData
				
				SELECT @MatchRowCount = COUNT(*)
				FROM T_Histogram_Cache_Data HCD INNER JOIN
					 #TmpHistogramData C ON HCD.Bin = C.Bin AND HCD.Frequency = C.Frequency
				WHERE HCD.Histogram_Cache_ID = @HistogramCacheID
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error
				
				If @myRowCount = 0 Or @myError <> 0
				Begin
					-- Error occurred or no match found
					Set @CachedDataExists = 0
				End
				Else
				Begin
					If @MatchRowCount <> @ResultCount
						Set @CachedDataExists = 0
					Else
					Begin
						-- Row counts match; update Query_Date in T_Histogram_Cache
						UPDATE T_Histogram_Cache
						SET Query_Date = GetDate(), 
							Result_Count = @ResultCount, 
							Query_Speed_Category = @QuerySpeedCategory,
							Execution_Time_Seconds = @ExecutionTimeSeconds,
							Histogram_Cache_State = 1
						WHERE Histogram_Cache_ID = @HistogramCacheID
						--
						SELECT @myRowCount = @@rowcount, @myError = @@error
					End
					
				End
			
				If @CachedDataExists = 0
				Begin
					-- The cached data for @HistogramCacheID doesn't match the new data
					-- Update to state 0 and set Auto_Update to 0
					UPDATE T_Histogram_Cache
					SET Histogram_Cache_State = 0, Auto_Update = 0
					WHERE Histogram_Cache_ID = @HistogramCacheID
					--
					SELECT @myRowCount = @@rowcount, @myError = @@error
				End
			End -- </c>
			
			If @CachedDataExists = 0
			Begin -- <c>
				-- Make a new entry in T_Histogram_Cache
				INSERT INTO T_Histogram_Cache ( Histogram_Mode, Score_Minimum, Score_Maximum, Bin_Count, 
												Discriminant_Score_Minimum, PMT_Quality_Score_Minimum, Charge_State_Filter,
												Use_Distinct_Peptides, Result_Type_Filter, 
												Query_Date, Result_Count, Query_Speed_Category, Execution_Time_Seconds, 
												Histogram_Cache_State, Auto_Update)
				VALUES (	@mode, @ScoreMinimumInput, @ScoreMaximumInput, @BinCount,
							@DiscriminantScoreMinimum, @PMTQualityScoreMinimum, @ChargeStateFilter,
							@UseDistinctPeptides, @ResultTypeFilter, 
							GetDate(), @ResultCount, @QuerySpeedCategory, @ExecutionTimeSeconds, 
							1, @AutoUpdate)
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error, @HistogramCacheID = SCOPE_IDENTITY()
				
				If @myError <> 0
				Begin
					Set @message = 'Error adding new row to table T_Histogram_Cache: error number = ' + Convert(varchar(19), @myError) + '; ' + @InputParams
					EXEC PostLogEntry 'Error', @message, 'GenerateHistogram'
					Goto Done
				End
				
				-- Now copy the data from #TmpHistogramData to T_Histogram_Cache_Data
				INSERT INTO T_Histogram_Cache_Data(Histogram_Cache_ID, Bin, Frequency)
				SELECT @HistogramCacheID AS Histogram_Cache_ID, Bin, Frequency
				FROM #TmpHistogramData
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error
				
			End -- </c>
			
			If @CachedDataExists = 2
			Begin
				UPDATE T_Histogram_Cache
				SET Query_Date = GetDate(), 
					Result_Count = @ResultCount, 
					Query_Speed_Category = @QuerySpeedCategory,
					Execution_Time_Seconds = @ExecutionTimeSeconds,
					Histogram_Cache_State = 1
				WHERE Histogram_Cache_ID = @HistogramCacheID
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error
				
				-- Now copy the data from #TmpHistogramData to T_Histogram_Cache_Data
				INSERT INTO T_Histogram_Cache_Data(Histogram_Cache_ID, Bin, Frequency)
				SELECT @HistogramCacheID AS Histogram_Cache_ID, Bin, Frequency
				FROM #TmpHistogramData
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error
			End
			
			DROP TABLE #TmpHistogramData

		End -- </b>
		
		-- Only return the data if @HistogramCacheIDOverride = 0
		If @HistogramCacheIDOverride = 0
		Begin
			Set @Sql = @SqlFromCache + Convert(varchar(19), @HistogramCacheID)
			Exec (@Sql)
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
		End
	End -- </a>
	Else
	Begin
		-- Preview the Sql
		If @CachedDataExists = 0 Or @ForceUpdate <> 0
		Begin
			Print @Sql
			SELECT @Sql AS TheSql
		End
		Else
		Begin
			Set @Sql = @SqlFromCache + Convert(varchar(19), @HistogramCacheID)
			Print @Sql
			SELECT @Sql AS TheSql
		End
	End

Done:
	Return @myError


GO
GRANT EXECUTE ON [dbo].[GenerateHistogram] TO [DMS_SP_User]
GO
