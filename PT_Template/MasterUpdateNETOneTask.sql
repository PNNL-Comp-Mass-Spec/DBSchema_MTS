/****** Object:  StoredProcedure [dbo].[MasterUpdateNETOneTask] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.MasterUpdateNETOneTask
/****************************************************
**
**	Desc: 
**		Loads the NET regression results for the given NET Update Task
**
**		Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	07/30/2004
**			01/22/2005 mem - Added @MinNETRSquared parameter
**			04/08/2005 mem - Renamed the filename and filepath parameters
**			05/28/2005 mem - Switched to use T_NET_Update_Task and T_NET_Update_Task_Job_Map
**						   - Removed the filename and filepath parameters, since now obtaining that information from T_NET_Update_Task
**						   - Removed the @MinNETFit parameter
**			07/04/2006 mem - Switched to using DeleteFiles and changed error code from 8 to 7 call to SetGANETUpdateTaskState if ComputePeptideNETBulk fails
**			03/17/2010 mem - Now calling LoadGANETObservedNETsFile
**			04/07/2010 mem - Now deleting the _ObsNET_vs_PNET_Filtered.txt file if @DeleteNETFiles = 1
**			03/25/2013 mem - Now keeping track of which information is loaded for each job
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

	declare @SourceFolderPath varchar(256)
	declare @SourceFileName varchar(256)	
	declare @JobStatsFileName varchar(256)
	declare @ObsNETvsPNETFileName varchar(256)
	
	declare @ResultsFolderPath varchar(256)
	declare @ResultsFileName varchar(256)
	declare @PredNETsFileName varchar(256)
	declare @ObsNETsFileName varchar(256)

	declare @GANETProcessingTimeoutState int = 44

	---------------------------------------------------
	-- Create temporary table to track the jobs processed by this NET update task
	---------------------------------------------------

	CREATE TABLE #Tmp_NET_Update_Jobs (
		Job int not null,
		RegressionInfoLoaded tinyint not null,
		ObservedNETsLoaded tinyint not null
	)
	
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
	
	SELECT 	@SourceFolderPath = Output_Folder_Path,
			@SourceFileName = Out_File_Name,
			@ResultsFolderPath = Results_Folder_Path, 
			@ResultsFileName = Results_File_Name,
			@PredNETsFileName = PredictNETs_File_Name,
			@ObsNETsFileName = ObservedNETs_File_Name
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
	-- Populate #Tmp_NET_Update_Jobs
	---------------------------------------------------
	--
	INSERT INTO #Tmp_NET_Update_Jobs (Job,
	                                  RegressionInfoLoaded,
	                                  ObservedNETsLoaded )
	SELECT J.Job, 0, 0
	FROM T_NET_Update_Task T
	     INNER JOIN T_NET_Update_Task_Job_Map J
	       ON T.Task_ID = J.Task_ID
	WHERE T.Task_ID = @TaskID

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

		goto UpdateJobStates
	end

	--------------------------------------------------------------
	-- Load contents of NET prediction file into
	-- T_Predicted_NET and T_Sequest
	--------------------------------------------------------------

	If @logLevel >= 2
		execute PostLogEntry 'Normal', 'Begin LoadGANETPredictionFile', 'MasterUpdateNETOneTask'
		
	EXEC @result = LoadGANETPredictionFile
										@PredNETsFileName,
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
			
		-- This is not a fatal error; continue loading data
	end



	--------------------------------------------------------------
	-- Load contents of Observed NETs file into T_Peptides
	--------------------------------------------------------------

	If @logLevel >= 2
		execute PostLogEntry 'Normal', 'Begin LoadGANETObservedNETsFile', 'MasterUpdateNETOneTask'
		
	EXEC @result = LoadGANETObservedNETsFile
										@ObsNETsFileName,
										@ResultsFolderPath,
										@message  output,
										@numLoaded output

	if @result = 0
	begin
		set @message = 'Complete LoadGANETObservedNETsFile: ' + @message
		If @logLevel >= 1
			EXEC PostLogEntry 'Normal', @message, 'MasterUpdateNETOneTask'
	end
	else
	begin
		set @message = 'Complete LoadGANETObservedNETsFile: ' + @message + ' (error ' + convert(varchar(32), @result) + ')'
		If @logLevel >= 1
			EXEC PostLogEntry 'Error', @message, 'MasterUpdateNETOneTask'
	end

	--------------------------------------------------------------
	-- Update NET values for Peptides in T_Peptides and T_Sequence
	--------------------------------------------------------------

	/*
	***************************************************************
	**
	** NOTE:
	**   Since we're now loading data from file ObservedNETsAfterRegression, 
	**   we no longer need to call ComputePeptideNETBulk,
	**   though we do need to check for any additional steps that it performs
	**
	***************************************************************
	*/
		
	-- If @logLevel >= 2
	-- 	execute PostLogEntry 'Normal', 'Begin ComputePeptideNETBulk', 'MasterUpdateNETOneTask'
	-- 
	-- EXEC @result = ComputePeptideNETBulk @TaskID, @MinNETRSquared, @message OUTPUT


	if @result = 0
	begin

		-- Set state of NET update task to state 5 = 'Update Complete'
		--
		Exec @myError = SetGANETUpdateTaskState @TaskID, 5, @NextProcessStateForJobs, @message output
		
		-- Delete the NET files if set to do so
		--
		if @myError = 0 AND @DeleteNETFiles = 1
		Begin
			Set @JobStatsFileName = Replace(@SourceFileName , 'peptideGANET_', 'jobStats_')
			Set @ObsNETvsPNETFileName = Replace(@ResultsFileName , '.txt', '_ObsNET_vs_PNET_Filtered.txt')

			Exec DeleteFiles @SourceFolderPath, @SourceFileName, @JobStatsFileName, @message = @message output
			Exec DeleteFiles @ResultsFolderPath, @ResultsFileName, @PredNETsFileName, @message = @message output
			Exec DeleteFiles @ResultsFolderPath, @ObsNETsFileName, @message = @message output			
			Exec DeleteFiles @ResultsFolderPath, @ObsNETvsPNETFileName, @message = @message output
		End
	end
	else
	begin
		-- Set state of NET update task to error
		--
		Set @myError = @Result
		exec SetGANETUpdateTaskState @TaskID, 7, @GANETProcessingTimeoutState, @message
	end


