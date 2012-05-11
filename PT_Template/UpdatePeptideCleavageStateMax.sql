/****** Object:  StoredProcedure [dbo].[UpdatePeptideCleavageStateMax] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE UpdatePeptideCleavageStateMax
/****************************************************
**
**	Desc:	Updates column Cleavage_State_Max in T_Peptides 
**			for the specified Jobs
**
**	Auth:	mem
**	Date:	09/22/2009 mem - Initial version (modelled after UpdatePeptideStateID)
**			09/23/2009 mem - Added parameter @PostLogEntryOnSuccess
**			09/24/2009 mem - Updated @JobList='All' to match jobs LIKE '%peptide_hit'
**						   - Added new mode: @JobList='Missing'
**			01/06/2012 mem - Updated to use T_Peptides.Job
**
*****************************************************/
(
	@JobList varchar(max),					-- Comma separated list of one or more jobs.  Can alternatively be 'Missing' or 'All'.  'Missing' will process jobs that have null Max_Cleavage_State entries in T_Peptides.  'All' will process all jobs in T_Analysis_Description
	@MaxJobsPerBatch int = 50,				-- Maximum jobs to process at a time
	@PostLogEntryOnSuccess tinyint = 0,		-- If 0, then will only call PostLogEntry if an error
	@infoOnly tinyint = 0,					-- Set to 1 to preview the new values; set to 2 to only see the jobs that would be processed
	@message varchar(512)='' output
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	declare @JobCountTotal int
	declare @BatchJobCount int
	declare @BatchJobMin int
	declare @BatchJobMax int
	declare @JobDescription varchar(128)

	declare @EntryIDStart int
	declare @continue int
	declare @IterationsCompleted int
	
	Set @JobCountTotal = 0

	---------------------------------------------------
	-- Validate the inputs
	---------------------------------------------------	
	
	Set @JobList = IsNull(@JobList, '')
	
	Set @MaxJobsPerBatch = IsNull(@MaxJobsPerBatch, 50)
	If @MaxJobsPerBatch < 2
		Set @MaxJobsPerBatch = 2

	Set @PostLogEntryOnSuccess = IsNull(@PostLogEntryOnSuccess, 1)
	
	Set @infoOnly = IsNull(@infoOnly, 0)
	set @message = ''
	
	---------------------------------------------------
	-- Create two temporary tables
	---------------------------------------------------
	--
	CREATE TABLE #Tmp_JobsToProcess (
		EntryID int IDENTITY(1,1),
		Job int NOT NULL
	)
	CREATE UNIQUE CLUSTERED INDEX #IX_Tmp_JobsToProcess ON #Tmp_JobsToProcess (EntryID)

	CREATE TABLE #Tmp_JobsCurrentBatch (
		Job int NOT NULL
	)
	CREATE UNIQUE CLUSTERED INDEX #IX_Tmp_JobsCurrentBatch ON #Tmp_JobsCurrentBatch (Job)
	
	CREATE TABLE #Tmp_PeptideCleavageStateVals (
		Peptide_ID int NOT NULL,
		Cleavage_State_Max tinyint NULL
	)
	CREATE CLUSTERED INDEX #IX_Tmp_PeptideCleavageStateVals ON #Tmp_PeptideCleavageStateVals (Peptide_ID)
	
	
	---------------------------------------------------
	-- Populate #Tmp_JobsToProcess
	---------------------------------------------------
	--
	If @JobList = 'All' Or @JobList = 'Missing'
	Begin
		If @JobList = 'All'
			INSERT INTO #Tmp_JobsToProcess (Job)
			SELECT Job
			FROM T_Analysis_Description
			WHERE ResultType LIKE '%peptide_hit'
			ORDER BY Job
		Else
			INSERT INTO #Tmp_JobsToProcess (Job)
			SELECT Job
			FROM T_Peptides
			WHERE (Cleavage_State_Max IS NULL)
			GROUP BY Job
			ORDER BY Job
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
	End
	Else
	Begin
		INSERT INTO #Tmp_JobsToProcess (Job)
		SELECT DISTINCT Value
		FROM dbo.udfParseDelimitedIntegerList(@JobList, ',')
		ORDER BY Value
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
	End
	
	Set @JobCountTotal = @myRowCount
	
	If @myError <> 0
	Begin
		set @message = 'Error parsing @JobList: ' + @JobList
		Goto Done
	End
	
	If @myRowCount = 0
	Begin
		If @JobList = 'Missing'
			Set @message = 'No jobs were found to process (all jobs in T_Peptides already have valid Cleavage_State_Max values)'
		Else
		Begin
			If @JobList = 'All'
				set @message = 'Warning: No Peptide_Hit jobs were found in T_Analysis_Description'
			Else
			Begin
				set @message = 'Error: @JobList parameter is empty'
				Set @myError = 50000
			End
		End
	End
	Else
	Begin -- <a>
		-- Process @MaxJobsPerBatch jobs at a time from #Tmp_JobsToProcess
		
		Set @EntryIDStart = 0
		Set @Continue = 1
		Set @IterationsCompleted = 0
		
		While @Continue = 1
		Begin -- <b>
			TRUNCATE TABLE #Tmp_JobsCurrentBatch
			
			INSERT INTO #Tmp_JobsCurrentBatch (Job)
			SELECT TOP (@MaxJobsPerBatch) Job
			FROM #Tmp_JobsToProcess
			WHERE EntryID >= @EntryIDStart
			ORDER BY EntryID
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			
			Set @BatchJobCount = @myRowCount

			If @BatchJobCount = 0
				Set @Continue = 0
			Else
			Begin -- <c>
	
				If @BatchJobCount = 1
				Begin
					-- Just one job in @JobList
					SELECT @JobDescription = 'Job ' + Convert(varchar(12), Job)
					FROM #Tmp_JobsCurrentBatch
				End
				Else
				Begin
					-- Multiple jobs in @JobList
					SELECT @BatchJobMin = Min(Job)
					FROM #Tmp_JobsCurrentBatch

					SELECT @BatchJobMax = Max(Job)
					FROM #Tmp_JobsCurrentBatch

					Set @JobDescription = 'Jobs ' + Convert(varchar(12), IsNull(@BatchJobMin, 0)) + ' to ' + Convert(varchar(12), IsNull(@BatchJobMax, 0)) + ' (' + Convert(varchar(12), @BatchJobCount) + ' jobs)'
				End

				Set @JobDescription = IsNull(@JobDescription, 'Job ??')
	
				
				---------------------------------------------------
				-- Populate a temporary table with the peptides for the job(s)
				---------------------------------------------------
				--
				TRUNCATE TABLE #Tmp_PeptideCleavageStateVals
				
				If @infoOnly <= 1
				Begin
					INSERT INTO #Tmp_PeptideCleavageStateVals (Peptide_ID, Cleavage_State_Max)
					SELECT Peptide_ID, NULL AS Cleavage_State_Max
					FROM T_Peptides Pep INNER JOIN
						#Tmp_JobsCurrentBatch JobQ ON Pep.Job = JobQ.Job
					--
					SELECT @myRowCount = @@rowcount, @myError = @@error
				End
				Else
				Begin
					SELECT @myRowCount = COUNT(*)
					FROM T_Peptides Pep INNER JOIN
						#Tmp_JobsCurrentBatch JobQ ON Pep.Job = JobQ.Job
				End
				
				If @myRowCount = 0
				Begin
					-- Update @message with a warning, but do not return an error
					set @message = 'Warning: No peptides found for ' + @JobDescription
					
					If @infoOnly = 0
						exec PostLogEntry 'Warning', @message, 'UpdatePeptideCleavageStateMax'
					Else
						print @message
				End
				Else
				Begin -- <d>

					if @infoOnly >= 2
					Begin
						Print 'Would update ' + Convert(varchar(12), @myRowCount) + ' peptides for ' + @JobDescription
					End
					Else
					Begin -- <e>
						
						---------------------------------------------------
						-- Compute the max cleavage state value for each peptide using T_Peptide_to_Protein_Map
						---------------------------------------------------
						--
						UPDATE #Tmp_PeptideCleavageStateVals
						SET Cleavage_State_Max = ComputeQ.Cleavage_State_Max
						FROM #Tmp_PeptideCleavageStateVals Target
							INNER JOIN ( SELECT PPM.Peptide_ID,
												MAX(PPM.Cleavage_State) AS Cleavage_State_Max
										FROM #Tmp_PeptideCleavageStateVals Src
											INNER JOIN T_Peptide_to_Protein_Map PPM
												ON Src.Peptide_ID = PPM.Peptide_ID
										GROUP BY PPM.Peptide_ID 
										) ComputeQ
							ON Target.Peptide_ID = ComputeQ.Peptide_ID
						--
						SELECT @myRowCount = @@rowcount, @myError = @@error


						---------------------------------------------------
						-- If any peptides have a null entry in #Tmp_PeptideCleavageStateVals,
						-- then we need to manually compute the cleavage state
						---------------------------------------------------

						-- Define Cleavage State
						-- Note that this update query matches that in CalculateCleavageState		
						--
						UPDATE #Tmp_PeptideCleavageStateVals
						SET Cleavage_State_Max = 
							CASE WHEN Pep.Peptide LIKE '[KR].%[KR].[^P]' AND Pep.Peptide NOT LIKE '_.P%' THEN 2		-- Fully tryptic
							WHEN Pep.Peptide LIKE '[KR].%[KR][^A-Z].[^P]' AND Pep.Peptide NOT LIKE '_.P%' THEN 2	-- Fully tryptic, allowing modified K or R
							WHEN Pep.Peptide LIKE '-.%[KR].[^P]' THEN 2				-- Fully tryptic at the N-terminus
							WHEN Pep.Peptide LIKE '-.%[KR][^A-Z].[^P]' THEN 2		-- Fully tryptic at the N-terminus, allowing modified K or R
							WHEN Pep.Peptide LIKE '[KR].[^P]%.-' THEN 2				-- Fully tryptic at C-terminus
							WHEN Pep.Peptide LIKE '-.%.-' THEN 2					-- Label sequences spanning the entire protein as fully tryptic
							WHEN Pep.Peptide LIKE '[KR].[^P]%.%' THEN 1				-- Partially tryptic
							WHEN Pep.Peptide LIKE '%.%[KR].[^P-]' THEN 1			-- Partially tryptic
							WHEN Pep.Peptide LIKE '%.%[KR][^A-Z].[^P-]' THEN 1		-- Partially tryptic, allowing modified K or R
							ELSE 0
							END
						FROM #Tmp_PeptideCleavageStateVals PCS
							INNER JOIN T_Peptides Pep
							ON PCS.Peptide_ID = Pep.Peptide_ID AND
								PCS.Cleavage_State_Max IS NULL
						--
						SELECT @myRowCount = @@rowcount, @myError = @@error


						If @infoOnly = 0
						Begin -- <f1>
							---------------------------------------------------
							-- Apply the changes to T_Peptides
							---------------------------------------------------
							UPDATE T_Peptides
							SET Cleavage_State_Max = #Tmp_PeptideCleavageStateVals.Cleavage_State_Max
							FROM T_Peptides Pep
								INNER JOIN #Tmp_PeptideCleavageStateVals
								ON #Tmp_PeptideCleavageStateVals.Peptide_ID = Pep.Peptide_ID 
							WHERE Pep.Cleavage_State_Max Is Null OR
								#Tmp_PeptideCleavageStateVals.Cleavage_State_Max <> Pep.Cleavage_State_Max
							--
							SELECT @myRowCount = @@rowcount, @myError = @@error

							If @myError <> 0
							Begin
								set @message = 'Error updating Cleavage_State_Max values for ' + @JobDescription
								Exec PostLogEntry 'Error', @message, 'UpdatePeptideCleavageStateMax'								
								set @myError = 0
							End
							Else
							Begin
								set @message = 'Updated Cleavage_State_Max values for ' + convert(varchar(12), @myRowCount) + ' peptides for ' + @JobDescription
								
								If @PostLogEntryOnSuccess <> 0
									Exec PostLogEntry 'Normal', @message, 'UpdatePeptideCleavageStateMax'
							End
							
						End -- </f1>
						Else
						Begin -- <f2>
							SELECT Pep.Peptide_ID,
								Pep.Peptide,
								Pep.Cleavage_State_Max,
								#Tmp_PeptideCleavageStateVals.Cleavage_State_Max AS Cleavage_State_Max_New
							FROM T_Peptides Pep
								INNER JOIN #Tmp_PeptideCleavageStateVals
								ON #Tmp_PeptideCleavageStateVals.Peptide_ID = Pep.Peptide_ID 
							WHERE Pep.Cleavage_State_Max Is Null OR
								#Tmp_PeptideCleavageStateVals.Cleavage_State_Max <> Pep.Cleavage_State_Max
							--
							SELECT @myRowCount = @@rowcount, @myError = @@error
						End -- </f2>
					
					End -- </e>
					
				End -- </d>
			
				
				Set @EntryIDStart = @EntryIDStart + @MaxJobsPerBatch

				Set @IterationsCompleted = @IterationsCompleted + 1

			End -- </c>

		End -- </b>
	End -- </a>
	
	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:

	If @myError <> 0
	Begin
		If @infoOnly = 0
			exec PostLogEntry 'Error', @message, 'UpdatePeptideCleavageStateMax'
		Else
			Print @message
	End
	Else
	Begin
		If @IterationsCompleted > 1
			Set @message = 'Processed ' + convert(varchar(12), @JobCountTotal) + ' jobs in ' + Convert(varchar(12), @IterationsCompleted) + ' batches of ' + Convert(varchar(12), @MaxJobsPerBatch) + ' jobs per batch'
	End

	return @myError

GO
