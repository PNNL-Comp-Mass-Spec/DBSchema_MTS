/****** Object:  StoredProcedure [dbo].[UpdatePeptideSICStats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.UpdatePeptideSICStats
/****************************************************
**
**	Desc: 
**		Populates SIC-related fields in T_Peptides for
**		all analyses with Process_State = @ProcessStateMatch
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	10/01/2005
**			10/12/2005 mem - Fixed bug that processed a job even if a valid SIC Job was not present in the DB
**						   - Now posting errors about missing SIC jobs only if the MS/MS job is at least 24 hours old
**			11/09/2005 mem - Added a holdoff time of 24 hours when posting log messages to prevent the same message from appearing twice in a 24 hour period
**			11/10/2005 mem - Added parameter @numJobsAdvanced
**			03/01/2006 mem - Now calling ComputeMaxObsAreaByJob for each job processed
**			03/11/2006 mem - Now calling VerifyUpdateEnabled
**			03/18/2006 mem - No longer calling ComputeMaxObsAreaByJob for each job processed since Seq_ID is required to call that SP
**			10/12/2007 mem - Now calling ReindexDatabase if InitialDBReindexComplete = 0 or UpdatePeptideSICStatsHadDBReindexed = 0 in T_Process_Step_Control
**			10/29/2008 mem - Formatting changes
**			05/21/2009 mem - Reworked the T_Peptides Update Query to use @SICJob and not join in T_Analysis_Description or T_Datasets
**    
*****************************************************/
(
	@ProcessStateMatch int = 20,
	@NextProcessState int = 25,
	@numJobsToProcess int = 50000,
	@numJobsProcessed int=0 OUTPUT,
	@numJobsAdvanced int=0 OUTPUT,
	@UpdateAdditionalJobsWithNullSICStats tinyint = 0			-- Set to 1 to also look for and update jobs with Null SIC stat values in T_Peptides
)
As
	Set NoCount On
	
	Declare @myRowCount int
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

	Declare @jobAvailable int
	Set @jobAvailable = 0

	Declare @result int
	Declare @UpdateEnabled tinyint
	Declare @message varchar(255)
	Set @message = ''
	
	Declare @Job int
	Declare @SICJob int

	Declare @JobCreated datetime
	Declare @LastJobNullSICStats int
	Declare @AdvanceStateForJob tinyint
	
	Declare @count int
	Set @count = 0

	Declare @SICProcessState int
	Declare @SICJobExists tinyint
	
	Declare @RowCountUpdated int
	Declare @RowCountDefined int
	Declare @JobFilterList varchar(128)
	
	Declare @DBReindexComplete int
	Declare @UpdateSICStatsMarkDBReindexed int
	Set @DBReindexComplete = 0
	Set @UpdateSICStatsMarkDBReindexed = 0
	
	Declare @JobStr varchar(18)
	
	----------------------------------------------
	-- Loop through T_Analysis_Description, processing jobs with Process_State = @ProcessStatematch
	-- If @UpdateAdditionalJobsWithNullSICStats = 1 then we'll also look 
	--  for jobs in T_Peptides with Null SIC stat values
	----------------------------------------------
	Set @Job = 0
	Set @LastJobNullSICStats = 0
	Set @jobAvailable = 1
	Set @numJobsProcessed = 0
	Set @numJobsAdvanced = 0
	
	while @jobAvailable > 0 and @myError = 0 and @numJobsProcessed < @numJobsToProcess
	begin -- <a>

		-- Look up the next available job
		Set @jobAvailable = 0

		SELECT TOP 1 @Job = Job,
		             @JobCreated = Created
		FROM T_Analysis_Description
		WHERE Process_State = @ProcessStateMatch AND
		      Job > @Job
		ORDER BY Job
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0 
		begin
			Set @message = 'Error while reading next job from T_Analysis_Description'
			goto done
		end

		If @myRowCount = 1
		Begin
			Set @jobAvailable = 1
			Set @AdvanceStateForJob = 1
		End
		Else
		Begin -- <b1>
			-- No more jobs were found with Process_State = @ProcessStateMatch
			
			if @UpdateAdditionalJobsWithNullSICStats = 1
			Begin -- <c1>
				-- Look for jobs with Null SIC stats values in T_Peptides and a Process State > @NextProcessState
				-- And a SIC_Job defined in T_Datasets
				SELECT TOP 1 @Job = TAD.Job, @JobCreated = TAD.Created
				FROM	T_Analysis_Description TAD INNER JOIN
						T_Peptides Pep ON TAD.Job = Pep.Analysis_ID INNER JOIN
						T_Datasets DS on TAD.Dataset_ID = DS.Dataset_ID
				WHERE	Pep.Scan_Time_Peak_Apex IS NULL AND 
						TAD.Process_State >= @NextProcessState AND 
						NOT DS.SIC_Job Is Null AND
						TAD.Job > @LastJobNullSICStats
				ORDER BY TAD.Job
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				
				If @myRowCount = 1
				Begin
					Set @jobAvailable = 1
					Set @AdvanceStateForJob = 0
					Set @LastJobNullSICStats = @Job
				End
				Else
				Begin -- <d1>
					-- See if any jobs have Null SIC stats values in T_Peptides
					-- If @LastJobNullSICStats is > 0 then limit by @LastJobNullSICStats; otherwise, check all jobs
					-- If any jobs are found, post an entry to the log
					
					If @LastJobNullSICStats > 0 
						SELECT @myRowCount = COUNT(DISTINCT Analysis_ID)
						FROM T_Peptides Pep INNER JOIN
							 T_Analysis_Description TAD on TAD.Job = Pep.Analysis_ID
						WHERE Pep.Scan_Time_Peak_Apex IS NULL AND
							  TAD.Process_State >= @NextProcessState AND
							  TAD.Job <= @LastJobNullSICStats
					Else
						SELECT @myRowCount = COUNT(DISTINCT Analysis_ID)
						FROM T_Peptides Pep INNER JOIN
							 T_Analysis_Description TAD on TAD.Job = Pep.Analysis_ID
						WHERE Pep.Scan_Time_Peak_Apex IS NULL AND
							  TAD.Process_State >= @NextProcessState
					
					If @myRowCount > 0
					Begin
						Set @message = 'Warning, found ' + Convert(varchar(9), @myRowCount) + ' jobs in T_Peptides with undefined SIC stats'
						execute PostLogEntry 'Error', @message, 'UpdatePeptideSICStats'
						Set @message = ''
					End
				End -- </d1>
			End -- </c1>
		End -- </b1>
		
		
		If @jobAvailable = 1
		Begin -- <b2>
			
			Set @JobStr = convert(varchar(18), @job)
			
			If @numJobsProcessed = 0
			Begin
				----------------------------------------------
				-- Prior to processing the first job, check whether 
				--  the database needs to be re-indexed
				----------------------------------------------

				SELECT @DBReindexComplete = enabled 
				FROM T_Process_Step_Control
				WHERE (Processing_Step_Name = 'InitialDBReindexComplete')

				Set @DBReindexComplete = IsNull(@DBReindexComplete, 0)
				
				If @DBReindexComplete <> 0
				Begin
					-- DB already re-indexed once, but what about on the first call to this procedure?
					SELECT @DBReindexComplete = enabled
					FROM T_Process_Step_Control
					WHERE (Processing_Step_Name = 'UpdatePeptideSICStatsHadDBReindexed')
					
					Set @DBReindexComplete = IsNull(@DBReindexComplete, 0)
					If @DBReindexComplete = 0
						Set @UpdateSICStatsMarkDBReindexed = 1
				End
				

				If @DBReindexComplete = 0
				Begin
					Exec @myError = ReindexDatabase @message output
					
					If @UpdateSICStatsMarkDBReindexed <> 0
					Begin
						UPDATE T_Process_Step_Control
						SET Enabled = 1
						WHERE (Processing_Step_Name = 'UpdatePeptideSICStatsHadDBReindexed')
						--
						SELECT @myError = @@error, @myRowCount = @@rowcount
					
						If @myRowCount = 0
						Begin
							Set @message = 'Entry "UpdatePeptideSICStatsHadDBReindexed" not found in T_Process_Step_Control; adding it'
							Exec PostLogEntry 'Error', @message, 'UpdatePeptideSICStats'
							
							INSERT INTO T_Process_Step_Control (Processing_Step_Name, Enabled)
							VALUES ('UpdatePeptideSICStatsHadDBReindexed', 1)
						End
					End
				End
			End

			-- Make sure the Job has a SIC_Job associated with it
			Set @SICJobExists = 0
			Set @SICProcessState = 0
			Set @SICJob = 0
			
			SELECT @SICProcessState = TAD_SIC.Process_State,
			       @SICJob = DS.SIC_Job
			FROM T_Analysis_Description TAD
			     INNER JOIN T_Datasets DS
			       ON TAD.Dataset_ID = DS.Dataset_ID
			     INNER JOIN T_Analysis_Description TAD_SIC
			       ON DS.SIC_Job = TAD_SIC.Job
			WHERE TAD.Job = @Job
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			If @myRowCount = 0
			Begin
				Set @message = 'Update SIC stats in T_Peptides failed for job ' + @JobStr + '; a corresponding SIC job could not be found'
				-- Only post an entry to the log if Job was created in this DB more than 24 hours ago
				-- Additionally, only post one entry every 24 hours
				If DateDiff(hour, @JobCreated, GetDate()) >= 24
					execute PostLogEntry 'Error', @message, 'UpdatePeptideSICStats', 24
				Set @message = ''
			End
			Else
			Begin
				If IsNull(@SICProcessState, 0) = 75
					Set @SICJobExists = 1
				Else
				Begin
					Set @message = 'Update SIC stats in T_Peptides failed for job ' + @JobStr
					Set @message = @message + '; although a SIC job exists its state is not 75'
					Set @message = @message + '; SIC Job' + Convert(varchar(18), @SICJob) + ', State ' + Convert(varchar(12), @SICProcessState)
					
					-- Only post an entry to the log if Job was created in this DB more than 24 hours ago
					-- Additionally, only post one entry every 24 hours
					If DateDiff(hour, @JobCreated, GetDate()) >= 24
						execute PostLogEntry 'Error', @message, 'UpdatePeptideSICStats', 24
					Set @message = ''
				End
			End

			If @SICJobExists = 1
			Begin -- <c2>
				-- Update the SIC Stats
				UPDATE T_Peptides
				SET Scan_Time_Peak_Apex = DS_Scans.Scan_Time,
				    Peak_Area = DS_SIC.Peak_Area,
				    Peak_SN_Ratio = DS_SIC.Peak_SN_Ratio
				FROM T_Peptides Pep
				     INNER JOIN T_Dataset_Stats_SIC DS_SIC
				       ON DS_SIC.Job = @SICJob AND
				          Pep.Scan_Number = DS_SIC.Frag_Scan_Number
				     INNER JOIN T_Dataset_Stats_Scans DS_Scans
				       ON DS_SIC.Optimal_Peak_Apex_Scan_Number = DS_Scans.Scan_Number AND
				          DS_SIC.Job = DS_Scans.Job
				WHERE Pep.Analysis_ID = @Job
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				--
				Set @RowCountUpdated = @myRowCount
				
				-- Make sure the number of rows updated matches the number of rows defined for this job
				SELECT @RowCountDefined = COUNT(*)
				FROM T_Peptides
				WHERE Analysis_ID = @Job
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				
				-- Make a log entry if the number of updated rows doesn't match @RowCountDefined
				If @RowCountUpdated < @RowCountDefined
				Begin
					Set @message = 'Update SIC stats in T_Peptides failed for job ' + @JobStr + '; only ' + Convert(varchar(11), @RowCountUpdated) + ' rows were updated while ' + Convert(varchar(11), @RowCountDefined) + ' rows exist'
					execute PostLogEntry 'Error', @message, 'UpdatePeptideSICStats'
					Set @message = ''
				End
				Else
				Begin
					If @RowCountUpdated = 0
					Begin
						-- Make a log entry if @RowCountUpdated = 0
						Set @message = 'Update SIC stats in T_Peptides failed for job ' + @JobStr + '; 0 rows were updated'
						execute PostLogEntry 'Error', @message, 'UpdatePeptideSICStats'
						Set @message = ''
						Set @AdvanceStateForJob = 0
					End
				End
				
				-----------------------------------------------------------
				-- Update state of analysis job provided @AdvanceStateForJob = 1
				-- @AdvanceStateForJob will be 0 if this job was selected because
				--  @UpdateAdditionalJobsWithNullSICStats = 1
				-- @AdvanceStateForJob will also be 0 if no rows were updated
				-----------------------------------------------------------
				--
				If @AdvanceStateForJob = 1
				Begin
					Exec SetProcessState @job, @NextProcessState
					Set @numJobsAdvanced = @numJobsAdvanced + 1
				End
			end  -- </c2>

			-- check number of jobs processed
			--
			Set @numJobsProcessed = @numJobsProcessed + 1
			
		end -- </b2>

		-- Validate that updating is enabled, abort if not enabled
		exec VerifyUpdateEnabled @CallingFunctionDescription = 'UpdatePeptideSICStats', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
		If @UpdateEnabled = 0
			Goto Done

	end -- </a>

	if @numJobsProcessed = 0
		set @message = 'no analyses were available'

Done:
	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[UpdatePeptideSICStats] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[UpdatePeptideSICStats] TO [MTS_DB_Lite] AS [dbo]
GO