UpdateJobStates:

	If @result <> 0
	Begin
		-- One or more jobs failed NET regression
		-- Increment Regression_Failure_Count
		--
		UPDATE T_Analysis_Description
		SET Regression_Failure_Count = Regression_Failure_Count + 1
		WHERE Job IN ( SELECT Job
		               FROM #Tmp_NET_Update_Jobs
		               WHERE RegressionInfoLoaded = 0 OR
		                     ObservedNETsLoaded = 0 )

		-- Change the job state to 8 for any jobs that have failed NET regression 3 times
		--
		UPDATE T_Analysis_Description
		SET Process_State = 8,		-- NET Regression failed repeatedly
		    Last_Affected = GETDATE()
		WHERE Regression_Failure_Count >= 3 AND
		      Job IN ( SELECT Job
		               FROM #Tmp_NET_Update_Jobs
		               WHERE RegressionInfoLoaded = 0 OR
		                     ObservedNETsLoaded = 0 )
		                     
		
		-- Change the job state to @NextProcessStateForJobs for any jobs that 
		-- successfully loaded the regression information and observed NETs
		--
		UPDATE T_Analysis_Description
		SET Process_State = @NextProcessStateForJobs,
		    Last_Affected = GETDATE()
		WHERE Job IN ( SELECT Job
		               FROM #Tmp_NET_Update_Jobs
		               WHERE RegressionInfoLoaded = 1 AND
		                     ObservedNETsLoaded = 1 )

	End
	

Done:
	return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[MasterUpdateNETOneTask] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[MasterUpdateNETOneTask] TO [MTS_DB_Lite] AS [dbo]
GO
