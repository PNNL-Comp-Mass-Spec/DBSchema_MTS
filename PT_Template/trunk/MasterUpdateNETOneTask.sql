SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[MasterUpdateNETOneTask]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[MasterUpdateNETOneTask]
GO


create Procedure dbo.MasterUpdateNETOneTask
/****************************************************
**
**	Desc: 
**		Loads the NET regression results for the given NET Update Task
**
**		Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**		Auth: mem
**		Date: 07/30/2004
**			  01/22/2005 mem - Added @MinNETRSquared parameter
**			  04/08/2005 mem - Renamed the filename and filepath parameters
**			  05/28/2005 mem - Switched to use T_NET_Update_Task and T_NET_Update_Task_Job_Map
**							 - Removed the filename and filepath parameters, since now obtaining that information from T_NET_Update_Task
**							 - Removed the @MinNETFit parameter
**    
*****************************************************/
(
	@TaskID int,
	@NextProcessStateForJobs int = 50,
	@DeleteNETFiles int,
	@logLevel int,
	@MinNETRSquared real = 0.1,
	@message varchar(255) = '' output
)
As

	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @numLoaded int

	declare @result int

	declare @outFolderPath varchar(256)
	declare @outFileName varchar(256)
	declare @ResultsFolderPath varchar(256)
	declare @ResultsFileName varchar(256)
	declare @predFileName varchar(256)

	declare @GANETProcessingTimeoutState int
	set @GANETProcessingTimeoutState = 44

	---------------------------------------------------
	-- Possibly log that we are loading NET results
	---------------------------------------------------
	--
	set @message = 'Load NET results for TaskID ' + Convert(varchar(12), @TaskID)
	If @logLevel >= 2
		execute PostLogEntry 'Normal', @message, 'MasterUpdateNETOneTask'

	---------------------------------------------------
	-- Update state for task to 4 = 'Results Loading'
	---------------------------------------------------
	--
	Exec @myError = SetGANETUpdateTaskState @TaskID, 4, Null, @message output

	---------------------------------------------------
	-- Lookup the results folder path and file names from T_NET_Update_Task
	---------------------------------------------------
	
	SELECT 	@outFolderPath = Output_Folder_Path,
			@outFileName = Out_File_Name,
			@ResultsFolderPath = Results_Folder_Path, 
			@ResultsFileName = Results_File_Name,
			@predFileName = PredictNETs_File_Name
	FROM T_NET_Update_Task
	WHERE Task_ID = @TaskID
	--
	SELECT @myError = @@error
	--
	if @myError <> 0
	begin
		goto Done
	end


	---------------------------------------------------
	-- Load contents of NET result file into analysis description table
	---------------------------------------------------
	--
	If @logLevel >= 2
		execute PostLogEntry 'Normal', 'Begin LoadGANETJobFile', 'MasterUpdateNETOneTask'
	EXEC @result = LoadGANETJobFile
										@ResultsFileName,
										@ResultsFolderPath,
										@message  output,
										@numLoaded output

	if @result = 0
	begin
		set @message = 'Complete LoadGANETJobFile: ' + @message
		If @logLevel >= 2
			EXEC PostLogEntry 'Normal', @message, 'MasterUpdateNETOneTask'
	end
	else
	begin
		set @message = 'Complete LoadGANETJobFile: ' + @message + ' (error ' + convert(varchar(32), @result) + ')'
		If @logLevel >= 1
			EXEC PostLogEntry 'Error', @message, 'MasterUpdateNETOneTask'

		Set @myError = @result
		Exec SetGANETUpdateTaskState @TaskID, 7, @GANETProcessingTimeoutState, @message output

		goto Done
	end

	--------------------------------------------------------------
	-- Load contents of NET prediction file into
	-- T_Predicted_NET and T_Mass_Tags_NET
	--------------------------------------------------------------

	If @logLevel >= 2
		execute PostLogEntry 'Normal', 'Begin LoadGANETPredictionFile', 'MasterUpdateNETOneTask'
		
	EXEC @result = LoadGANETPredictionFile
										@predFileName,
										@ResultsFolderPath,
										@message  output,
										@numLoaded output

	if @result = 0
	begin
		set @message = 'Complete LoadGANETPredictionFile: ' + @message
		If @logLevel >= 1
			EXEC PostLogEntry 'Normal', @message, 'MasterUpdateNETOneTask'
	end
	else
	begin
		set @message = 'Complete LoadGANETPredictionFile: ' + @message + ' (error ' + convert(varchar(32), @result) + ')'
		If @logLevel >= 1
			EXEC PostLogEntry 'Error', @message, 'MasterUpdateNETOneTask'
	end

	--------------------------------------------------------------
	-- Update NET values for Peptides in T_Peptides and T_Sequence
	--------------------------------------------------------------
	
	If @logLevel >= 2
		execute PostLogEntry 'Normal', 'Begin ComputePeptideNETBulk', 'MasterUpdateNETOneTask'

	EXEC @result = ComputePeptideNETBulk @TaskID, @MinNETRSquared, @message OUTPUT

	if @result = 0
	begin

		-- Set state of NET update task to state 5 = 'Update Complete'
		--
		Exec @myError = SetGANETUpdateTaskState @TaskID, 5, @NextProcessStateForJobs, @message output
		
		-- Delete the NET files if set to do so
		--
		if @myError = 0 AND @DeleteNETFiles = 1
			Exec DeleteGANETFiles 	@outFileName,
									@outFolderPath,
									@ResultsFileName,
									@ResultsFolderPath,
									@predFileName,
									@message  output
	end
	else
	begin
		-- Set state of NET update task to error
		--
		Set @myError = @Result
		exec SetGANETUpdateTaskState @TaskID, 8, @GANETProcessingTimeoutState, @message
	end

Done:
	return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

