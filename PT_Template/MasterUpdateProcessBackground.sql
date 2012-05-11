/****** Object:  StoredProcedure [dbo].[MasterUpdateProcessBackground] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure MasterUpdateProcessBackground
/****************************************************
** 
**	Desc: 
**		Filtering and sequence modification checks
**		are performed on newly imported peptides and
**		the results saved in the database 
**
**		Return values: 0: success, otherwise, error code
** 
**		Parameters:
**
**	Auth:	grk
**	Date:	07/15/2004
**			07/21/2004 mem - Added some @logLevel statements
**			07/30/2004 grk - modified subprocess calls for new PTDB design
**			08/07/2004 mem - Added @numJobsToProcess parameter and use of @count
**			11/04/2004 mem - Moved Load Peptides code to here from MasterUpdateProcessImport
**			12/12/2004 mem - Added call to MasterUpdateDatasets
**			01/22/2005 mem - Added @MinNETRSquared parameter when calling MasterUpdateNET
**			01/31/2005 mem - Added call to ResetChangedAnalysisJobs
**			02/16/2005 mem - Now checking for AssignMasterSequenceIDs in T_Process_Step_Control
**			05/28/2005 mem - Updated call to MasterUpdateNET to reflect switch to using T_NET_Update_Task
**			07/08/2005 mem - Added call to RefreshAnalysisDescriptionInfo
**						   - Now looking up General_Statistics_Update_Interval and Job_Info_DMS_Update_Interval in T_Process_Config
**			09/30/2005 mem - Added call to UpdatePeptideSICStats
**			10/31/2005 mem - Added call to CheckStaleJobs
**			11/10/2005 mem - Added second call to UpdatePeptideSICStats, this time for jobs in state 35
**			11/26/2005 mem - Now passing @ProcessStateFilterEvaluationRequired to CheckAllFiltersForAvailableAnalyses
**			03/11/2006 mem - Now calling VerifyUpdateEnabled
**			03/18/2006 mem - Added call to ComputeMaxObsAreaForAvailableAnalyses
**			07/06/2006 mem - Added call to ProcessPeptideProphetTasks and updated call to CheckAllFiltersForAvailableAnalyses
**			08/02/2006 mem - Added call to SetReversedAndScrambledJobsToHolding
**			08/25/2006 mem - Now posting log entry before calling UpdatePeptideSICStats if any jobs are in state 20
**			12/02/2006 mem - Added a second call to CheckStaleJobs
**			10/29/2008 mem - Added call to ComputeInspectMassValuesForAvailableAnalyses
**			11/01/2009 mem - Added call to UpdateProteinDataForAvailableAnalyses
**			11/02/2009 mem - Added call to CalculateCleavageStateForAvailableAnalyses
**			10/12/2010 mem - Added call to ResetLoadFailedJobs
**			08/22/2011 mem - Removed call to CalculateCleavageStateForAvailableAnalyses
**			12/23/2011 mem - Added call to UpdateResultsForAvailableAnalyses
**    
*****************************************************/
(
	@numJobsToProcess int = 50000,
	@GeneralStatsUpdateInterval int = 13			-- Minimum interval in hours to call UpdateGeneralStatistics
)
As

	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @result int
	declare @ganetEnabled int
	declare @count int
	declare @count2 int
	declare @UpdateEnabled tinyint
	
	declare @logLevel int
	set @logLevel = 1		-- Default to normal logging

	declare @ProcessStateMatch int
	declare @NextProcessState int
	
	declare @message varchar(255)

	declare @PeptideDatabase varchar(128)
	set @PeptideDatabase = DB_Name()

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateProcessBackground', @AllowPausing = 0, @UpdateEnabled = @UpdateEnabled output, @message = @message output
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

	set @message = 'Begin Master Update for ' + @PeptideDatabase
	If @logLevel >= 2
		execute PostLogEntry 'Normal', @message, 'MasterUpdateProcessBackground'

	-- < A1 >
	--------------------------------------------------------------
	-- Look for Jobs with different Results_Folder values from DMS
	--------------------------------------------------------------
	--
	Set @NextProcessState = 10

	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'ResetChangedAnalysisJobs')
	If @result = 0
	begin
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Skipped ResetChangedAnalysisJobs', 'MasterUpdateProcessBackground'
	end
	else
	begin
		EXEC @result = ResetChangedAnalysisJobs @NextProcessState
	end

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateProcessBackground', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done


	-- < A2 >
	--------------------------------------------------------------
	-- Look for Jobs in state 9 that need to be retried
	--------------------------------------------------------------
	--
	exec @result = ResetLoadFailedJobs @infoonly = 0
	
	-- < B >
	--------------------------------------------------------------
	-- Load Peptides or SIC results for jobs in state 10
	--------------------------------------------------------------
	--
	-- Load Peptides from analyses	
	-- 
	Set @ProcessStateMatch = 10
	Set @NextProcessState = 15

	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'LoadAnalysisResults')
	If @result = 0
	begin
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Skipped LoadAnalysisResults', 'MasterUpdateProcessBackground'
	end
	else
	begin
		EXEC @result = LoadResultsForAvailableAnalyses @ProcessStateMatch, @NextProcessState, @numJobsToProcess, @count OUTPUT

		set @message = 'Completed loading peptides for available analyses: ' + convert(varchar(11), @count) + ' jobs processed'
		if @count > 0 and @logLevel >= 1
			execute PostLogEntry 'Normal', @message, 'MasterUpdateProcessBackground'
	end

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateProcessBackground', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done



	-- < B2 >
	--------------------------------------------------------------
	-- Update the protein data for jobs in state 15
	--------------------------------------------------------------
	--
	-- Load Peptides from analyses	
	-- 
	Set @ProcessStateMatch = 15
	Set @NextProcessState = 20

	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'UpdateProteinData')
	If @result = 0
	begin
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Skipped UpdateProteinData', 'MasterUpdateProcessBackground'
	end
	else
	begin
		EXEC @result = UpdateProteinDataForAvailableAnalyses @ProcessStateMatch, @NextProcessState, @numJobsToProcess, @count OUTPUT

		set @message = 'Completed updating proteins for available analyses: ' + convert(varchar(11), @count) + ' jobs processed'
		if @count > 0 and @logLevel >= 1
			execute PostLogEntry 'Normal', @message, 'MasterUpdateProcessBackground'
	end

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateProcessBackground', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done


	-- < C >
	--------------------------------------------------------------
	-- Update the mapping between dataset and SIC job
	--------------------------------------------------------------
	--
	EXEC @result = MasterUpdateDatasets @numJobsToProcess
	
	-- < D >
	--------------------------------------------------------------
	-- Populate the SIC columns in T_Peptides
	--------------------------------------------------------------
	--
	Set @ProcessStateMatch = 20
	Set @NextProcessState = 25

	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'UpdatePeptideSICStats')
	If @result = 0
	begin
		-- Note that if we skip updating SIC Stats, then NET regression will fail because Scan_Time_Peak_Apex will be Null
		-- Additionally, view V_Peptide_Export will also contain Null values for Scan_Time_Peak_Apex
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Skipped UpdatePeptideSICStats for jobs in State 20', 'MasterUpdateProcessBackground'
	end
	else
	begin
		If @logLevel >= 1
		Begin
			-- See if any jobs have state @ProcessStateMatch
			-- If they do, post a log entry that we are calling UpdatePeptideSICStats, since this can sometimes take awhile, 
			--  particularly if the database's indices are corrupt and need to be re-created using DBCC DBREINDEX (T_Peptides, '', 90)
			Set @count = 0
			SELECT @count = COUNT(*)
			FROM T_Analysis_Description
			WHERE Process_State = @ProcessStateMatch
			
			If @count > 0
			Begin
				Set @message = 'Updating SIC stats in T_Peptides for available analyses in State ' + Convert(varchar(9), @ProcessStateMatch)
				execute PostLogEntry 'Normal', @message, 'MasterUpdateProcessBackground'
				Set @message = ''
			End
			
			Set @count = 0
		End		
				
		EXEC @result = UpdatePeptideSICStats @ProcessStateMatch, @NextProcessState, @numJobsToProcess, @count OUTPUT, @count2 OUTPUT

		set @message = 'Completed updating SIC stats in T_Peptides for available analyses in State ' + Convert(varchar(9), @ProcessStateMatch) + ': ' + convert(varchar(11), @count) + ' jobs processed and ' + Convert(varchar(11), @count2) + ' advanced to next state'
		if @count > 0 and @logLevel >= 1
			execute PostLogEntry 'Normal', @message, 'MasterUpdateProcessBackground'
	end	

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateProcessBackground', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done

	-- < E >
	--------------------------------------------------------------
	-- Look for jobs in state 25 that were searched against a reversed or scrambled database
	-- Update their states from 25 to 6 if enabled in T_Process_Step_Control
	--------------------------------------------------------------
	--
	Set @ProcessStateMatch = 25
	Set @NextProcessState = 6

	-- See if Hold Reversed And Scrambled Jobs is enabled; assume, by default, that it is enabled
	-- If it isn't, then skip this section

	set @result = 1
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'HoldReversedAndScrambledJobs')
	If @result = 0
	begin
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Skipped SetReversedAndScrambledJobsToHolding', 'MasterUpdateProcessBackground'
	end
	Else
	begin
		EXEC @result =  SetReversedAndScrambledJobsToHolding @ProcessStateMatch, @NextProcessState, @count OUTPUT

		set @message = 'Completed update SetReversedAndScrambledJobsToHolding: ' + convert(varchar(11), @count) + ' jobs set to holding'
		If @logLevel >= 1 and @count > 0
			execute PostLogEntry 'Normal', @message, 'MasterUpdateProcessBackground'
	end

	
	-- < F >
	--------------------------------------------------------------
	-- Resolve master sequence ID for each peptide in each new job
	--------------------------------------------------------------
	--
	Set @ProcessStateMatch = 25
	Set @NextProcessState = 30

	-- See if Master Sequence ID assignment is enabled; assume, by default, that it is enabled
	-- If it isn't, we can't perform any other processing steps, so jump to CalculateStatistics

	set @result = 1
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'AssignMasterSequenceIDs')
	If @result = 0
	begin
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Skipped UpdateSequenceModsForAvailableAnalyses', 'MasterUpdateProcessBackground'
			
		Goto CalculateStatistics
	end
	Else
	begin
		EXEC @result = UpdateSequenceModsForAvailableAnalyses @ProcessStateMatch, @NextProcessState, @numJobsToProcess, @count OUTPUT

		set @message = 'Completed update sequence modifications for available analyses: ' + convert(varchar(11), @count) + ' jobs processed'
		If @logLevel >= 1 and @count > 0
			execute PostLogEntry 'Normal', @message, 'MasterUpdateProcessBackground'
	end

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateProcessBackground', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done

	-- < G >
	--------------------------------------------------------------
	-- Verify sequence information
	--  Refresh local sequences table from master sequence DB and
	--  verify that monoisotopic mass calcs have been done
	--------------------------------------------------------------
	--
	Set @ProcessStateMatch = 30
	Set @NextProcessState = 33				-- Changed from 31 to 33 in August 2011

	-- Perform this subprocess if it is enabled
	--
	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'VerifySequenceInfo')
	If @result = 0
	begin
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Skipped VerifySequenceInfo', 'MasterUpdateProcessBackground'
	end
	Else
	begin
		EXEC @result = VerifySequenceInfo @ProcessStateMatch, @NextProcessState, @numJobsToProcess, @count OUTPUT, @count2 OUTPUT

		set @message = 'Completed VerifySequenceInfo: ' + convert(varchar(11), @count) + ' jobs processed and ' + convert(varchar(11), @count2) + ' advanced to next state'
		If @logLevel >= 1 and @count > 0
			execute PostLogEntry 'Normal', @message, 'MasterUpdateProcessBackground'
	end

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateProcessBackground', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done

	-- < G2 >
	--------------------------------------------------------------
	-- Calculate cleavage state and terminus state
	-- Note: disabled in August 2011 since stored procedure CalculateCleavageStateUsingProteinSequence is not complete
	-- (this information should have already been computed by PHRP)
	--------------------------------------------------------------
	--
	/*
	Set @ProcessStateMatch = 31
	Set @NextProcessState = 33

	-- Perform this subprocess if it is enabled
	--
	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'CalculateCleavageState')
	If @result = 0
	begin
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Skipped CalculateCleavageState', 'MasterUpdateProcessBackground'
	end
	Else
	begin
		EXEC @result = CalculateCleavageStateForAvailableAnalyses @ProcessStateMatch, @NextProcessState, @numJobsToProcess, @count OUTPUT

		set @message = 'Completed CalculateCleavageState: ' + convert(varchar(11), @count) + ' jobs processed'
		If @logLevel >= 1 and @count > 0
			execute PostLogEntry 'Normal', @message, 'MasterUpdateProcessBackground'
	end

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateProcessBackground', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done
	*/
	
	-- < H >
	--------------------------------------------------------------
	-- Populate Max_Obs_Area_In_Job in T_Peptides
	--------------------------------------------------------------
	--
	Set @ProcessStateMatch = 33
	Set @NextProcessState = 37

	-- Perform this subprocess if it is enabled
	--
	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'ComputeMaxObsArea')
	If @result = 0
	begin
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Skipped ComputeMaxObsArea', 'MasterUpdateProcessBackground'
	end
	Else
	begin
		Declare @PostLogEntryOnSuccess tinyint
		If @logLevel >= 2
			Set @PostLogEntryOnSuccess = 1
		Else
			Set @PostLogEntryOnSuccess = 0
			
		EXEC @result = ComputeMaxObsAreaForAvailableAnalyses @ProcessStateMatch, @NextProcessState, @numJobsToProcess, @PostLogEntryOnSuccess, @numJobsProcessed = @count OUTPUT

		set @message = 'Completed ComputeMaxObsAreaForAvailableAnalyses: ' + convert(varchar(11), @count) + ' jobs processed'
		If @logLevel >= 1 and @count > 0
			execute PostLogEntry 'Normal', @message, 'MasterUpdateProcessBackground'
	end

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateProcessBackground', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done
		
	-- < I >
	--------------------------------------------------------------
	-- Update the SIC columns in T_Peptides for jobs that were reset to state 35
	--------------------------------------------------------------
	--
	Set @ProcessStateMatch = 35
	Set @NextProcessState = 37

	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'UpdatePeptideSICStats')
	If @result = 0
	begin
		-- Note that if we skip updating SIC Stats, then NET regression will fail because Scan_Time_Peak_Apex will be Null
		-- Additionally, view V_Peptide_Export will also contain Null values for Scan_Time_Peak_Apex
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Skipped UpdatePeptideSICStats for jobs in State 35', 'MasterUpdateProcessBackground'
	end
	else
	begin
		EXEC @result = UpdatePeptideSICStats @ProcessStateMatch, @NextProcessState, @numJobsToProcess, @count OUTPUT, @count2 OUTPUT

		set @message = 'Completed updating SIC stats in T_Peptides for available analyses in State ' + Convert(varchar(9), @ProcessStateMatch) + ': ' + convert(varchar(11), @count) + ' jobs processed and ' + Convert(varchar(11), @count2) + ' advanced to next state'
		iF @count > 0 and @logLevel >= 1
			execute PostLogEntry 'Normal', @message, 'MasterUpdateProcessBackground'
	end	

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateProcessBackground', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done

	-- < J >
	--------------------------------------------------------------
	-- Compute MH and DelM for Inspect Jobs
	--------------------------------------------------------------
	--
	Set @ProcessStateMatch = 37
	Set @NextProcessState = 40

	-- See if GANET regression is disabled
	-- If it is, set @NextProcessState to 50 instead of 40
	--
	set @ganetEnabled = 0
	SELECT @ganetEnabled = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'GANETJobRegression')
	If @ganetEnabled = 0
	begin
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Skipped GANETJobRegression', 'MasterUpdateProcessBackground'
		Set @NextProcessState = 50
	end

	-- Note that @result defaults to 1, so that this step is enabled if no entry is present in T_Process_Step_Control
	set @result = 1
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'ComputeInspectMassValues')
	If @result = 0
	begin
		-- Note that if we skip computing the mass values, then MH and DelM will be null, which can affect downstream processing
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Skipped ComputeInspectMassValues for jobs in State 37', 'MasterUpdateProcessBackground'
	end
	else
	begin
		EXEC @result = ComputeInspectMassValuesForAvailableAnalyses @ProcessStateMatch, @NextProcessState, @numJobsToProcess, @count OUTPUT

		set @message = 'Completed computing Inspect mass values in T_Peptides for available analyses in State ' + Convert(varchar(9), @ProcessStateMatch) + ': ' + convert(varchar(11), @count) + ' jobs processed'
		If @logLevel >= 1 and @count > 0
			execute PostLogEntry 'Normal', @message, 'MasterUpdateProcessBackground'
	end	

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateProcessBackground', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done
		
	-- < K >
	--------------------------------------------------------------
	-- Call MasterUpdateNET (provided GANET processing is enabled)
	--------------------------------------------------------------
	--
	declare @MinNETFit real				-- Legacy, no longer used
	declare @MinNETRSquared real
	Set @MinNETFit = 0.8
	Set @MinNETRSquared = 0.1
	
	Set @NextProcessState = 50

	if @ganetEnabled = 0
	begin
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Skipped MasterUpdateNET', 'MasterUpdateProcessBackground'	
	end
	Else
	begin
		EXEC @result = MasterUpdateNET @NextProcessState, @MinNETRSquared, @message OUTPUT, @numJobsToProcess

		set @message = 'Completed MasterUpdateProcessNET: ' + convert(varchar(11), @result)
		If (@result <> 0 And @logLevel >= 1) Or @logLevel >= 2
			execute PostLogEntry 'Normal', @message, 'MasterUpdateProcessBackground'
	end

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateProcessBackground', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done

	-- < L >
	--------------------------------------------------------------
	-- Calculate confidence scores for each peptide in each new job
	--------------------------------------------------------------
	--
	Set @ProcessStateMatch = 50
	Set @NextProcessState = 90
	
	Declare @NextProcessStateSkipPeptideProphet int
	Set @NextProcessStateSkipPeptideProphet = 60

	-- Perform this subprocess if it is enabled
	--
	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'CalculateConfidenceScore')
	If @result = 0
	begin
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Skipped CalculateConfidenceScore', 'MasterUpdateProcessBackground'
	end
	Else
	begin
		EXEC @result = CalculateConfidenceScores @ProcessStateMatch, @NextProcessState, @NextProcessStateSkipPeptideProphet, 
												 @numJobsToProcess, @count OUTPUT

		set @message = 'Completed calculating confidence scores for available analyses: ' + convert(varchar(11), @count) + ' jobs processed'
		If @logLevel >= 1 and @count > 0
			execute PostLogEntry 'Normal', @message, 'MasterUpdateProcessBackground'
	end

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateProcessBackground', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done


	-- < M1 >
	--------------------------------------------------------------
	-- Peptide Prophet processing
	--------------------------------------------------------------
	--
	Set @NextProcessState = 60
	
	-- Perform this subprocess if it is enabled
	--
	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'PeptideProphetProcessing')
	If @result = 0
	begin
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Skipped ProcessPeptideProphetTasks', 'MasterUpdateProcessBackground'
	end
	Else
	begin
		-- Since peptide prophet task loading is generally quite fast, we'll us @numJobsToProcess * 5 if @numJobsToProcess is 5 or more
		Declare @numJobsToProcessPProphet int
		if @numJobsToProcess >= 5
			Set @numJobsToProcessPProphet = @numJobsToProcess*5
		else
			Set @numJobsToProcessPProphet = @numJobsToProcess
			
		EXEC @result = ProcessPeptideProphetTasks @NextProcessState, @message OUTPUT, @numJobsToProcessPProphet

		set @message = 'Completed ProcessPeptideProphetTasks: ' + convert(varchar(11), @result)
		If (@result <> 0 And @logLevel >= 1) Or @logLevel >= 2
			execute PostLogEntry 'Normal', @message, 'MasterUpdateProcessBackground'
	end

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateProcessBackground', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done
	
	
	
	-- < M2 >
	--------------------------------------------------------------
	-- Re-load peptide data for jobs with state 55
	--------------------------------------------------------------
	--
	Set @ProcessStateMatch = 55
	Set @NextProcessState = 60
	
	-- Perform this subprocess if it is enabled
	--
	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'UpdateResultsForAvailableAnalyses')
	If @result = 0
	begin
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Skipped UpdateResultsForAvailableAnalyses', 'MasterUpdateProcessBackground'
	end
	Else
	begin
		EXEC @result = UpdateResultsForAvailableAnalyses @ProcessStateMatch, @NextProcessState, @numJobsToProcess, @count OUTPUT

		set @message = 'Completed updating results for available analyses: ' + convert(varchar(11), @count) + ' jobs processed'
		If @logLevel >= 1 and @count > 0
			execute PostLogEntry 'Normal', @message, 'MasterUpdateProcessBackground'
	end

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateProcessBackground', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done
		
	
	-- < N >
	--------------------------------------------------------------
	-- Calculate filter results for each peptide in each new job
	--------------------------------------------------------------
	--
	Set @ProcessStateMatch = 60
	Set @NextProcessState = 70

	Declare @ProcessStateFilterEvaluationRequired int
	Set @ProcessStateFilterEvaluationRequired = 65
	
	Declare @ProcessStateAllStepsComplete int
	Set @ProcessStateAllStepsComplete = 70			-- Update this if additional steps are added below

	-- Perform this subprocess if it is enabled
	--
	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'CalculateFilterResults')
	If @result = 0
	begin
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Skipped CalculateFilterResults', 'MasterUpdateProcessBackground'
	end
	Else
	begin
		EXEC @result = CheckAllFiltersForAvailableAnalyses @ProcessStateMatch, @ProcessStateFilterEvaluationRequired, 
														   @NextProcessState, @ProcessStateAllStepsComplete,
														   @numJobsToProcess, @count OUTPUT

		set @message = 'Completed check all filters for available analyses: ' + convert(varchar(11), @count) + ' jobs processed'
		If @logLevel >= 1 and @count > 0
			execute PostLogEntry 'Normal', @message, 'MasterUpdateProcessBackground'
	end

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateProcessBackground', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done


