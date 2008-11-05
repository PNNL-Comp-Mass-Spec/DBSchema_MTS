/****** Object:  StoredProcedure [dbo].[MasterUpdateNET] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.MasterUpdateNET
/****************************************************
** 
**	Desc: 
**		Performs all the steps necessary to 
**		load NET regression results for available NET Update Tasks
**
**	Return values: 0: success, otherwise, error code
** 
**	Parameters:
**
**	Auth:	grk
**	Date:	09/12/2003
**			04/09/2004 mem - Added support for LogLevel
**			07/05/2004 mem - Changed for use in Peptide DB's
**			08/08/2004 mem - Added @ProcessStateMatch parameter and moved job processing code to MasterUpdateNETOneAnalysis
**			09/15/2004 mem - Added @numJobsToProcess
**			01/22/2005 mem - Added @MinNETRSquared parameter
**			04/08/2005 mem - Updated call to GetGANETFolderPaths
**			05/28/2005 mem - Switched to use T_NET_Update_Task and T_NET_Update_Task_Job_Map
**						   - Removed parameters @ProcessStateMatch and @MinNETFit
**			05/30/2005 mem - Added call to DropOldNETExportViews for V_NET_Export_Peptides_Task% views
**			07/28/2005 mem - Added call to DropOldNETExportViews for T_Tmp_NET_Export_Task% tables
**			03/11/2006 mem - Now calling VerifyUpdateEnabled
**			07/04/2006 mem - Removed check for 'GANETJobRegression' in T_Process_Step_Control
**			07/28/2006 mem - Updated to allow Task_ID values of 0
**    
*****************************************************/
(
	@NextProcessState int = 50,
	@MinNETRSquared real = 0.1,
	@message varchar(255) = '' output,
	@numJobsToProcess int = 50000	
)
As
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	declare @cmd varchar(255)

	declare @result int
	declare @logLevel int
	declare @DeleteGANETFiles int
	declare @JobsInTask int
	declare @UpdateEnabled tinyint
	
	set @result = 0
	set @logLevel = 1		-- Default to normal logging
	set @DeleteGANETFiles = 0
	
	--------------------------------------------------------------
	-- Lookup the LogLevel state
	-- 0=Off, 1=Normal, 2=Verbose, 3=Debug
	--------------------------------------------------------------
	--
	set @result = @logLevel
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'LogLevel')
	Set @logLevel = @result

	set @message = 'Begin Master Update NET for ' + DB_NAME()
	If @logLevel >= 2
		execute PostLogEntry 'Normal', @message, 'MasterUpdateNET'

	--------------------------------------------------------------
	-- Lookup whether or not we're deleting the GANET results files
	--------------------------------------------------------------
	--
	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'DeleteGANETFiles')
	if @result <> 0
		Set @DeleteGANETFiles = 1

	--------------------------------------------------------------
	-- Process any NET Update Tasks in state 3 = 'Results Ready'
	--------------------------------------------------------------

	declare @Continue tinyint
	declare @TaskID int,
			@numJobsProcessed int
	
	set @TaskID = -1
	set @numJobsProcessed = 0
	
	set @Continue = 1
	while @Continue = 1 And @numJobsProcessed < @numJobsToProcess
	begin
		---------------------------------------------------
		-- find an available NET Update Task
		---------------------------------------------------
		
		SELECT TOP 1 @TaskID = Task_ID
		FROM T_NET_Update_Task WITH (HoldLock)
		WHERE Processing_State = 3 And Task_ID > @TaskID
		ORDER BY Task_ID ASC
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0
		begin
			set @message = 'Error trying to find viable record'
			goto done
		end
		
		---------------------------------------------------
		-- Exit loop if no task found
		---------------------------------------------------

		if @TaskID < 0 OR @myRowCount = 0
			Set @Continue = 0
		else
		begin
			---------------------------------------------------
			-- Process the NET Update Task
			---------------------------------------------------

			Set @JobsInTask = 0
			SELECT @JobsInTask = COUNT(Job)
			FROM T_NET_Update_Task_Job_Map
			WHERE Task_ID = @TaskID

			exec @result = MasterUpdateNETOneTask	@TaskID, 
													@NextProcessState,
													@DeleteGANETFiles, 
													@logLevel,
													@MinNETRSquared,
													@message = @message OUTPUT
			
			set @numJobsProcessed = @numJobsProcessed + IsNull(@JobsInTask,0)
			
			If @result <> 0
				Set @Continue = 0
		end

		-- Validate that updating is enabled, abort if not enabled
		exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateNET', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
		If @UpdateEnabled = 0
			Goto Done

	end

	---------------------------------------------------
	-- Possibly update any jobs in T_Analysis_Description that are in state 48
	---------------------------------------------------
	--
	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'IgnoreGANETJobRegressionFailure')
	If @result = 1
	begin
		UPDATE T_Analysis_Description
		SET Process_State = @NextProcessState, Last_Affected = GetDate()
		WHERE Process_State = 48
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myRowCount > 0
		Begin
			Set @message = 'Advanced process state for ' + convert(varchar(11), @myRowCount)
			if @myRowCount = 1
				Set @message = @message + ' job '
			else
				Set @message = @message + ' jobs '
			--
			Set @message = @message + 'that had failed GANET regression since IgnoreGANETJobRegressionFailure is enabled'
			--
			execute PostLogEntry 'Normal', @message, 'MasterUpdateNET'
		End		
	end
	

	--------------------------------------------------------------
	-- Look for and drop any old NET Export views and tables
	--------------------------------------------------------------
	--
	Exec DropOldNETExportViews 'V_NET_Export_Peptides_Task_%', @DropViews = 1
	
	Exec DropOldNETExportViews 'T_Tmp_NET_Export_Task_%', @DropViews = 0


	--------------------------------------------------------------
	-- Normal Exit
	--------------------------------------------------------------

	set @message = 'End Master Update NET for ' + DB_NAME() + ': ' + convert(varchar(32), @myError)
	
Done:
	If (@logLevel >=1 AND @myError <> 0)
		execute PostLogEntry 'Error', @message, 'MasterUpdateNET'
	Else
	If (@logLevel >=1 And @numJobsProcessed > 0) OR @logLevel >= 2
		execute PostLogEntry 'Normal', @message, 'MasterUpdateNET'

	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[MasterUpdateNET] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[MasterUpdateNET] TO [MTS_DB_Lite]
GO
