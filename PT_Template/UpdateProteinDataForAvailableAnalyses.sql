/****** Object:  StoredProcedure [dbo].[UpdateProteinDataForAvailableAnalyses] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.UpdateProteinDataForAvailableAnalyses
/****************************************************
**
**	Desc: 
**		Calls UpdateProteinData for jobs in T_Analysis_Description
**      matching state @ProcessState
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	11/02/2009
**    
*****************************************************/
(
	@ProcessStateMatch int = 15,
	@NextProcessState int = 20,
	@numJobsToProcess int = 50000,
	@numJobsProcessed int=0 OUTPUT
)
AS
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Declare @JobList varchar(max)
	Declare @count int
	Declare @Job int
	Declare @Continue int
	Declare @MatchCount int
	Set @MatchCount = 0
	
	Declare @message varchar(512)
	
	----------------------------------------------
	-- Construct a list of the jobs in T_Analysis_Description that have a Process_State of @ProcessStateMatch
	----------------------------------------------

	If Exists (SELECT * FROM T_Analysis_Description WHERE Process_State = @ProcessStateMatch)
	Begin -- <a>
	
		---------------------------------------------------
		-- Create and populate a temporary to hold the jobs to process
		---------------------------------------------------
		--
		CREATE TABLE #T_Tmp_JobsToProcess_PDA (
			Job int NOT NULL
		)

		CREATE CLUSTERED INDEX #IX_Tmp_JobsToProcess_PDA ON #T_Tmp_JobsToProcess_PDA (Job)

		INSERT INTO #T_Tmp_JobsToProcess_PDA (Job)
		SELECT TOP ( @numJobsToProcess ) Job
		FROM T_Analysis_Description
		WHERE Process_State = @ProcessStateMatch
		ORDER BY Job
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error


		---------------------------------------------------
		-- Fill @JobList with the jobs to process
		---------------------------------------------------
		--
		Set @JobList = ''
		SELECT @JobList = @JobList + ', ' + Convert(varchar(20), Job)
		FROM #T_Tmp_JobsToProcess_PDA
		ORDER BY Job
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		Set @Count = @myRowCount

		If @Count > 0
		Begin -- <b>
			-- Remove the leading comma from @JobList
			Set @JobList = Substring(@JobList, 3, Len(@JobList))

			---------------------------------------------------
			-- Update the proteins for the jobs in @JobList
			---------------------------------------------------			
			--
			EXEC @myError = UpdateProteinData @JobListFilter=@JobList, @SkipUpdateExistingProteins=1
			
			If @myError <> 0
				Set @message = 'Error calling UpdateProteinData: ' + Convert(varchar(12), @myError)
			Else		
			Begin -- </c>
			
				---------------------------------------------------
				-- Make sure each of the jobs in @JobList has all of its proteins defined in T_Proteins
				-- Post an error if it doesn't
				---------------------------------------------------

				Set @Job = 0				
				SELECT @Job = MIN(Job)-1
				FROM #T_Tmp_JobsToProcess_PDA
				
				Set @continue = 1
				While @Continue = 1
				Begin -- <d>
				
					SELECT TOP 1 @Job = Job
    				FROM #T_Tmp_JobsToProcess_PDA
    				WHERE Job > @Job
    				ORDER BY Job
					--
					SELECT @myError = @@error, @myRowCount = @@rowcount
				
					If @myRowCount = 0
						Set @continue = 0
					Else
					Begin -- <e>
						
						Set @MatchCount = 0
						
						SELECT @MatchCount = COUNT(*)
						FROM T_Peptides Pep
						     INNER JOIN T_Peptide_to_Protein_Map PPM
						       ON Pep.Peptide_ID = PPM.Peptide_ID
						     INNER JOIN T_Proteins Prot
						       ON PPM.Ref_ID = Prot.Ref_ID
						WHERE Pep.Analysis_ID = @Job AND
						      Prot.Protein_Collection_ID IS NULL AND
						      NOT (Prot.Reference LIKE 'reversed[_]%' OR
						           Prot.Reference LIKE 'scrambled[_]%' OR
						           Prot.Reference LIKE '%[:]reversed')

						If @MatchCount > 0
						Begin
							Set @message = 'Job ' + Convert(varchar(12), @Job) + ' has ' + Convert(varchar(12), @MatchCount) + ' protein'
							If @MatchCount = 1
								Set @message = @message + ' that does not have '
							Else
								Set @message = @message + 's that do not have '
							
							Set @message = @message + 'a valid protein collection defined; this likely indicates a problem'
							
							execute PostLogEntry 'Error', @message, 'UpdateProteinDataForAvailableAnalyses'
							Set @message = ''
						End

					End -- </e>
					
				End -- </d>

				---------------------------------------------------
				-- Advance the state of the processed jobs to @NextProcessState
				-- We advance the state of the jobs regardless of whether or not 
				--  the protein update succeeded
				---------------------------------------------------
				
				UPDATE T_Analysis_Description
				SET Process_State = @NextProcessState
				FROM T_Analysis_Description TAD
				     INNER JOIN #T_Tmp_JobsToProcess_PDA JobQ
				       ON TAD.Job = JobQ.Job
				--
				SELECT @myRowCount = @@rowcount, @myError = @@error
				
				Set @numJobsProcessed = @myRowCount
					
			End -- </c>
		End -- </b>
	End -- </a>

	
	If @numJobsProcessed = 0
		set @message = 'no analyses were available'

Done:
	return @myError


GO
