/****** Object:  StoredProcedure [dbo].[UpdateGeneralStatisticsIfRequired] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.UpdateGeneralStatisticsIfRequired
/****************************************************
** 
**	Desc:
**		Calls UpdateGeneralStatistics if sufficient time has elapsed
**		 since the last update
**
**	Return values: 0: success, otherwise, error code
** 
**	Parameters:
**
**	Auth:	mem
**	Date:	03/04/2006
**			03/13/2006 mem - Now calling SP UpdateCachedHistograms and SP DeleteHistogramCacheData
**    
*****************************************************/
(
	@GeneralStatsUpdateInterval int = 13,			-- Minimum interval in hours to call UpdateGeneralStatistics (overridden if defined in T_Process_Config)
	@ForceGeneralStatisticsUpdate tinyint = 0,
	@LogLevel int = 1,
	@StatsUpdated tinyint = 0 Output,
	@HoursSinceLastUpdate int = 0 Output,
	@message varchar(255) = '' Output
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	Set @StatsUpdated = 0
	Set @HoursSinceLastUpdate = 0
	Set @message = ''
	
	Declare @MinimumDateThreshold datetime
	
	--------------------------------------------------------------
	-- Possibly update the general statistics
	--------------------------------------------------------------
	--
	-- Lookup the Last Update date stored in T_General_Statistics

	Declare @ValueText varchar(64)
	Declare @UpdateInterval int				-- Interval is in hours
	
	Declare @LastUpdated varchar(64)
	Set @LastUpdated = '1/1/1900'
	
	SELECT @LastUpdated = Value
	FROM T_General_Statistics
	WHERE Category = 'General' AND Label = 'Last Updated'
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	If @myError <> 0 
	Begin
		Set @message = 'Error looking up Last Updated time from T_General_Statistics'
		Set @myError = 100
		execute PostLogEntry 'Error', @message, 'UpdateGeneralStatisticsIfRequired'
		Goto Done
	End
	
	-- Force an update if no statistics are present
	If @myRowcount = 0
		Set @ForceGeneralStatisticsUpdate = 1
		
	-- Lookup the value for General_Statistics_Update_Interval in T_Process_Config
	-- If present, then this value overrides @GeneralStatsUpdateInterval
	SELECT @ValueText = Value
	FROM T_Process_Config
	WHERE [Name] = 'General_Statistics_Update_Interval'
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--	
	If IsNumeric(@ValueText) <> 0
		Set @UpdateInterval = Convert(int, @ValueText)
	Else
		Set @UpdateInterval = @GeneralStatsUpdateInterval

	Set @HoursSinceLastUpdate = DateDiff(hour, @LastUpdated, GetDate())
	
	If @HoursSinceLastUpdate >= @UpdateInterval Or IsNull(@ForceGeneralStatisticsUpdate,0) <> 0
	Begin
		Set @StatsUpdated = 1
		
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Begin UpdateGeneralStatistics', 'UpdateGeneralStatisticsIfRequired'
		EXEC @myError = UpdateGeneralStatistics
		--
		set @message = 'Complete UpdateGeneralStatistics: ' + convert(varchar(32), @myError)
		If @logLevel >= 1
			execute PostLogEntry 'Normal', @message, 'UpdateGeneralStatisticsIfRequired'


		-- Update the data for any cached histograms with Histogram_Cache_State = 2
		EXEC @myError = UpdateCachedHistograms @UpdateIfRequired = 1, @message = @message output

		
		-- Delete cached histogram data over 120 days old
		Set @MinimumDateThreshold = GetDate() - 120
		EXEC @myError = DeleteHistogramCacheData @MinimumDateThreshold, @KeepOneEntryForEachUniqueCombo = 1
	End
	Else
	Begin
		set @message = 'Skipping UpdateGeneralStatistics since ' + Convert(varchar(19), @UpdateInterval) + ' hours have not yet elapsed (last update was ' + Convert(varchar(19), @HoursSinceLastUpdate) + ' hours ago)'
		If @logLevel >= 3
		Begin
			execute PostLogEntry 'Normal', @message, 'UpdateGeneralStatisticsIfRequired'
		End
	End
		
		
	--------------------------------------------------------------
	-- Exit
	--------------------------------------------------------------

Done:
	return @myError


GO
