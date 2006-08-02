SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[CalculateConfidenceScoresBulk]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[CalculateConfidenceScoresBulk]
GO


CREATE PROCEDURE dbo.CalculateConfidenceScoresBulk
/****************************************************
**
**	Desc: 
**		Updates confidence scores for
**		all the peptides for the all the analyses with
**		Process_State = @ProcessStateMatch
**
**		-- Unused Procedure --
**		This was an attempt to speed up CalculateConfidenceScores 
**		and CalculateConfidenceScoresOneAnalysis, but it runs much slower
**
**	Return values: 0 if no error; otherwise error code
**
**	Parameters:
**
**		Auth: grk
**		Date: 07/30/2004
**			  08/06/2004 mem - Log entry updates
**			  09/06/2004 mem - Now processing multiple jobs simultaneously, but with a maximum number of peptides to process per bulk operation
**			  09/11/2004 mem - Switched to using T_Peptide_to_Protein_Map
**			  10/01/2005 mem - Updated to use Cleavage_State_Max in T_Sequence rather than polling T_Peptide_to_Protein_Map
**    
*****************************************************/
	@ProcessStateMatch int = 50,
	@NextProcessState int = 60,
	@numJobsToProcess int = 50000,
	@numJobsProcessed int=0 OUTPUT
AS
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	declare @JobAvailableCount int
	declare @AddnlJobAvailableCount int

	declare @PeptidesInBatch int
	declare @JobsInBatch int

	declare @result int
	declare @message varchar(255)
	set @message = ''
	
	declare @Job int
	declare @PeptideCountForJob int
	declare @LastJobPolled int
	declare @intContinue int	

	declare @MaxPeptidesPerBatch int
	Set @MaxPeptidesPerBatch = 250000

	declare	@ORFCount int
	declare @ResidueCount int

	Set @ORFCount = 0
	Set @ResidueCount = 0

	set @numJobsProcessed = 0

	-----------------------------------------------------------
	-- Create the temporary tables to hold the jobs to process
	-----------------------------------------------------------
	CREATE TABLE #JobsToProcess (
		Job int,
		PeptideCount int
	)

	CREATE TABLE #JobsInBatch (
			Job int,
			PeptideCount int,
			ResidueCount int
	)

	-- Get list of analyses that need to be processed
	INSERT INTO #JobsToProcess
	SELECT	AD.Job, IsNull(COUNT(P.Peptide_ID), 0) AS PeptideCount
	FROM T_Analysis_Description AS AD LEFT OUTER JOIN T_Peptides AS P ON 
		 AD.Job = P.Analysis_ID
	WHERE	AD.Process_State = @ProcessStateMatch
	GROUP BY AD.Job
	ORDER BY AD.Job
	--
	SELECT @myError = @@error, @JobAvailableCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Error populating #JobsToProcess with the jobs to process'
		set @myError = 51103
		goto Done
	end

	set @numJobsProcessed = 0
	
	-- loop through the available jobs, and process them in groups
	--
	while @JobAvailableCount > 0 and @myError = 0 And @numJobsProcessed < @numJobsToProcess
	begin -- <a>
		-- Populate #JobsInBatch with jobs from #JobsToProcess,
		-- limiting the list to at most @MaxPeptidesPerBatch peptides
		Set @Job = 0

		SELECT TOP 1 @job = Job, @PeptideCountForJob = PeptideCount
		FROM #JobsToProcess
		ORDER BY Job
		--
		SELECT @myError = @@error, @JobAvailableCount = @@rowcount
		--
		if @myError <> 0
		begin
			set @message = 'Could not get next entry from #JobsToProcess'
			set @myError = 51104
			goto Done
		end

		if @JobAvailableCount > 0
		begin -- <b>
			-- Delete this job from #JobsToProcess
			DELETE FROM #JobsToProcess WHERE Job = @Job
		
			-- Reset #JobsInBatch
			DELETE FROM #JobsInBatch
				
			-- Lookup the size of the Organism DB file (aka the FASTA file) for this job
			--
			Set @ResidueCount = 0
			Exec @result = GetOrganismDBFileStats @Job, @ORFCount OUTPUT, @ResidueCount OUTPUT

			If IsNull(@ResidueCount, 0) < 1
				Set @ResidueCount = 1
			
			INSERT INTO #JobsInBatch (Job, PeptideCount, ResidueCount)
			VALUES (@job, @PeptideCountForJob, @ResidueCount)

			Set @PeptidesInBatch = @PeptideCountForJob
			Set @JobsInBatch = 1
			Set @AddnlJobAvailableCount = 1
			
			-- Add additional jobs to #JobsInBatch
			while @PeptidesInBatch < @MaxPeptidesPerBatch AND @AddnlJobAvailableCount > 0 AND @numJobsProcessed + @JobsInBatch < @numJobsToProcess
			begin -- <c>
				SELECT TOP 1 @job = Job, @PeptideCountForJob = PeptideCount
				FROM #JobsToProcess
				ORDER BY Job
				--
				SELECT @myError = @@error, @AddnlJobAvailableCount = @@rowcount
			
				If @AddnlJobAvailableCount = 1
				Begin
					If @PeptidesInBatch + @PeptideCountForJob < @MaxPeptidesPerBatch
					Begin
						-- Delete this job from #JobsToProcess
						DELETE FROM #JobsToProcess WHERE Job = @Job

						-- Lookup the size of the Organism DB file (aka the FASTA file) for this job
						--
						Set @ResidueCount = 0
						Exec @result = GetOrganismDBFileStats @Job, @ORFCount OUTPUT, @ResidueCount OUTPUT

						If IsNull(@ResidueCount, 0) < 1
							Set @ResidueCount = 1
					
						INSERT INTO #JobsInBatch (Job, PeptideCount, ResidueCount)
						VALUES (@job, @PeptideCountForJob, @ResidueCount)

						Set @PeptidesInBatch = @PeptidesInBatch + @PeptideCountForJob
						Set @JobsInBatch = @JobsInBatch + 1
					
					End					
					Else
						Set @AddnlJobAvailableCount = 0
				End
			end -- </c>
		
			----------------------------------------
			-- Process the jobs in #JobsInBatch
			----------------------------------------
	
			UPDATE T_Score_Discriminant
			SET DiscriminantScore = dbo.calcDiscriminantScore (
							S.Xcorr, 
							S.DeltaCn2, 
							S.DelM, 
							IsNull(P.GANET_Obs, 0),
							CASE WHEN IsNull(P.GANET_Obs, -10000) > -10000
							THEN T_Sequence.GANET_Predicted
							ELSE 0
							END,
							S.RankSp, 
							S.RankXc, 
							S.XcRatio, 
							P.Charge_State, 
							Len(T_Sequence.Clean_Sequence),
							T_Sequence.Cleavage_State_Max, 
							0,									-- Number of missed cleavages
							PassFilt, 
							MScore)
			FROM T_Score_Discriminant INNER JOIN T_Peptides AS P ON T_Score_Discriminant.Peptide_ID = P.Peptide_ID
				 INNER JOIN T_Score_Sequest	AS S ON T_Score_Discriminant.Peptide_ID = S.Peptide_ID 
				 INNER JOIN T_Sequence ON P.Seq_ID = T_Sequence.Seq_ID
		 		 INNER JOIN #JobsInBatch ON P.Analysis_ID = #JobsInBatch.Job
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--
			if @myError <> 0 
			begin
				set @message = 'Error while computing T_Score_discriminant.DiscriminantScore'
				goto done
			end

			------------------------------------------------------------------
			-- Compute the DiscriminantScoreNorm value for all the peptides for jobs in #JobsInBatch
			------------------------------------------------------------------
			--
			UPDATE T_Score_Discriminant
			SET DiscriminantScoreNorm = dbo.calcDiscriminantScoreNorm(DiscriminantScore, Charge_state, #JobsInBatch.ResidueCount)
			FROM T_Score_Discriminant INNER JOIN T_Peptides AS P ON T_Score_Discriminant.Peptide_ID = P.Peptide_ID
				 INNER JOIN #JobsInBatch ON P.Analysis_ID = #JobsInBatch.Job
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--
			if @myError <> 0 
			begin
				set @message = 'Error while computing T_Score_Discriminant.DiscriminantScoreNorm'
				goto done
			end

			-- Update the Process_State value
			UPDATE T_Analysis_Description 
			SET Process_State = @NextProcessState, Last_Affected = GETDATE()
			FROM T_Analysis_Description INNER JOIN #JobsInBatch ON
				 T_Analysis_Description.Job = #JobsInBatch.Job
			--
			SELECT @myError = @@error, @myRowCount = @@RowCount


			-- Post entries to T_Log_Entries for all jobs processed in this batch
			--			
			Set @intContinue = 1
			Set @LastJobPolled = 0
			
			While @intContinue = 1
			Begin -- <d>
				SELECT	TOP 1
						@LastJobPolled = Job,
						@PeptideCountForJob = PeptideCount
				FROM #JobsInBatch
				WHERE Job > @LastJobPolled
				--
				SELECT @myError = @@error, @intContinue = @@RowCount
				
				If @intContinue = 1
				Begin
					set @message = 'Discriminant scores computed for job ' + convert(varchar(11), @LastJobPolled) + '; processed ' + convert(varchar(11), @PeptideCountForJob) + ' peptides'
					
					-- make log entry
					--
					execute PostLogEntry 'Normal', @message, 'CalculateConfidenceScores'
				End
			End -- </d>
		

			-- Increment jobs processed count
			Set @numJobsProcessed = @numJobsProcessed + @JobsInBatch

		end -- </b>
	end -- </a>

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
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

