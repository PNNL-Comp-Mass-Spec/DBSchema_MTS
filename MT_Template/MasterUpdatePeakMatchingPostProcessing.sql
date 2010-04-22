/****** Object:  StoredProcedure [dbo].[MasterUpdatePeakMatchingPostProcessing] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.MasterUpdatePeakMatchingPostProcessing
/****************************************************
** 
**	Desc:
**		Performs calculations and data reductions for 
**		newly completed peak matching tasks   
**
**	Return values: 0: success, otherwise, error code
** 
**	Parameters:
**
**	Auth:	grk
**	Date:	09/03/2003
**			04/08/2004 mem - Limiting call to UpdateGeneralStatistics to be every @GeneralStatsUpdateInterval hours
**			04/09/2004 mem - Added support for LogLevel
**			09/20/2004 mem - Updated to new MTDB schema
**			04/13/2005 mem - Now calling CheckStaleTasks to look for tasks stuck in processing
**			10/11/2005 mem - Updated to call MasteUpdateQRProcessStart
**			03/04/2006 mem - Now calling UpdateGeneralStatisticsIfRequired to possibly update the general statistics
**			03/14/2006 mem - Now calling VerifyUpdateEnabled
**    
*****************************************************/
(
	@message varchar(255) = '' output,
	@GeneralStatsUpdateInterval int = 13			-- Minimum interval in hours to call UpdateGeneralStatistics (overridden if defined in T_Process_Config)
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0
	
	declare @result int
	declare @logLevel int
	declare @UpdateEnabled tinyint

	declare @countProcessed int
	set @countProcessed = 0

	set @logLevel = 1		-- Default to normal logging

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled 'MS_Peak_Matching', 'MasterUpdatePeakMatchingPostProcessing', @AllowPausing = 0, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done
	
	--------------------------------------------------------------
	-- Lookup the LogLevel state
	-- 0=Off, 1=Normal, 2=Verbose, 3=Debug
	--------------------------------------------------------------
	--
	set @result = @logLevel
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'LogLevel')
	Set @logLevel = @result

	set @message = 'Begin Master Update Peak Matching Post Processing for ' + DB_NAME()
	If @logLevel >= 2
		execute PostLogEntry 'Normal', @message, 'MasterUpdatePeakMatchingPostProcessing'
		
 	--------------------------------------------------------------
	-- Quantitation processing
	--------------------------------------------------------------
	
	EXEC @result = MasterUpdateQRProcessStart @logLevel

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled 'MS_Peak_Matching', 'MasterUpdatePeakMatchingPostProcessing', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done

	--------------------------------------------------------------
	-- Possibly update general statistics
	--------------------------------------------------------------
	--
	Declare @ForceGeneralStatisticsUpdate tinyint
	Declare @StatsUpdated tinyint
	Declare @HoursSinceLastUpdate int

	Set @ForceGeneralStatisticsUpdate = 0
	Set @StatsUpdated = 0
	Set @HoursSinceLastUpdate = 0
	
	Exec @myError = UpdateGeneralStatisticsIfRequired @GeneralStatsUpdateInterval, @ForceGeneralStatisticsUpdate, @LogLevel, @StatsUpdated = @StatsUpdated Output, @HoursSinceLastUpdate = @HoursSinceLastUpdate Output

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled 'MS_Peak_Matching', 'MasterUpdatePeakMatchingPostProcessing', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done

	If @StatsUpdated <> 0 Or @HoursSinceLastUpdate >= 6
	Begin
		--------------------------------------------------------------
		-- Call CheckStaleTasks to look for tasks stuck in processing
		--------------------------------------------------------------
		--
		Exec @result = CheckStaleTasks
		--
		set @message = 'Complete CheckStaleTasks: ' + convert(varchar(32), @result)
		If @logLevel >= 2
			execute PostLogEntry 'Normal', @message, 'MasterUpdatePeakMatchingPostProcessing'
	End
		
	--------------------------------------------------------------
	-- Normal Exit
	--------------------------------------------------------------

	set @message = 'End Master Update Peak Matching Post Processing for ' + DB_NAME() + ': ' + convert(varchar(32), @myError)
	
Done:
	If (@logLevel >=1 AND @myError <> 0)
		execute PostLogEntry 'Error', @message, 'MasterUpdatePeakMatchingPostProcessing'
	Else
	If @logLevel >= 2
		execute PostLogEntry 'Normal', @message, 'MasterUpdatePeakMatchingPostProcessing'

	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[MasterUpdatePeakMatchingPostProcessing] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[MasterUpdatePeakMatchingPostProcessing] TO [MTS_DB_Lite] AS [dbo]
GO
