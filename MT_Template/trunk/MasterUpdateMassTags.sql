SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[MasterUpdateMassTags]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[MasterUpdateMassTags]
GO



CREATE PROCEDURE dbo.MasterUpdateMassTags
/****************************************************
** 
**		Desc: 
**			Performs all the steps necessary to 
**			bring the status of the mass tag table
**			to be current with the state of DMS
**
**			Also schedules GANET update task
**
**		Return values: 0: success, otherwise, error code
** 
**		Parameters:
**
**		Auth: grk
**		Date: 11/20/2003
**			  11/26/2003 grk - modified to add peak matching tasks from FTICR import count
**			  04/08/2003 mem - Added ForceLCQProcessingOnNextUpdate option
**							 - Added call to ComputePMTQualityScore
**							 - Enabled optional call to CalculateMonoisotopicMass
**							 - Removed call to AddDefaultPeakMatchingTasks (now in MasterUpdateNET)
**							 - Changed instances of AddGANETUpateTask to AddGANETUpdateTask
**			  04/09/2004 mem - Added support for LogLevel
**							 - Limiting call to UpdateGeneralStatistics to be every @GeneralStatsUpdateInterval hours
**			  06/12/2004 mem - Added call to SynchronizeCoverageTable
**			  09/29/2004 mem - Updated to new MTDB schema and added @numJobsToProcess and @skipImport parameters
**			  10/15/2004 mem - Added call to RefreshMSMSJobNETs
**			  10/17/2004 mem - Now updating general statistics if any new MS/MS jobs are loaded
**			  10/18/2004 mem - Re-enabled optional call to CalculateMonoisotopicMass
**			  03/14/2005 mem - Added optional call to RunCustomSPs
**			  04/08/2005 mem - Changed GANET export call to use ExportGANETData
**			  04/10/2005 mem - Now calling CheckStaleTasks to look for tasks stuck in processing
**			  07/08/2005 mem - Added call to RefreshAnalysisDescriptionInfo
**							 - Now looking up General_Statistics_Update_Interval and Job_Info_DMS_Update_Interval in T_Process_Config
**			  08/13/2005 mem - Fixed logic bug involving determining whether general statistics should be updated
**			  10/12/2005 mem - Added call to RefreshMSMSSICJobs (which will cascade into RefreshMSMSSICStats for any updated jobs)
**							 - When performing LCQ Processing, now assuring Enabled = 0 for 'ForceLCQProcessingOnNextUpdate' in T_Process_Step_Control
**			  11/27/2005 mem - Now checking the return value of ExportGANETData and storing the message as an error if non-zero
**    
*****************************************************/
(
	@numJobsToProcess int = 50000,
	@skipImport tinyint = 0,						-- Set to 1 to skip job import steps and Add peak matching tasks step
	@message varchar(255) = '' output,
	@GeneralStatsUpdateInterval int = 13			-- Minimum interval in hours to call UpdateGeneralStatistics (overridden if defined in T_Process_Config)
)
As
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @result int
	declare @logLevel int
	
	set @result = 0
	set @logLevel = 1		-- Default to normal logging

	declare @ForceGeneralStatisticsUpdate tinyint
	declare @ComputeProteinCoverage tinyint
	declare @ProteinCoverageComputed tinyint
	
	set @ForceGeneralStatisticsUpdate = 0
	set @ComputeProteinCoverage = 0
	set @ProteinCoverageComputed = 0
	
	--------------------------------------------------------------
	-- Lookup the LogLevel state
	-- 0=Off, 1=Normal, 2=Verbose, 3=Debug
	--------------------------------------------------------------
	--
	set @result = @logLevel
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'LogLevel')
	Set @logLevel = @result

	set @message = 'Begin Master Update Mass Tags for ' + DB_NAME()
	If @logLevel > 1
		execute PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'


	-- < A >
	--------------------------------------------------------------
	-- import new LCQ analyses
	--------------------------------------------------------------
	--
	declare @entriesAdded int
	set @entriesAdded = 0
	--
	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'ImportLCQJobs')
	if @result > 0 And @skipImport <> 1
	begin
		-- Import new analyses for peptide identification from peptide database
		--
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Begin ImportLCQJobs', 'MasterUpdateMassTags'
		EXEC @result = ImportNewLCQAnalyses @entriesAdded OUTPUT, @message OUTPUT
		set @message = 'Complete ' + @message
	end
	else
		set @message = 'Skipped ImportLCQJobs'

	If @logLevel > 1 Or (@entriesAdded > 0 And @logLevel >= 1)
		execute PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'


	-- < B >
	--------------------------------------------------------------
	-- Update MSMS Job NET values
	--------------------------------------------------------------
	--
	declare @jobNETsUpdated int
	declare @peptideRowsUpdated int
	set @jobNETsUpdated = 0
	set @peptideRowsUpdated = 0
	--
	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'RefreshMSMSJobNets')
	if @result > 0 And @skipImport <> 1

	begin
		-- Look for Jobs in T_Analysis_Description with NET values differing from those in the associated Peptide DB
		--
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Begin RefreshMSMSJobNETs', 'MasterUpdateMassTags'
		EXEC @result = RefreshMSMSJobNETs @jobNETsUpdated OUTPUT, @peptideRowsUpdated OUTPUT, @message OUTPUT
		set @message = 'Complete ' + @message
	end
	else
		set @message = 'Skipped RefreshMSMSJobNETs'

	If @logLevel > 1 Or ((@jobNETsUpdated + @peptideRowsUpdated) > 0 And @logLevel >= 1)
		execute PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'


	-- < C >
	--------------------------------------------------------------
	-- Update MSMS SIC Jobs
	--------------------------------------------------------------
	--
	declare @jobsUpdated int
	set @jobsUpdated = 0
	--
	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'RefreshMSMSSICJobs')
	if @result > 0 And @skipImport <> 1

	begin
		-- Look for Jobs in T_Analysis_Description with missing Dataset_SIC_Job values or values differing from those in the associated Peptide DB
		--
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Begin RefreshMSMSSICJobs', 'MasterUpdateMassTags'
		EXEC @result = RefreshMSMSSICJobs @jobsUpdated OUTPUT, @message OUTPUT
		set @message = 'Complete ' + @message
	end
	else
		set @message = 'Skipped RefreshMSMSSICJobs'

	If @logLevel > 1 Or (@jobsUpdated > 0 And @logLevel >= 1)
		execute PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'
		

	--------------------------------------------------------------
	-- Skip any LCQ related processing if no new LCQ jobs found, no jobs in state 1 = New, and no Job NETs were updated
	-- However, force the updating if ForceLCQProcessingOnNextUpdate = 1 in T_Process_Step_Control
	--------------------------------------------------------------
	--
	if (@entriesAdded > 0) OR (@jobNETsUpdated + @peptideRowsUpdated) > 0 OR (@jobsUpdated > 0)
		set @ForceGeneralStatisticsUpdate = 1
	else
	begin
		-- See if any jobs are in state 1
		SELECT @result = COUNT(*)
		FROM T_Analysis_Description
		WHERE State = 1
		
		If @result > 0
			set @ForceGeneralStatisticsUpdate = 1
		else
		Begin
			set @result = 0
			SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'ForceLCQProcessingOnNextUpdate')
			if @result = 0
			begin
				-- Skipping is not enabled; jump to DoFTICR
				Set @message = 'No new LCQ jobs were loaded; skipping LCQ related processing'
				If @logLevel >= 2
					execute PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'
				goto DoFTICR
			end

			Set @message = 'No new LCQ jobs were loaded; proceeding with LCQ related processing since ForceLCQProcessingOnNextUpdate = 1'
			If @logLevel >= 2
				execute PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'
		End
	end

	-- Update T_Process_Step_Control to make sure ForceLCQProcessingOnNextUpdate has enabled = 0
	UPDATE T_Process_Step_Control 
	SET enabled = 0
	WHERE (Processing_Step_Name = 'ForceLCQProcessingOnNextUpdate')


		
	-- < D >
	--------------------------------------------------------------
	-- Update Mass Tags
	--------------------------------------------------------------
	--
	-- Update the Mass Tag Table
	--
	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'UpdateMassTags')
	if @result > 0
	begin
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Begin UpdateMassTags', 'MasterUpdateMassTags'
		EXEC @result = UpdateMassTagsFromAvailableAnalyses @numJobsToProcess
		set @message = 'Complete UpdateMassTagsFromAvailableAnalyses: ' + convert(varchar(32), @result)
	end
	else
		set @message = 'Skipped UpdateMassTags'
	--
	If @logLevel >= 1
		execute PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'
	
	-- < E >
	--------------------------------------------------------------
	-- refresh local Protein table
	--------------------------------------------------------------
	--
	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'RefreshProteins')
	if @result > 0
	begin
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Begin RefreshProteins', 'MasterUpdateMassTags'
		exec @result = RefreshLocalProteinTable @message OUTPUT
		set @message = 'Complete ' + @message
	end
	else
		set @message = 'Skipped RefreshProteins'
	--
	If @logLevel >= 1
		execute PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'


	-- < F >
	--------------------------------------------------------------

	-- Update Mass Tag Names
	--------------------------------------------------------------
	--
	declare @count int
	--
	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'UpdateMassTagNames')
	if @result > 0
	begin
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Begin UpdateMassTagNames', 'MasterUpdateMassTags'
		EXEC @result = NamePeptides @count output, @message output
		if @result = 0
			set @message = 'Complete UpdateMassTagNames: ' + convert(varchar(32), @count)
		else
			set @message = 'Complete UpdateMassTagNames: ' + @message + ' (error ' + convert(varchar(32), @result) + ')'
	end
	else
		set @message = 'Skipped UpdateMassTagNames'
	--
	If @logLevel >= 1
		execute PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'


	-- < G >
	--------------------------------------------------------------
	-- Calculate monoisotopic mass for mass tags
	--
	-- This is typically done in the peptide database, but may
	-- be required periodically in the mass tag database
	-- Since not normally used, will not post a 
	-- 'Skipped CalculateMonoisotopicMass' message
	--------------------------------------------------------------
	--
	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'CalculateMonoisotopicMass')
	if @result > 0
	begin
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Begin CalculateMonoisotopicMass', 'MasterUpdateMassTags'
		EXEC @result = CalculateMonoisotopicMass @message output, @count output
		if @result = 0
			set @message = 'Complete CalculateMonoisotopicMass: ' + convert(varchar(32), @count)
		else
			set @message = 'Complete CalculateMonoisotopicMass: ' + convert(varchar(32), @count) + ' (error ' + convert(varchar(32), @result) + ')'
		If @logLevel >= 1 Or @count > 0
			execute PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'
	end
	else
		If @logLevel >= 3
			execute PostLogEntry 'Normal', 'Skipped CalculateMonoisotopicMass', 'MasterUpdateMassTags'


	-- < H >
	--------------------------------------------------------------
	-- Update GANET values for Mass Tags in T_Mass_Tags_NET
	--------------------------------------------------------------
	--	
	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'ComputeMassTagsGANET')
	if @result > 0
	begin
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Begin ComputeMassTagsGANET', 'MasterUpdateMassTags'

		EXEC @result = ComputeMassTagsGANET @message OUTPUT

		if @result = 0
		begin
			set @message = 'Complete ComputeMassTagsGANET: ' + @message
			If @logLevel >= 1
				EXEC PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'
		end
		else
		begin
			set @message = 'Complete ComputeMassTagsGANET: ' + @message + ' (error ' + convert(varchar(32), @result) + ')'
			If @logLevel >= 1
				EXEC PostLogEntry 'Error', @message, 'MasterUpdateMassTags'
		end
	end
	else
		If @logLevel >= 3
			execute PostLogEntry 'Normal', 'Skipped ComputeMassTagsGANET', 'MasterUpdateMassTags'


	-- < I >
	--------------------------------------------------------------
	-- Update the PMT Quality Scores for the mass tags
	--------------------------------------------------------------
	--
	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'ComputePMTQualityScore')
	if @result > 0
	begin
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Begin ComputePMTQualityScore', 'MasterUpdateMassTags'
		EXEC @result = ComputePMTQualityScore @message output
		if @result = 0
			set @message = 'Complete ComputePMTQualityScore: ' + @message
		else
			set @message = 'Complete ComputePMTQualityScore: ' + @message + ' (error ' + convert(varchar(32), @result) + ')'
	end
	else
		set @message = 'Skipped ComputePMTQualityScore'
	--
	If @logLevel >= 1
		execute PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'


	-- < J >
	--------------------------------------------------------------
	-- Run any custom MS/MS processing SPs
	--------------------------------------------------------------
	--
	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'RunCustomSPs')
	if @result > 0
	begin
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Begin RunCustomSPs', 'MasterUpdateMassTags'
		EXEC @result = RunCustomSPs @logLevel, @message output
		if @result = 0
			set @message = 'Complete RunCustomSPs: ' + @message
		else
		begin
			set @message = 'Complete RunCustomSPs: ' + @message + ' (error ' + convert(varchar(32), @result) + ')'
			If @logLevel >= 1
				EXEC PostLogEntry 'Error', @message, 'MasterUpdateMassTags'
		end
	end
	else
		set @message = 'Skipped RunCustomSPs'
	--
	If @logLevel > 1
		execute PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'


	-- < K >
	--------------------------------------------------------------
	-- dump peptides for GANET program
	--------------------------------------------------------------
	--
	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'ExportGANET')
	if @result > 0
	begin
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Begin ExportGANET', 'MasterUpdateMassTags'

		EXEC @result = ExportGANETData @message = @message OUTPUT

		if @result = 0
		begin
			If @logLevel >= 1
				EXEC PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'
		end
		else
		begin
			set @message = 'Complete ExportGANETData: ' + @message + ' (error ' + convert(varchar(32), @result) + ')'
			If @logLevel >= 1
				EXEC PostLogEntry 'Error', @message, 'MasterUpdateMassTags'
		end
	end
	else
	begin
		set @message = 'Skipped ExportGANET'
		If @logLevel > 1
			EXEC PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'
	end


	-- < L >
	--------------------------------------------------------------
	-- Add GANET Update task
	--------------------------------------------------------------
	--
	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'AddGANETUpdateTask')
	if @result > 0
	begin
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Begin AddGANETUpdateTask', 'MasterUpdateMassTags'
		EXEC @result = AddGANETUpdateTask @message output
		if @result = 0
			SET @message = 'Complete AddGANETUpdateTask'
	end
	else
		set @message = 'Skipped AddGANETUpdateTask'
	--
	If @logLevel >= 1
		EXEC PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'


	--------------------------------------------------------------
	-- Mark that we need to compute protein coverage (if enabled)
	--------------------------------------------------------------
	--
	Set @ComputeProteinCoverage = 1
	
	
