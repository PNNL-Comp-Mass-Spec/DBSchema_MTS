/****** Object:  StoredProcedure [dbo].[CalculateConfidenceScores] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.CalculateConfidenceScores
/****************************************************
**
**	Desc:	Updates confidence scores for all the peptides
**			for the all the analyses with Process_State = @ProcessStateMatch
**
**	Return values: 0 if no error; otherwise error code
**
**	Parameters:
**
**	Auth:	grk
**	Date:	07/30/2004
**			08/06/2004 mem - Log entry updates
**			09/09/2004 mem - Switched from using a temporary table to polling T_Analysis_Description directly for the next available job
**			01/28/2005 mem - Added SkipConfidenceScoreRecalculation option
**			03/11/2006 mem - Now calling VerifyUpdateEnabled
**			07/05/2006 mem - Added parameter @NextProcessStateSkipPeptideProphet
**			10/10/2008 mem - Added support for Inspect results (type IN_Peptide_Hit)
**			03/19/2010 mem - Now calling CheckPeptideProphetUpdateRequired for each job in state @ProcessStateMatch
**    
*****************************************************/
(
	@ProcessStateMatch int = 50,
	@NextProcessState int = 90,
	@NextProcessStateSkipPeptideProphet int = 60,
	@numJobsToProcess int = 50000,
	@numJobsProcessed int=0 OUTPUT
)
AS
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	set @numJobsProcessed = 0
	
	declare @Continue int
	set @Continue = 0

	declare @result int
	declare @UpdateEnabled tinyint
	declare @message varchar(255)
	set @message = ''
	
	Declare @Job int
	Declare @JobAdvancedToNextState tinyint
	Declare @JobCountSkipped int
	
	Declare @message2 varchar(256)

	declare @count int
	set @count = 0

	------------------------------------------------------------------
	-- See if confidence score recalculation skipping is enabled
	------------------------------------------------------------------
	--
	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'SkipConfidenceScoreRecalculation')
	If @result > 0 And Exists (SELECT * FROM T_Analysis_Description WHERE Process_State = @ProcessStateMatch)
	Begin -- <a1>
	
		-- Look for any Jobs that already have all of their confidence scores calculated
		-- If found, then call CheckPeptideProphetUpdateRequired for each job
		--   If peptide prophet processing is required, set the state to @NextProcessState
		--   Otherwise, set it to @NextProcessStateSkipPeptideProphet

		CREATE TABLE #Tmp_JobsToPossiblySkip (
			Job int NOT NULL
		)

		INSERT INTO #Tmp_JobsToPossiblySkip (Job)
		SELECT TAD.Job
		FROM T_Analysis_Description TAD
		WHERE TAD.Process_State = @ProcessStateMatch AND 
			  (TAD.Job NOT IN
				  (	SELECT TAD.Job
					FROM T_Peptides P INNER JOIN
						 T_Score_Discriminant SD ON P.Peptide_ID = SD.Peptide_ID INNER JOIN
						 T_Analysis_Description TAD ON P.Analysis_ID = TAD.Job
					WHERE SD.DiscriminantScore IS NULL AND 
						  TAD.Process_State = @ProcessStateMatch
					GROUP BY TAD.Job
					HAVING COUNT(SD.Peptide_ID) > 0
				  )
			  )
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	
		Set @JobCountSkipped = 0
	
		If @myRowCount > 0
		Begin -- <b1>
			-- Process each job in #Tmp_JobsToPossiblySkip
			
			Set @Job = -1
			set @Continue = 1
			Set @numJobsProcessed = 0

			While @Continue > 0 and @numJobsProcessed < @numJobsToProcess
			Begin -- <c>
			
				SELECT TOP 1 @Job = Job
				FROM #Tmp_JobsToPossiblySkip
				WHERE Job > @Job
				ORDER BY Job
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount

				if @myError <> 0 
				begin
					set @message = 'Error while reading next job from #Tmp_JobsToPossiblySkip'
					goto done
				end

				if @myRowCount = 0
					Set @Continue = 0
				else
				Begin -- <d>
					-- Job is available to process
					
					-- Advance the job state as appropriate
					Set @JobAdvancedToNextState = 0
					Exec @myError = CheckPeptideProphetUpdateRequired 0, @NextProcessStateSkipPeptideProphet, @message2 OUTPUT, @JobFilter = @Job, @JobAdvancedToNextState = @JobAdvancedToNextState OUTPUT
					
					if @myError <> 0 
					begin
						set @message = 'Error calling CheckPeptideProphetUpdateRequired for job ' + Convert(varchar(12), @Job)
						If Len(IsNull(@message2, '')) > 0
							Set @message = @message + '; ' + @message2

						goto done
					end
					
					If @JobAdvancedToNextState <> 0
						Set @JobCountSkipped = @JobCountSkipped + 1

					-- Increment number of jobs processed
					Set @numJobsProcessed = @numJobsProcessed + 1


				End -- </d>
				
			End -- </c>
			
		End -- </b1>
			  
		If @myError = 0 AND @JobCountSkipped > 0
		Begin
			Set @message = 'Discriminant score computation skipped for jobs where existing scores were already present; updated ' + convert(varchar(9), @JobCountSkipped) + ' jobs'
			execute PostLogEntry 'Warning', @message, 'CalculateConfidenceScores'			
			Set @message = ''
		End
    End -- </a1>


	----------------------------------------------
	-- Loop through T_Analysis_Description, processing jobs with Process_State = @ProcessStatematch
	----------------------------------------------
	Set @Job = -1
	set @Continue = 1
	Set @numJobsProcessed = 0
	
	while @Continue > 0 and @myError = 0 and @numJobsProcessed < @numJobsToProcess
	begin -- <a2>
		-- Look up the next available job
		SELECT	TOP 1 @Job = Job
		FROM	T_Analysis_Description
		WHERE	Process_State = @ProcessStateMatch AND Job > @Job
		ORDER BY Job
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0 
		begin
			set @message = 'Error while reading next job from T_Analysis_Description'
			goto done
		end

		if @myRowCount = 0
			Set @Continue = 0
		else
		begin -- <b2>
			-- Job is available to process
			Exec @result = CalculateConfidenceScoresOneAnalysis @Job, @NextProcessState, @NextProcessStateSkipPeptideProphet, @message OUTPUT
		
			-- make log entry
			--
			if @result = 0
				execute PostLogEntry 'Normal', @message, 'CalculateConfidenceScores'
			else
				execute PostLogEntry 'Error', @message, 'CalculateConfidenceScores'
			
			-- Increment number of jobs processed
			set @numJobsProcessed = @numJobsProcessed + 1
			
		end -- </b2>

		-- Validate that updating is enabled, abort if not enabled
		exec VerifyUpdateEnabled @CallingFunctionDescription = 'CalculateConfidenceScores', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
		If @UpdateEnabled = 0
			Goto Done

	end -- </a2>

	if @numJobsProcessed = 0
		set @message = 'no analyses were available'

	-----------------------------------------------
	-- exit the stored procedure
	-----------------------------------------------
	-- 
Done:

	-- Post a log entry if an error exists
	if @myError <> 0
		execute PostLogEntry 'Error', @message, 'CalculateConfidenceScores'

	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[CalculateConfidenceScores] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[CalculateConfidenceScores] TO [MTS_DB_Lite] AS [dbo]
GO
