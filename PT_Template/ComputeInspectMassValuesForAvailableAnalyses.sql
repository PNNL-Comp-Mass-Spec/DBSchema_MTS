/****** Object:  StoredProcedure [dbo].[ComputeInspectMassValuesForAvailableAnalyses] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE Procedure ComputeInspectMassValuesForAvailableAnalyses
/****************************************************
**
**	Desc: 
**		Calls ComputeInspectMassValuesUsingSICStat for jobs in T_Analysis_Description
**      matching state @ProcessState
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	10/29/2008
**    
*****************************************************/
(
	@ProcessStateMatch int = 37,
	@NextProcessState int = 40,
	@numJobsToProcess int = 50000,
	@numJobsProcessed int=0 OUTPUT
)
AS
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Declare @Job int
	Declare @ResultType varchar(32)

	declare @jobAvailable int
	set @jobAvailable = 0

	declare @FirstInspectJobFound tinyint
	set @FirstInspectJobFound = 0

	declare @IsInspectJob tinyint
	
	declare @UpdateEnabled tinyint
	declare @message varchar(255)
	set @message = ''
	
	declare @count int
	set @count = 0

	----------------------------------------------
	-- Loop through T_Analysis_Description, processing jobs with Process_State = @ProcessStatematch
	----------------------------------------------
	Set @Job = 0
	set @jobAvailable = 1
	set @numJobsProcessed = 0
	
	While @jobAvailable > 0 and @myError = 0 and @numJobsProcessed < @numJobsToProcess
	Begin -- <a>
		-- Look up the next available job
		SELECT	TOP 1 @Job = Job,
					  @ResultType = ResultType
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

		If @myRowCount <> 1
			Set @jobAvailable = 0
		Else
		Begin -- <b>
			-- Job is available to process

			Set @IsInspectJob = 0
			If @ResultType = 'IN_Peptide_Hit'
			Begin
				Set @IsInspectJob = 1
				
				if @FirstInspectJobFound = 0
				begin
					-- Write entry to T_Log_Entries for the first job processed
					set @message = 'Starting Inspect mass value computation for job ' + convert(varchar(11), @job)
					execute PostLogEntry 'Normal', @message, 'ComputeInspectMassValuesForAvailableAnalyses'
					set @message = ''
					set @FirstInspectJobFound = 1
				end

				-- Note that if an error occurs, then ComputeInspectMassValuesUsingSICStats will post a message to T_Log_Entries
				Exec @myError = ComputeInspectMassValuesUsingSICStats @Job, @message = @message output
				Set @message = ''
			End
			Else
			Begin
				-- Job is not an inspect job; simply advance the state to @NextProcessState
				Set @myError = 0
			End
			
			-- Advance the state if no error; leave unchanged if an error
			If @myError = 0
			Begin
				Exec SetProcessState @job, @NextProcessState				
				set @numJobsProcessed = @numJobsProcessed + 1
			End
			
		End -- </b>

		-- Validate that updating is enabled, abort if not enabled
		-- For speed purposes, only need to do this if we actually called ComputeInspectMassValuesUsingSICStats
		If @IsInspectJob <> 0
		Begin
			exec VerifyUpdateEnabled @CallingFunctionDescription = 'ComputeInspectMassValuesForAvailableAnalyses', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
			If @UpdateEnabled = 0
				Goto Done
		End
		
	End -- </a>

	If @numJobsProcessed = 0
		set @message = 'no analyses were available'

Done:
	return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[ComputeInspectMassValuesForAvailableAnalyses] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[ComputeInspectMassValuesForAvailableAnalyses] TO [MTS_DB_Lite] AS [dbo]
GO
