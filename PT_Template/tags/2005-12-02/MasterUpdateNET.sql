SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[MasterUpdateNET]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[MasterUpdateNET]
GO


CREATE Procedure dbo.MasterUpdateNET
/****************************************************
** 
**		Desc: 
**			Performs all the steps necessary to 
**			load NET regression results for available NET Update Tasks
**
**		Return values: 0: success, otherwise, error code
** 
**		Parameters:
**
**		Auth: grk
**		Date: 9/12/2003
**			  04/09/2004 mem - Added support for LogLevel
**			  07/05/2004 mem - Changed for use in Peptide DB's
**			  08/08/2004 mem - Added @ProcessStateMatch parameter and moved job processing code to MasterUpdateNETOneAnalysis
**			  09/15/2004 mem - Added @numJobsToProcess
**			  01/22/2005 mem - Added @MinNETRSquared parameter
**			  04/08/2005 mem - Updated call to GetGANETFolderPaths
**			  05/28/2005 mem - Switched to use T_NET_Update_Task and T_NET_Update_Task_Job_Map
**							 - Removed parameters @ProcessStateMatch and @MinNETFit
**			  05/30/2005 mem - Added call to DropOldNETExportViews for V_NET_Export_Peptides_Task% views
**			  07/28/2005 mem - Added call to DropOldNETExportViews for T_Tmp_NET_Export_Task% tables
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

	declare @result int,
			@logLevel int,
			@DeleteGANETFiles int,
			@JobsInTask int
	
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
	-- Verify that loading of GANET values is enabled
	--------------------------------------------------------------
	--
	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'GANETJobRegression')
	if @result = 0
	begin
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Skipped GANETJobRegression', 'MasterUpdateNET'
		goto Done
	end

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
	
	set @TaskID = 0
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
		-- Exit loop if no job found
		---------------------------------------------------

		if @TaskID = 0 OR @myRowCount = 0
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
	if (@logLevel >=1 And @numJobsProcessed > 0) OR @logLevel >= 2
		execute PostLogEntry 'Normal', @message, 'MasterUpdateNET'
	
Done:
	return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

