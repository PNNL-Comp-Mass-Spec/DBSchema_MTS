/****** Object:  StoredProcedure [dbo].[ComputeMaxObsAreaForAvailableAnalyses] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.ComputeMaxObsAreaForAvailableAnalyses
/****************************************************
**
**	Desc: 
**		Calls ComputeMaxObsAreaByJob for each job
**		with Process_State = @ProcessStateMatch
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	03/18/2006
**    
*****************************************************/
(
	@ProcessStateMatch int = 33,
	@NextProcessState int = 40,
	@numJobsToProcess int = 50000,
	@PostLogEntryOnSuccess tinyint = 0,
	@numJobsProcessed int=0 OUTPUT
)
AS
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	declare @jobAvailable int
	set @jobAvailable = 0

	declare @result int
	declare @UpdateEnabled tinyint
	declare @message varchar(255)
	set @message = ''
	
	declare @Job int
	declare @JobFilterList varchar(32)
	declare @JobsUpdated int
	declare @NextProcessStateToUse int

	----------------------------------------------
	-- Loop through T_Analysis_Description, processing jobs with Process_State = @ProcessStatematch
	----------------------------------------------
	Set @Job = 0
	set @jobAvailable = 1
	set @numJobsProcessed = 0
	
	while @jobAvailable > 0 and @myError = 0 and @numJobsProcessed < @numJobsToProcess
	begin -- <a>
		-- Look up the next available job
		SELECT	TOP 1 @Job = Job
		FROM	T_Analysis_Description
		WHERE	Process_State = @ProcessStateMatch AND Job > @Job
		ORDER BY Job
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		if @myError <> 0 
		begin
			set @message = 'Error while reading next job from T_Analysis_Description'
			goto done
		end

		if @myRowCount <> 1
			Set @jobAvailable = 0
		else
		begin -- <b>
			-- Job is available to process
			
			-- See if the job is present in T_Joined_Job_Details
			-- If it is, will set @NextProcessState to 39
			If Exists (SELECT * FROM T_Joined_Job_Details WHERE Source_Job = @Job)
				Set @NextProcessStateToUse = 39
			Else
				Set @NextProcessStateToUse = @NextProcessState

			-- Call ComputeMaxObsAreaByJob for @Job
			Set @JobFilterList = Convert(varchar(19), @Job)
			
			Set @JobsUpdated = 0
			exec ComputeMaxObsAreaByJob @JobsUpdated = @JobsUpdated output, @message = @message output, @JobFilterList = @JobFilterList
				
			If @JobsUpdated > 0
				Exec SetProcessState @job, @NextProcessState
			
			-- Increment number of jobs processed
			set @numJobsProcessed = @numJobsProcessed + 1
		end -- </b>

		-- Validate that updating is enabled, abort if not enabled
		exec VerifyUpdateEnabled @CallingFunctionDescription = 'ComputeMaxObsAreaForAvailableAnalyses', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
		If @UpdateEnabled = 0
			Goto Done

	end -- </a>

	if @numJobsProcessed = 0
		set @message = 'no analyses were available'

Done:
	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[ComputeMaxObsAreaForAvailableAnalyses] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[ComputeMaxObsAreaForAvailableAnalyses] TO [MTS_DB_Lite]
GO
