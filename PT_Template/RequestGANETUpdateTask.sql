/****** Object:  StoredProcedure [dbo].[RequestGANETUpdateTask] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.RequestGANETUpdateTask
/****************************************************
**
**	Desc: 
**		Looks for jobs in T_Analysis_Description with a
**      Process_State = @ProcessStateMatch (default 40)
**
**      If found, create NET Update task and populate with
**		batch of available jobs; set @TaskAvailable to 1
**		and return the relevant information in the output arguments
**
**      If no jobs are available or an error occurs, then @message 
**		will contain explanatory text.
**
**	Auth:	grk
**	Date:	08/26/2003
**			04/08/2004 mem - Removed references to T_GANET_Update_Parameters
**			04/09/2004 mem - Removed @maxIterations and @maxHours parameters
**			07/05/2004 mem - Modified procedure for use in Peptide DB
**			09/09/2004 mem - Removed call to SetProcessState
**			09/23/2004 mem - Now checking for tasks in states 44, 45, 47, or 48 with Last_Affected over 12 hours old; bumping back to Process_State 40 if found
**			01/22/2005 mem - Now setting Process_State = 43 if a job is in state 40 and does not have associated scan time data
**			01/24/2005 mem - Now checking for jobs in state 43 that now have a SIC job available; if found, the state is reset back to 40 and a message is posted to the log
**			04/08/2005 mem - Changed GANET export call to use ExportGANETData
**			05/30/2005 mem - Updated to process batches of jobs using T_NET_Update_Task rather than one job at a time
**						   - Added parameters @ResultsFolderPath and @BatchSize
**			12/11/2005 mem - Updated to support XTandem results
**			07/03/2006 mem - Updated to use T_Analysis_Description.RowCount_Loaded to quickly determine the number of peptides loaded for each job
**			10/10/2008 mem - Added support for Inspect results (type IN_Peptide_Hit)
**			03/13/2010 mem - Reordered the parameters and added several new parameters (@obsNETsFile, @unmodifiedPeptidesOnly, @noCleavageRuleFilters, and @RegressionOrder)
**			03/19/2010 mem - Added parameter @ParamFileName
**			04/21/2010 mem - Now examining field Regression_Param_File when looking for available jobs
**			08/22/2011 mem - Added support for MSGFDB results (type MSG_Peptide_Hit)
**			07/20/2012 mem - Now calling UpdateNETRegressionParamFileName for jobs in state 44
**			12/04/2012 mem - Added support for MSAlign results (type MSA_Peptide_Hit)
**			12/05/2012 mem - Now using tblPeptideHitResultTypes to determine the valid Peptide_Hit result types
**			03/25/2013 mem - Now creating #Tmp_NET_Update_Jobs
**
*****************************************************/
(
	@processorName varchar(128),
	@TaskID int output,								-- The job to process; if processing several jobs at once, then the first job number in the batch
	@taskAvailable tinyint output,

	@SourceFolderPath varchar(256) = '',			-- Path to folder containing source data; if blank, then will look up path in MT_Main (e.g. I:\GA_Net_Xfer\Out\PT_Shewanella_ProdTest_A123\)
	@SourceFileName varchar(256) = '' output,		-- Source file name

	@ResultsFolderPath varchar(256) = '',			-- Path to folder containing the results; if blank, then will look up path in MT_Main (e.g. I:\GA_Net_Xfer\In\PT_Shewanella_ProdTest_A123\)
	@ResultsFileName varchar(256) = '' output,		-- Results file name
	@PredNETsFileName varchar(256) = '' output,		-- Predict NETs results file name
	@ObsNETsFileName varchar(256) = '' output,		-- Observed NETs results file name

	@ParamFileName varchar(256) = '' output,		-- If this is defined, then settings in the parameter file will superseded the following 5 parameters
	
	@unmodifiedPeptidesOnly tinyint = 0 output,		-- 1 if we should only consider unmodified peptides
	@noCleavageRuleFilters tinyint = 0 output,		-- 1 if we should use the looser filters that do not consider cleavage rules
	@RegressionOrder tinyint = 3 output,			-- 1 for linear regression, >=2 for non-linear regression
	
	@message varchar(512) output,
	@ProcessStateMatch int = 40,
	@NextProcessState int = 45,
	@GANETProcessingTimeoutState int = 44,
	@BatchSize int = 0,								-- If non-zero, then this value overrides the one present in T_Process_Config, entry NET_Update_Batch_Size
	@MaxPeptideCount int = 0						-- If non-zero, then this value overrides the one present in T_Process_Config, entry NET_Update_Max_Peptide_Count
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	declare @MatchCount int
	declare @ParamFileMatch varchar(256)
	
	set @message = ''		
	
	---------------------------------------------------
	-- Create temporary table required by SetGANETUpdateTaskState
	-- (this procedure does not utilize this temp table)
	---------------------------------------------------

	CREATE TABLE #Tmp_NET_Update_Jobs (
		Job int not null,
		RegressionInfoLoaded tinyint not null,
		ObservedNETsLoaded tinyint not null
	)
	
	---------------------------------------------------
	-- clear the output arguments
	---------------------------------------------------
	set @TaskID = 0
	set @TaskAvailable = 0

	set @message = ''

	set @SourceFolderPath = ''
	set @SourceFileName = ''
	
	set @ResultsFolderPath = ''
	set @ResultsFileName = ''
	set @PredNETsFileName = ''	
	set @ObsNETsFileName = ''
	
	Set @ParamFileName = ''
	
	set @UnmodifiedPeptidesOnly = 0		-- 1 if we should only consider unmodified peptides and peptides with alkylated cysteine
	set @NoCleavageRuleFilters = 0		-- 1 if we should use the looser filters that do not consider cleavage rules
	Set @RegressionOrder = 3			-- 1 for first order, 3 for non-linear

	set @taskAvailable = 0
	
	---------------------------------------------------
	-- Look for jobs that are timed out (State 44)
	-- See if their parameter file name contains one of the label names defined in T_Process_Config
	-- This is typically used to fix jobs where the dataset is an iTRAQ dataset and the parameter file
	--  name contains _iTRAQ_ but the experiment Labelling field is set to None instead if iTRAQ
	---------------------------------------------------
	exec UpdateNETRegressionParamFileName @GANETProcessingTimeoutState, @GANETProcessingTimeoutState, @infoonly=0, @MatchLabellingToParamFileName=1
	
	
	---------------------------------------------------
	-- Look for jobs that are timed out (State 44) and for which Last_Affected
	-- is more than 60 minutes ago; reset to state @ProcessStateMatch
	---------------------------------------------------
	--
	UPDATE T_Analysis_Description
	SET Process_State = @ProcessStateMatch
	WHERE Process_State = @GANETProcessingTimeoutState AND
		  DateDiff(Minute, Last_Affected, GetDate()) > 60
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	If @myRowCount > 0
	Begin
		Set @message = 'Jobs that were timed out (state ' + Convert(varchar(11), @GANETProcessingTimeoutState) + ') were reset to state ' + Convert(varchar(11), @ProcessStateMatch) + '; ' + Convert(varchar(11), @myRowCount) + ' updated'
		Exec PostLogEntry 'Error', @message, 'RequestGANETUpdateTask'
	End


	---------------------------------------------------
	-- Check for and reset stale NET update tasks
	---------------------------------------------------
	--
	Declare @CurrentTime datetime
	Declare @maxHoursUnchangedState int
	Set @maxHoursUnchangedState = 12

	Exec ResetStaleNETUpdateTasks @maxHoursUnchangedState, @ProcessStateMatch
	
	---------------------------------------------------
	-- Look for any jobs in state @ProcessStateMatch that
	-- do not have associated scan time information;
	-- If found, update their state to 43
	---------------------------------------------------
	--
	UPDATE T_Analysis_Description
	SET Process_State = 43, Last_Affected = GetDate()
	WHERE Job IN
        (	SELECT TAD.Job
			FROM T_Dataset_Stats_Scans DSS INNER JOIN
				 V_SIC_Job_to_PeptideHit_Map JobMap ON DSS.Job = JobMap.SIC_Job
					RIGHT OUTER JOIN T_Analysis_Description TAD ON 
				 JobMap.Job = TAD.Job
			WHERE (TAD.Process_State = @ProcessStateMatch)
			GROUP BY TAD.Job
			HAVING COUNT(DSS.Job) = 0
		)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		Set @message = 'Error looking for jobs that are missing scan stats info'
		Exec PostLogEntry 'Error', @message, 'RequestGANETUpdateTask'
		goto done
	end

	if @myRowCount > 0
	begin
		Set @message = 'Jobs were found that did not have associated ScanTime entries in T_Dataset_Stats_Scans; their states have been set to 43 (Updated ' + Convert(varchar(9), @myRowCount) + ' jobs)'
		Exec PostLogEntry 'Error', @message, 'RequestGANETUpdateTask'
	end


	---------------------------------------------------
	-- Look for any jobs in state 43 that
	-- now do have associated scan time information;
	-- If found, reset their state to @ProcessStateMatch
	---------------------------------------------------
	--
	UPDATE T_Analysis_Description
	SET Process_State = @ProcessStateMatch, Last_Affected = GetDate()
	WHERE Job IN
		(	SELECT TAD.Job
			FROM T_Dataset_Stats_Scans DSS INNER JOIN
				V_SIC_Job_to_PeptideHit_Map JobMap ON DSS.Job = JobMap.SIC_Job
					INNER JOIN T_Analysis_Description TAD ON 
				JobMap.Job = TAD.Job
			WHERE (TAD.Process_State = 43)
			GROUP BY TAD.Job
			HAVING COUNT(DSS.Job) > 0
		)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myRowCount > 0
	begin
		Set @message = 'Jobs that were in state 43 were reset to state ' + Convert(varchar(11), @ProcessStateMatch) + ' since a SIC job now exists; ' + Convert(varchar(11), @myRowCount) + ' updated'
		Exec PostLogEntry 'Normal', @message, 'RequestGANETUpdateTask'
	end
	
	
	---------------------------------------------------
	-- Lookup the value for @BatchSize
	---------------------------------------------------
	
	If IsNull(@BatchSize, 0) <= 0
	Begin
		Set @BatchSize = 0
		SELECT TOP 1 @BatchSize = Value
		FROM T_Process_Config
		WHERE [Name] = 'NET_Update_Batch_Size'
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		-- Default to a batch size of 100 if an error occurs
		If @MyRowCount = 0 Or @myError <> 0
			Set @Batchsize = 100
		Else
			If IsNull(@BatchSize, 0) <= 0
				Set @BatchSize = 100
	End
	
	---------------------------------------------------
	-- Lookup the value for @MaxPeptideCount
	---------------------------------------------------
	
	If IsNull(@MaxPeptideCount, 0) <= 0
	Begin
		Set @MaxPeptideCount = 0
		SELECT TOP 1 @MaxPeptideCount = Value
		FROM T_Process_Config
		WHERE [Name] = 'NET_Update_Max_Peptide_Count'
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		-- Default to a max peptide count of 200000 if an error occurs
		If @MyRowCount = 0 Or @myError <> 0
			Set @MaxPeptideCount = 200000
		Else
			If IsNull(@MaxPeptideCount, 0) <= 0
				Set @MaxPeptideCount = 200000
	End
	
	If @BatchSize < 1
		Set @BatchSize = 1
	If @MaxPeptideCount < 1
		Set @MaxPeptideCount = 1

	
	---------------------------------------------------
	-- Start transaction
	---------------------------------------------------
	--
	declare @transName varchar(32)
	set @transName = 'RequestGANETUpateTask'
	begin transaction @transName

	---------------------------------------------------
	-- See if one or more jobs are in state @ProcessStateMatch
	---------------------------------------------------

	SELECT @MatchCount = Count(TAD.Job)
	FROM T_Analysis_Description TAD INNER JOIN
		 dbo.tblPeptideHitResultTypes() RTL ON TAD.ResultType = RTL.ResultType
	WHERE TAD.Process_State = @ProcessStateMatch
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		rollback transaction @transName
		set @message = 'Error trying to count number of available jobs'
		goto done
	end

	---------------------------------------------------
	-- bail if no jobs were found
	---------------------------------------------------

	if @MatchCount = 0
	begin
		rollback transaction @transName
		set @message = 'Could not find viable record'
		goto done
	end

	---------------------------------------------------
	-- Create a new NET Update task
	---------------------------------------------------
	
	INSERT INTO T_NET_Update_Task (Processing_State, Task_Created, Task_AssignedProcessorName)
	VALUES (1, GetDate(), @processorName)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount, @TaskID = Scope_Identity()
	--
	if @myError <> 0
	begin
		rollback transaction @transName
		set @message = 'Error adding new task to T_NET_Update_Task'
		goto done
	end
	
	
	---------------------------------------------------
	-- Find up to @BatchSize jobs in state @ProcessStateMatch
	-- Limit the number of entries to @MaxPeptideCount peptides (though, require a minimum of one job)
	-- Only grab the Job numbers at this time
	--
	-- If any of the available jobs has a NET regression param file defined in T_Analysis_Description
	--  then we preferentially choose those jobs (being sure to only choose jobs with the same param file name)
	---------------------------------------------------

	Set @ParamFileMatch = ''
	
	-- See if any of the available jobs have a customized Regression Parameter File defined
	--			
	SELECT TOP 1 @ParamFileMatch = Regression_Param_File
	FROM T_Analysis_Description TAD
	     INNER JOIN dbo.tblPeptideHitResultTypes() RTL
	       ON TAD.ResultType = RTL.ResultType
	WHERE TAD.Process_State = @ProcessStateMatch AND
	      IsNull(TAD.Regression_Param_File, '') <> ''
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	-- Now find jobs that are in state @ProcessStateMatch and use @ParamFileMatch (which could be blank)
	--
	INSERT INTO T_NET_Update_Task_Job_Map ( Task_ID, Job )
	SELECT @TaskID AS Task_ID, A.Job
	FROM ( SELECT TOP ( @BatchSize ) TAD.Job,
	                                 IsNull(TAD.RowCount_Loaded, 0) AS PeptideCount
	       FROM T_Analysis_Description TAD WITH ( HoldLock )
	            INNER JOIN dbo.tblPeptideHitResultTypes() RTL
	              ON TAD.ResultType = RTL.ResultType
	       WHERE TAD.Process_State = @ProcessStateMatch AND
	             IsNull(TAD.Regression_Param_File, '') = @ParamFileMatch
	       ORDER BY TAD.Job 
	     ) A
	     INNER JOIN
	     ( SELECT TOP ( @BatchSize ) TAD.Job,
	                                 IsNull(TAD.RowCount_Loaded, 0) AS PeptideCount
	       FROM T_Analysis_Description TAD WITH ( HoldLock )
	            INNER JOIN dbo.tblPeptideHitResultTypes() RTL
	              ON TAD.ResultType = RTL.ResultType
	       WHERE TAD.Process_State = @ProcessStateMatch AND
	             IsNull(TAD.Regression_Param_File, '') = @ParamFileMatch
	       ORDER BY TAD.Job 
	     ) B ON B.Job <= A.Job
	GROUP BY A.Job
	HAVING SUM(B.PeptideCount) < @MaxPeptideCount
	ORDER BY A.Job ASC
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		rollback transaction @transName
		set @message = 'Error trying to find viable record(s)'
		goto done
	end		


	If @myRowCount = 0
	Begin
		-- The @MaxPeptideCount filter filtered out all of the jobs
		-- Repeat the insert but only grab the first available job
		
		INSERT INTO T_NET_Update_Task_Job_Map ( Task_ID, Job )
		SELECT TOP 1 @TaskID AS Task_ID, Job
		FROM T_Analysis_Description TAD WITH ( HoldLock )
		     INNER JOIN dbo.tblPeptideHitResultTypes() RTL
		       ON TAD.ResultType = RTL.ResultType
		WHERE TAD.Process_State = @ProcessStateMatch
		ORDER BY Job ASC
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0
		begin
			rollback transaction @transName
			set @message = 'Error trying to find viable record(s)'
			goto done
		end

		if @myRowCount = 0
		begin
			rollback transaction @transName
			set @message = 'There are no longer any jobs with state ' + Convert(varchar(12), @ProcessStateMatch) + '; unable to continue'
			goto done
		end
		
		-- Update ParamFileMatch if this job has a Regression parameter file defined
		--
		SELECT @ParamFileMatch = IsNull(TAD.Regression_Param_File, '')
		FROM T_NET_Update_Task_Job_Map TJM
		     INNER JOIN T_Analysis_Description TAD
		       ON TJM.Job = TAD.Job
		WHERE Task_ID = @TaskID
		
	End
	
	---------------------------------------------------
	-- set state and last_affected for the selected jobs
	---------------------------------------------------
	--
	UPDATE T_Analysis_Description
	SET Process_State = @NextProcessState, Last_Affected = GETDATE()
	FROM T_Analysis_Description TAD INNER JOIN 
		 T_NET_Update_Task_Job_Map TJM ON TAD.Job = TJM.Job
	WHERE TJM.Task_ID = @TaskID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		rollback transaction @transName
		set @message = 'Update operation failed'
		goto done
	end

	---------------------------------------------------
	-- commit transaction
	---------------------------------------------------
	commit transaction @transName


	---------------------------------------------------
	-- Set the default values for these parameters
	-- If a parameter file is defined via @ParamFileMatch or 
	--  is defined in in T_Process_Config, then these defaults will get superseded
	---------------------------------------------------
	--
	set @unmodifiedPeptidesOnly = 0		-- 1 if we should only consider unmodified peptides and peptides with alkylated cysteine
	set @noCleavageRuleFilters = 0		-- 1 if we should use the looser filters that do not consider cleavage rules
	Set @RegressionOrder = 3			-- 1 for first order, 3 for non-linear

	If IsNull(@ParamFileMatch, '') = ''
	Begin
		Set @ParamFileName = ''
		SELECT @ParamFileName = Value
		FROM T_Process_Config 
		WHERE [Name] = 'NET_Regression_Param_File_Name'
	End
	Else
		Set @ParamFileName = @ParamFileMatch

	---------------------------------------------------
	-- Write the output files
	---------------------------------------------------

	Exec @myError = ExportGANETData @TaskID,
									@SourceFolderPath = @SourceFolderPath, 
									@ResultsFolderPath = @ResultsFolderPath,
									@SourceFileName = @SourceFileName output, 
									@ResultsFileName = @ResultsFileName output, 
									@PredNETsFileName = @PredNETsFileName output, 
									@ObsNETsFileName = @ObsNETsFileName output,
									@message = @message output
	--
	if @myError = 0
	begin
		-- Advance Task_ID to state 2 = 'Update In Progress'
		Exec SetGANETUpdateTaskState @TaskID, 2, Null, @message output
	end
	else
	begin
		If Len(IsNull(@message, '')) = 0
			Set @message = 'Error calling ExportGANETData for TaskID ' + Convert(varchar(9), @TaskID)
		
		-- Error calling ExportGANETData
		-- Post an error log entry
		Exec PostLogEntry 'Error', @message, 'RequestGANETUpdateTask'

		-- Now update Task_ID to State 6 and rollback state of jobs to @GANETProcessingTimeoutState
		Exec SetGANETUpdateTaskState @TaskID, 6, @GANETProcessingTimeoutState, @message output
		goto done
	end
	
	---------------------------------------------------
	-- If we get to this point, then all went fine
	-- Update TaskAvailable
	---------------------------------------------------
	Set @TaskAvailable = 1

	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[RequestGANETUpdateTask] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[RequestGANETUpdateTask] TO [MTS_DB_Lite] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[RequestGANETUpdateTask] TO [pnl\MTSProc] AS [dbo]
GO
