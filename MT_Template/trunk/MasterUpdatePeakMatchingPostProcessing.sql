SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[MasterUpdatePeakMatchingPostProcessing]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[MasterUpdatePeakMatchingPostProcessing]
GO


CREATE PROCEDURE dbo.MasterUpdatePeakMatchingPostProcessing
/****************************************************
** 
**		Desc:
**		Performs calculations and data reductions for 
**		newly completed peak matching tasks   
**
**		Return values: 0: success, otherwise, error code
** 
**		Parameters:
**
**		Auth: grk
**		Date: 9/03/2003
**			  04/08/2004 mem - Limiting call to UpdateGeneralStatistics to be every @GeneralStatsUpdateInterval hours
**			  04/09/2004 mem - Added support for LogLevel
**			  09/20/2004 mem - Updated to new MTDB schema
**			  04/13/2005 mem - Now calling CheckStaleTasks to look for tasks stuck in processing
**			  10/11/2005 mem - Updated to call MasteUpdateQRProcessStart
**    
*****************************************************/
(
	@message varchar(255) = '' output,
	@GeneralStatsUpdateInterval int = 13			-- Minimum interval in hours to call UpdateGeneralStatistics
)
As
	set nocount on
	
	declare @myError int
	set @myError = 0

	declare @myRowCount int
	set @myRowCount = 0
	
	declare @result int
	declare @logLevel int
	declare @countProcessed int
	set @countProcessed = 0

	set @logLevel = 1		-- Default to normal logging
	
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


	--------------------------------------------------------------
	-- Update general statistics
	--------------------------------------------------------------
	--
	-- Look up the Last Update date stored in T_General_Statistics
	
	Declare @LastUpdated varchar(64)
	
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
		execute PostLogEntry 'Error', @message, 'MasterUpdatePeakMatchingPostProcessing'
		Goto Done
	End
	
	If GetDate() > DateAdd(hour, @GeneralStatsUpdateInterval, @LastUpdated)
	Begin
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Begin UpdateGeneralStatistics', 'MasterUpdatePeakMatchingPostProcessing'
		EXEC @result = UpdateGeneralStatistics
		--
		set @message = 'Complete UpdateGeneralStatistics: ' + convert(varchar(32), @result)
		If @logLevel >= 1
			execute PostLogEntry 'Normal', @message, 'MasterUpdatePeakMatchingPostProcessing'


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
	else
		If @logLevel >= 3
		begin
			set @message = 'Skipping UpdateGeneralStatistics since ' + Convert(varchar(32), @GeneralStatsUpdateInterval) + ' hours have not yet elapsed'
			execute PostLogEntry 'Normal', @message, 'MasterUpdatePeakMatchingPostProcessing'
		end
		
	--------------------------------------------------------------
	-- Normal Exit
	--------------------------------------------------------------

	set @message = 'End Master Update Peak Matching Post Processing for ' + DB_NAME() + ': ' + convert(varchar(32), @myError)
	if @logLevel >= 2
		execute PostLogEntry 'Normal', @message, 'MasterUpdatePeakMatchingPostProcessing'
	
	
 Done:
	return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

