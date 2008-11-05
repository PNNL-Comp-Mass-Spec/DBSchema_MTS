/****** Object:  StoredProcedure [dbo].[MasterUpdateMassTags] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.MasterUpdateMassTags
/****************************************************
** 
**	Desc:	Performs all the steps necessary to 
**			bring the status of the mass tag table
**			to be current with the state of DMS
**
**			Also schedules GANET update task
**
**	Return values: 0: success, otherwise, error code
** 
**	Auth:	grk
**	Date:	11/20/2003
**			11/26/2003 grk - modified to add peak matching tasks from FTICR import count
**			04/08/2003 mem - Added ForceLCQProcessingOnNextUpdate option
**						   - Added call to ComputePMTQualityScore
**						   - Enabled optional call to CalculateMonoisotopicMass
**						   - Removed call to AddDefaultPeakMatchingTasks (now in MasterUpdateNET)
**						   - Changed instances of AddGANETUpateTask to AddGANETUpdateTask
**			04/09/2004 mem - Added support for LogLevel
**						   - Limiting call to UpdateGeneralStatistics to be every @GeneralStatsUpdateInterval hours
**			06/12/2004 mem - Added call to SynchronizeCoverageTable
**			09/29/2004 mem - Updated to new MTDB schema and added @numJobsToProcess and @skipImport parameters
**			10/15/2004 mem - Added call to RefreshMSMSJobNETs
**			10/17/2004 mem - Now updating general statistics if any new MS/MS jobs are loaded
**			10/18/2004 mem - Re-enabled optional call to CalculateMonoisotopicMass
**			03/14/2005 mem - Added optional call to RunCustomSPs
**			04/08/2005 mem - Changed GANET export call to use ExportGANETData
**			04/10/2005 mem - Now calling CheckStaleTasks to look for tasks stuck in processing
**			07/08/2005 mem - Added call to RefreshAnalysisDescriptionInfo
**						   - Now looking up General_Statistics_Update_Interval and Job_Info_DMS_Update_Interval in T_Process_Config
**			08/13/2005 mem - Fixed logic bug involving determining whether general statistics should be updated
**			10/12/2005 mem - Added call to RefreshMSMSSICJobs (which will cascade into RefreshMSMSSICStats for any updated jobs)
**						   - When performing LCQ Processing, now assuring Enabled = 0 for 'ForceLCQProcessingOnNextUpdate' in T_Process_Step_Control
**			11/27/2005 mem - Now checking the return value of ExportGANETData and storing the message as an error if non-zero
**			12/15/2005 mem - Renamed ImportNewLCQAnalyses to ImportNewMSMSAnalyses; renamed ImportNewFTICRAnalyses to ImportNewMSAnalyses
**						   - Replaced instances of LCQ with MSMS and FTICR with MS, including updating references to T_Process_Step_Control
**			01/18/2006 mem - No longer posting the message returned by ComputeMassTagsGANET to the log since ComputeMassTagsGANET is now doing that itself
**			01/23/2006 mem - No longer posting the message returned by ComputePMTQualityScore to the log since ComputePMTQualityScore is now doing that itself
**			02/23/2006 mem - No longer posting the message returned by ImportNewMSMSAnalyses or ImportNewMSAnalyses to the log since those SPs are now doing that themselves
**			03/04/2006 mem - Now calling UpdateGeneralStatisticsIfRequired to possibly update the general statistics
**			03/11/2006 mem - Now calling VerifyUpdateEnabled
**			08/29/2006 mem - Updated call to AddDefaultPeakMatchingTasks to use @SetStateToHolding = 0
**			09/15/2006 mem - Added call to UpdateMassTagPeptideProphetStats
**			10/06/2006 mem - No longer posting the message returned by ComputeProteinCoverage to the log since ComputeProteinCoverage is now doing that itself
**			12/14/2006 mem - Now sending @PostLogEntryOnSuccess=0 to RefreshMSMSJobNETs
**			03/11/2008 mem - Added call to ExtractMTModPositions
**			03/27/2008 mem - Added call to UpdateMassTagToProteinModMap
**			04/07/2008 mem - Now sending @ComputePMTQualityScoreLocal to ComputePMTQualityScore
**			04/23/2008 mem - Minor changes to the status messages posted to T_Log_Entries
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
	declare @UpdateEnabled tinyint
	
	set @result = 0
	set @logLevel = 1		-- Default to normal logging

	declare @ForceGeneralStatisticsUpdate tinyint
	declare @ComputeProteinCoverage tinyint
	declare @ProteinCoverageComputed tinyint
	declare @ComputePMTQualityScoreLocal tinyint
	
	set @ForceGeneralStatisticsUpdate = 0
	set @ComputeProteinCoverage = 0
	set @ProteinCoverageComputed = 0
	set @ComputePMTQualityScoreLocal = 0

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateMassTags', @AllowPausing = 0, @UpdateEnabled = @UpdateEnabled output, @message = @message output
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

	set @message = 'Begin Master Update Mass Tags for ' + DB_NAME()
	If @logLevel >= 2
		execute PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'


	-- < A >
	--------------------------------------------------------------
	-- import new MS/MS analyses
	--------------------------------------------------------------
	--
	declare @entriesAdded int
	set @entriesAdded = 0
	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'ImportMSMSJobs')
	if @result > 0 And @skipImport <> 1
	begin
		-- Import new analyses for peptide identification from peptide database
		--
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Begin ImportNewMSMSAnalyses', 'MasterUpdateMassTags'
		EXEC @result = ImportNewMSMSAnalyses @entriesAdded OUTPUT, @message OUTPUT
		set @message = 'Complete ImportNewMSMSAnalyses: ' + @message
	end
	else
		set @message = 'Skipped ImportMSMSJobs'
	--
	-- Note: ImportNewMSMSAnalyses will post an entry to the log if @entriesAdded is greater than 0
	If @entriesAdded = 0 And @logLevel >= 2
		execute PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateMassTags', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done


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
		EXEC @result = RefreshMSMSJobNETs @jobNETsUpdated OUTPUT, @peptideRowsUpdated OUTPUT, @message OUTPUT, @PostLogEntryOnSuccess=0
		set @message = 'Complete RefreshMSMSJobNETs: ' + @message
	end
	else
		set @message = 'Skipped RefreshMSMSJobNETs'

	If @logLevel >= 2 Or ((@jobNETsUpdated + @peptideRowsUpdated) > 0 And @logLevel >= 1)
		execute PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateMassTags', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done


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
		set @message = 'Complete RefreshMSMSSICJobs: ' + @message
	end
	else
		set @message = 'Skipped RefreshMSMSSICJobs'

	If @logLevel >= 2 Or (@jobsUpdated > 0 And @logLevel >= 1)
		execute PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateMassTags', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done


	--------------------------------------------------------------
	-- Skip any MS/MS related processing if no new MS/MS jobs found, no jobs in state 1 = New, and no Job NETs were updated
	-- However, force the updating if ForceMSMSProcessingOnNextUpdate = 1 in T_Process_Step_Control
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
			SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'ForceMSMSProcessingOnNextUpdate')
			if @result = 0
			begin
				-- Skipping is not enabled; jump to DoMSJobs
				Set @message = 'No new MS/MS jobs were loaded; skipping MS/MS related processing'
				If @logLevel >= 2
					execute PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'
				goto DoMSJobs
			end

			Set @message = 'No new MS/MS jobs were loaded; proceeding with MS/MS related processing since ForceMSMSProcessingOnNextUpdate = 1'
			If @logLevel >= 2
				execute PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'
		End
	end

	-- Update T_Process_Step_Control to make sure ForceMSMSProcessingOnNextUpdate has enabled = 0
	UPDATE T_Process_Step_Control 
	SET enabled = 0
	WHERE (Processing_Step_Name = 'ForceMSMSProcessingOnNextUpdate')


		
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

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateMassTags', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done
	
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
		set @message = 'Complete RefreshLocalProteinTable: ' + @message
	end
	else
		set @message = 'Skipped RefreshProteins'
	--
	If @logLevel >= 1
		execute PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateMassTags', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done


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

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateMassTags', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done


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

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateMassTags', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done


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
			-- Note that ComputeMassTagsGANET calls PostLogEntry with @message
			set @message = 'Complete ComputeMassTagsGANET'
			If @logLevel >= 2
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

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateMassTags', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done

	-- < I >
	--------------------------------------------------------------
	-- Update the PMT Quality Scores for the mass tags
	--------------------------------------------------------------
	--
	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'ComputePMTQualityScore')
	if @result > 0
	begin
		Set @ComputePMTQualityScoreLocal = 0
		SELECT @ComputePMTQualityScoreLocal = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'ComputePMTQualityScoreLocal')
		
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Begin ComputePMTQualityScore', 'MasterUpdateMassTags'
		
		EXEC @result = ComputePMTQualityScore @message output, @ComputePMTQualityScoreLocal = @ComputePMTQualityScoreLocal
		
		if @result = 0
		Begin
			-- Note that ComputePMTQualityScore calls PostLogEntry with @message if successful
			set @message = 'Complete ComputePMTQualityScore'
			If @logLevel >= 2
				EXEC PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'
		End
		else
		Begin
			set @message = 'Complete ComputePMTQualityScore: ' + @message + ' (error ' + convert(varchar(32), @result) + ')'
			If @logLevel >= 1
				EXEC PostLogEntry 'Error', @message, 'MasterUpdateMassTags'
		End
	end
	else
		If @logLevel >= 3
			execute PostLogEntry 'Normal', 'Skipped ComputePMTQualityScore', 'MasterUpdateMassTags'

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateMassTags', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done


	-- < J1 >
	--------------------------------------------------------------
	-- Update the Peptide Prophet Stats cached in T_Mass_Tag_Peptide_Prophet_Stats
	--------------------------------------------------------------
	--
	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'UpdateMassTagPeptideProphetStats')
	if @result > 0
	begin
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Begin UpdateMassTagPeptideProphetStats', 'MasterUpdateMassTags'
		
		EXEC @result = UpdateMassTagPeptideProphetStats @message = @message output
		
		if @result = 0
		Begin
			-- Note that UpdateMassTagPeptideProphetStats calls PostLogEntry with @message if successful
			set @message = 'Complete UpdateMassTagPeptideProphetStats'
			If @logLevel >= 2
				EXEC PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'
		End
		else
		Begin
			set @message = 'Complete UpdateMassTagPeptideProphetStats: ' + @message + ' (error ' + convert(varchar(32), @result) + ')'
			If @logLevel >= 1
				EXEC PostLogEntry 'Error', @message, 'MasterUpdateMassTags'
		End
	end
	else
		If @logLevel >= 3
			execute PostLogEntry 'Normal', 'Skipped UpdateMassTagPeptideProphetStats', 'MasterUpdateMassTags'

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateMassTags', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done


	-- < J2 >
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
	If @logLevel >= 2
		execute PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateMassTags', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done


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
		If @logLevel >= 2
			EXEC PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'
	end

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateMassTags', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done


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

	-- < M >
	--------------------------------------------------------------
	-- Refresh the Auto_Update histograms if necessary
	--------------------------------------------------------------
	--
	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'AutoComputeHistograms')

	if @result > 0
	begin
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Begin UpdateCachedHistograms', 'MasterUpdateMassTags'
		
		EXEC @result = UpdateCachedHistograms @UpdateIfRequired = 1, @UpdateCount = @count output, @message = @message output
		
		if @result = 0
		Begin
			set @message = 'Complete UpdateCachedHistograms: ' + @message
			If @logLevel >= 2 Or (@count > 0 And @logLevel >= 1)
				EXEC PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'
		End
		else
		Begin
			set @message = 'Complete UpdateCachedHistograms: ' + @message + ' (error ' + convert(varchar(32), @result) + ')'
			If @logLevel >= 1
				EXEC PostLogEntry 'Error', @message, 'MasterUpdateMassTags'
		End
	end
	else
	Begin
		set @message = 'Skipped UpdateCachedHistograms'
		If @logLevel >= 2
			EXEC PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'
	End


	-- < N1 >
	--------------------------------------------------------------
	-- Populate T_Mass_Tag_Mod_Info
	--------------------------------------------------------------
	--
	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'ExtractMTModInfo')

	if @result > 0
	begin
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Begin ExtractMTModPositions', 'MasterUpdateMassTags'
		
		EXEC @result = ExtractMTModPositions @message = @message output
		
		if @result = 0
		Begin
			set @message = 'Complete ExtractMTModPositions: ' + @message
			If @logLevel >= 2
				EXEC PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'
		End
		else
		Begin
			set @message = 'Complete ExtractMTModPositions: ' + @message + ' (error ' + convert(varchar(32), @result) + ')'
			If @logLevel >= 1
				EXEC PostLogEntry 'Error', @message, 'MasterUpdateMassTags'
		End
	end
	else
	Begin
		set @message = 'Skipped ExtractMTModPositions'
		If @logLevel >= 2
			EXEC PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'
	End


	-- < N2 >
	--------------------------------------------------------------
	-- Populate T_Protein_Residue_Mods and T_Mass_Tag_to_Protein_Mod_Map
	--------------------------------------------------------------
	--
	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'PopulateMTtoProteinModMap')

	if @result > 0
	begin
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Begin UpdateMassTagToProteinModMap', 'MasterUpdateMassTags'
		
		EXEC @result = UpdateMassTagToProteinModMap @message = @message output
		
		if @result = 0
		Begin
			set @message = 'Complete UpdateMassTagToProteinModMap: ' + @message
			If @logLevel >= 2
				EXEC PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'
		End
		else
		Begin
			set @message = 'Complete UpdateMassTagToProteinModMap: ' + @message + ' (error ' + convert(varchar(32), @result) + ')'
			If @logLevel >= 1
				EXEC PostLogEntry 'Error', @message, 'MasterUpdateMassTags'
		End
	end
	else
	Begin
		set @message = 'Skipped UpdateMassTagToProteinModMap'
		If @logLevel >= 2
			EXEC PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'
	End
	
	

	--------------------------------------------------------------
	-- Mark that we need to compute protein coverage (if enabled)
	--------------------------------------------------------------
	--
	Set @ComputeProteinCoverage = 1

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateMassTags', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done
	
	
DoMSJobs:
	-- < O >
	--------------------------------------------------------------
	-- import new LC-MS analyses
	--------------------------------------------------------------
	--
	set @entriesAdded = 0
	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'ImportMSJobs')
	if @result > 0 And @skipImport <> 1
	begin
		-- Import new analyses for peak results from DMS
		--
		If @logLevel >= 2
			execute PostLogEntry 'Normal', 'Begin ImportNewMSAnalyses', 'MasterUpdateMassTags'
		EXEC @result = ImportNewMSAnalyses  @entriesAdded OUTPUT, @message OUTPUT
		set @message = 'Complete ImportNewMSAnalyses: ' + @message
	end
	else
		set @message = 'Skipped ImportNewMSAnalyses'
	--
	-- Note: ImportNewMSAnalyses will post an entry to the log if @entriesAdded is greater than 0
	If @entriesAdded = 0 And @logLevel >= 2
		execute PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateMassTags', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done


	-- < P >
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

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateMassTags', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done


	-- < Q >
	--------------------------------------------------------------
	-- Possibly update the general statistics
	--------------------------------------------------------------
	--
	Declare @ValueDifference int
	Declare @ValueText varchar(64)
	Declare @UpdateInterval int				-- Interval is in hours

	Declare @StatsUpdated tinyint
	Declare @HoursSinceLastUpdate int
	Set @StatsUpdated = 0
	Set @HoursSinceLastUpdate = 0
	
	Exec @myError = UpdateGeneralStatisticsIfRequired @GeneralStatsUpdateInterval, @ForceGeneralStatisticsUpdate, @LogLevel, @StatsUpdated = @StatsUpdated Output, @HoursSinceLastUpdate = @HoursSinceLastUpdate Output

	If @StatsUpdated <> 0 OR @ForceGeneralStatisticsUpdate = 1
	Begin
			
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

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateMassTags', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done


	-- < R >
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
		set @message = 'Complete RefreshAnalysisDescriptionInfo: ' + @message
	end
	else
		set @message = 'Skipped RefreshAnalysisDescriptionInfo'
	--
	If @logLevel >= 2
		execute PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateMassTags', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done


	-- < S >
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
			
			if @logLevel >= 2
				execute PostLogEntry 'Normal', 'Begin ComputeProteinCoverage', 'MasterUpdateMassTags'

			if @result > 0
				Exec @result = ComputeProteinCoverage 1, 0, @message OUTPUT
			else
				Exec @result = ComputeProteinCoverage 0, 0, @message OUTPUT


			if @result <> 0
			begin
				set @message = 'Complete ComputeProteinCoverage: ' + @message + ' (error ' + convert(varchar(32), @result) + ')'
				If @logLevel >= 1
					execute PostLogEntry 'Error', @message, 'MasterUpdateMassTags'
			end
			else
			begin
				set @message = 'Complete ComputeProteinCoverage: ' + @message
				if @logLevel >= 2
					execute PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'
			end

			Set @ProteinCoverageComputed = 1
		end
		else
		begin
			set @message = 'Skipped ComputeProteinCoverage'
			If @logLevel >= 1
				execute PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'
		end

	End

	-- Validate that updating is enabled, abort if not enabled
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'MasterUpdateMassTags', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
		Goto Done


	-- < T >
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

		exec @result = AddDefaultPeakMatchingTasks @message OUTPUT, @entriesAdded output, @SetStateToHolding = 0
		
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
	-- Normal Exit
	--------------------------------------------------------------

	set @message = 'End Master Update Mass Tags for ' + DB_NAME() + ': ' + convert(varchar(32), @myError)

Done:
	If (@logLevel >=1 AND @myError <> 0)
		execute PostLogEntry 'Error', @message, 'MasterUpdateMassTags'
	Else
	If @logLevel >= 2
		execute PostLogEntry 'Normal', @message, 'MasterUpdateMassTags'

	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[MasterUpdateMassTags] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[MasterUpdateMassTags] TO [MTS_DB_Lite]
GO