DoFTICR:
	-- < M >
	--------------------------------------------------------------
	-- import new FTICR analyses
	--------------------------------------------------------------
	--
	set @entriesAdded = 0
	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'ImportFTICRJobs')
	if @result > 0 And @skipImport <> 1
	begin
		-- Import new analyses for peak results from DMS
		--
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Begin ImportNewFTICRAnalyses', 'MasterUpdateMassTags'
		EXEC @result = ImportNewFTICRAnalyses  @entriesAdded OUTPUT, @message OUTPUT
		set @message = 'Complete ' + @message
	end
	else
		set @message = 'Skipped ImportNewFTICRAnalyses'
	--
	If @logLevel > 1 Or (@entriesAdded > 0 And @logLevel >= 1)
		execute PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'
	


	-- < N >
	--------------------------------------------------------------
	-- Check for GANET update task with results ready
	-- We don't actually load the results into the database, but we
	--  need to update the state to Complete
	--------------------------------------------------------------
	declare @taskID int
	set @taskID = 0

	If @logLevel >= 3
		execute PostLogEntry 'Normal', 'Begin GetReadyGANETUpdateTask', 'MasterUpdateMassTags'

	exec @result = GetReadyGANETUpdateTask
						@taskID output,
						@message output

	set @message = 'Complete GetReadyGANETUpdateTask: ' + Convert(varchar(32), @result)
	If @logLevel >= 3
		execute PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'

	if @taskID = 0
	begin
		If @logLevel >= 3
			execute PostLogEntry 'Normal', 'No tasks found in T_GANET_Update_Task with State 3', 'MasterUpdateMassTags'
	end
	else
	begin
		If @logLevel >= 3
			execute PostLogEntry 'Normal', 'Begin SetGANETUpdateTaskComplete', 'MasterUpdateMassTags'

		exec @myError = SetGANETUpdateTaskComplete @taskID, 0, @message output

		If @logLevel >= 3
			execute PostLogEntry 'Normal', 'Complete SetGANETUpdateTaskComplete', 'MasterUpdateMassTags'
	end


	-- < O >
	--------------------------------------------------------------
	-- Update general statistics
	--------------------------------------------------------------
	--
	-- Look up the Last Update date stored in T_General_Statistics
	
	Declare @ValueText varchar(64)
	Declare @ValueDifference int
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
		execute PostLogEntry 'Error', @message, 'MasterUpdateMassTags'
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

	If GetDate() > DateAdd(hour, @UpdateInterval, @LastUpdated) OR @ForceGeneralStatisticsUpdate = 1
	Begin
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Begin UpdateGeneralStatistics', 'MasterUpdateMassTags'
		EXEC @result = UpdateGeneralStatistics
		--
		set @message = 'Complete UpdateGeneralStatistics: ' + convert(varchar(32), @result)
		If @logLevel >= 1
			execute PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'
			
		--------------------------------------------------------------
		-- Compare 'PMTs' and 'Confirmed PMTs' values to their previous values to see if we should compute protein coverage
		--------------------------------------------------------------
		--
		SET @ValueDifference = 0
		SELECT @ValueDifference = Abs(Convert(int, Value) - Convert(int, Previous_Value))
		FROM T_General_Statistics
		WHERE Category = 'Mass Tags' AND Label = 'PMTs' AND 
			  IsNumeric(Value) = 1 AND IsNumeric(Previous_Value) = 1
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myRowCount = 0
			Set @ValueDifference = 1
			

		SELECT @ValueDifference = @ValueDifference + Abs(Convert(int, Value) - Convert(int, Previous_Value))
		FROM T_General_Statistics
		WHERE Category = 'Mass Tags' AND Label = 'Confirmed PMTs' AND 
			  IsNumeric(Value) = 1 AND IsNumeric(Previous_Value) = 1
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myRowCount = 0
			Set @ValueDifference = 1
			
		If IsNull(@ValueDifference, 1) > 0
			Set @ComputeProteinCoverage = 1


		--------------------------------------------------------------
		-- Call CheckStaleTasks to look for tasks stuck in processing
		--------------------------------------------------------------
		--
		Exec @result = CheckStaleTasks
		--
		set @message = 'Complete CheckStaleTasks: ' + convert(varchar(32), @result)
		If @logLevel >= 2
			execute PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'
		
	End
	else
		If @logLevel >= 3
		begin
			set @message = 'Skipping UpdateGeneralStatistics since ' + Convert(varchar(32), @UpdateInterval) + ' hours have not yet elapsed'
			execute PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'
		end


	-- < P >
	-------------------------------------------------------------
	-- Synchronize the analysis description information with DMS
	-------------------------------------------------------------

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
			execute PostLogEntry 'Normal', 'Begin RefreshAnalysisDescriptionInfo', 'MasterUpdateMassTags'
		exec @result = RefreshAnalysisDescriptionInfo @UpdateInterval, @message OUTPUT
		set @message = 'Complete ' + @message
	end
	else
		set @message = 'Skipped RefreshAnalysisDescriptionInfo'
	--
	If @logLevel >= 2
		execute PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'
	

	-- < Q >
	--------------------------------------------------------------
	-- Update the Protein Coverage table (if necessary)
	--------------------------------------------------------------
	--
	If @ComputeProteinCoverage = 1
	Begin
		set @result = 0
		SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'ComputeProteinCoverage')
		if @result > 0
		begin
			-- Lookup residue level Protein coverage computation
			set @result = 0
			SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'ComputeProteinCoverageResidueLevel')
			
			If @logLevel >= 2
				execute PostLogEntry 'Normal', 'Begin ComputeProteinCoverage', 'MasterUpdateMassTags'

			if @result > 0
				Exec @result = ComputeProteinCoverage 1, 0, @message OUTPUT
			Else
				Exec @result = ComputeProteinCoverage 0, 0, @message OUTPUT
			
			if @result = 0
				set @message = 'Complete ComputeProteinCoverage: ' + @message
			else
				set @message = 'Complete ComputeProteinCoverage: ' + @message + ' (error ' + convert(varchar(32), @result) + ')'
				
			Set @ProteinCoverageComputed = 1
		end
		else
			set @message = 'Skipped ComputeProteinCoverage'
		--
		If @logLevel >= 1
			execute PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'
	End


	-- < R >
	--------------------------------------------------------------
	-- Add default peak matching tasks
	--------------------------------------------------------------
	set @entriesAdded = 0
	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'AddDefaultPeakMatchingTasks')
	if @result > 0 And @skipImport <> 1
	begin
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Begin AddDefaultPeakMatchingTasks', 'MasterUpdateMassTags'

		exec @result = AddDefaultPeakMatchingTasks @message OUTPUT, @entriesAdded output
		
		set @message = 'Complete AddDefaultPeakMatchingTasks: ' + convert(varchar(32), @entriesAdded)
		if @result <> 0
		begin
			set @message = @message + ' (error ' + convert(varchar(32), @result) + ')'
			If @logLevel >= 1
				execute PostLogEntry 'Error', @message, 'MasterUpdateMassTags'
		end
		else
			if @logLevel >= 2 Or (@entriesAdded > 0 And @logLevel >= 1)
				execute PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'
	end
	else
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Skipped AddDefaultPeakMatchingTasks', 'MasterUpdateMassTags'

	--------------------------------------------------------------
	-- Exit
	--------------------------------------------------------------

	set @message = 'End Master Update Mass Tags for ' + DB_NAME() + ': ' + convert(varchar(32), @myError)
	If @logLevel >= 2 Or (@myError <> 0 And @logLevel >= 1)
		execute PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'

Done:
	return @myError



GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