CalculateStatistics:
	
	-- < O >
	--------------------------------------------------------------
	-- Update general statistics
	--------------------------------------------------------------
	--
	-- Look up the Last Update date stored in T_General_Statistics
	
	Declare @ValueText varchar(64)
	Declare @UpdateInterval int
	
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
		execute PostLogEntry 'Error', @message, 'MasterUpdateProcessBackground'
		Goto Done
	End
	
	-- Lookup the value for General_Statistics_Update_Interval in T_Process_Config
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
	
	If GetDate() > DateAdd(hour, @UpdateInterval, @LastUpdated) OR @myRowCount = 0
	Begin
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Begin UpdateGeneralStatistics', 'MasterUpdateProcessBackground'
		EXEC @result = UpdateGeneralStatistics
		--
		set @message = 'Complete UpdateGeneralStatistics: ' + convert(varchar(32), @result)
		If @logLevel >= 1
			execute PostLogEntry 'Normal', @message, 'MasterUpdateProcessBackground'
	End
	else
		If @logLevel >= 3
		begin
			set @message = 'Skipping UpdateGeneralStatistics since ' + Convert(varchar(32), @UpdateInterval) + ' hours have not yet elapsed'
			execute PostLogEntry 'Normal', @message, 'MasterUpdateProcessBackground'
		end

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateProcessBackground', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done

	-- < P >
	-------------------------------------------------------------
	-- Synchronize the analysis description information with DMS
	-------------------------------------------------------------
	--
	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'RefreshAnalysisDescriptionInfo')
	if @result > 0
	begin

		-- Lookup the value for Job_Info_DMS_Update_Interval in T_Process_Config
		SELECT @ValueText = Value
		FROM T_Process_Config
		WHERE [Name] = 'Job_Info_DMS_Update_Interval'
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--	
		If IsNumeric(@ValueText) <> 0
			Set @UpdateInterval = Convert(int, @ValueText)
		Else
			Set @UpdateInterval = 30
			
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Begin RefreshAnalysisDescriptionInfo', 'MasterUpdateProcessBackground'
		exec @result = RefreshAnalysisDescriptionInfo @UpdateInterval, @message OUTPUT
		set @message = 'Complete ' + @message
	end
	else
		set @message = 'Skipped RefreshAnalysisDescriptionInfo'
	--
	If @logLevel >= 2
		execute PostLogEntry 'Normal', @message, 'MasterUpdateProcessBackground'

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateProcessBackground', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done

	-- < Q >
	-------------------------------------------------------------
	-- Look for stale jobs
	-------------------------------------------------------------
	--
	Declare @maxHoursProcessing int
	Declare @JobProcessingStateMin int
	Declare @JobProcessingStateMax int
	set @maxHoursProcessing = 48

	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'CheckStaleJobs')
	if @result > 0
	begin
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Begin CheckStaleJobs', 'MasterUpdateProcessBackground'
		
		-- Call CheckStaleJobs for states 10 to 69
		set @JobProcessingStateMin = 10
		set @JobProcessingStateMax = 69
		exec @result = CheckStaleJobs @maxHoursProcessing, @JobProcessingStateMin, @JobProcessingStateMax, @message = @message OUTPUT

		-- Call CheckStaleJobs agains for states 90 to 150
		set @JobProcessingStateMin = 90
		set @JobProcessingStateMax = 150
		exec @result = CheckStaleJobs @maxHoursProcessing, @JobProcessingStateMin, @JobProcessingStateMax, @message = @message OUTPUT
		
		set @message = 'Complete ' + @message
	end
	else
		set @message = 'Skipped CheckStaleJobs'
	--
	If @logLevel >= 2
		execute PostLogEntry 'Normal', @message, 'MasterUpdateProcessBackground'

	--------------------------------------------------------------
	-- Normal Exit
	--------------------------------------------------------------

	set @message = 'Completed master update for ' + @PeptideDatabase + ': ' + convert(varchar(32), @myError)

Done:
	If (@logLevel >=1 AND @myError <> 0)
		execute PostLogEntry 'Error', @message, 'MasterUpdateProcessBackground'
	Else
	If @logLevel >= 2
		execute PostLogEntry 'Normal', @message, 'MasterUpdateProcessBackground'

	return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[MasterUpdateProcessBackground] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[MasterUpdateProcessBackground] TO [MTS_DB_Lite] AS [dbo]
GO
