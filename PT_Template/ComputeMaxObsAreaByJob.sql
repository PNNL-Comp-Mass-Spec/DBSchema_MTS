/****** Object:  StoredProcedure [dbo].[ComputeMaxObsAreaByJob] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.ComputeMaxObsAreaByJob
/****************************************************
**
**	Desc: 
**		Populates column Max_Obs_Area_In_Job in T_Peptides,
**		 optionally filtering using @JobFilterList.  If jobs
**		 are provided by @JobFilterList then the Max_Obs_Are_In_Job
**		 values are reset to 0 prior to computation.
**		Note that Seq_ID values are required to populate Max_Obs_Are_In_Job
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	10/09/2005
**			10/12/2005 mem - Added parameter @PostLogEntryOnSuccess
**			03/01/2006 mem - Added parameter @JobBatchSize
**			03/03/2006 mem - Added parameter @MaxJobsToProcess
**			03/18/2006 mem - Now checking for jobs with Null Seq_ID values and skipping them since Seq_ID is required for populating ComputeMaxObsAreaByJob
**						   - Now calling VerifyUpdateEnabled
**			03/20/2006 mem - Now sorting on job when populating #T_Jobs_To_Update
**			11/27/2006 mem - Added support for option SkipPeptidesFromReversedProteins
**			07/29/2008 mem - Added parameter @PreviewSql
**			01/19/2010 mem - Now setting @duplicateEntryHoldoffHours to 24 when posting error messages
**			10/25/2011 mem - Switched to using Row_Number() when populating Max_Obs_Area_In_Job
**			12/29/2011 mem - Switched to using a Merge statement to update T_Peptides
**			01/06/2012 mem - Updated to use T_Peptides.Job
**    
*****************************************************/
(
 	@JobsUpdated int = 0 output,
 	@message varchar(255) = '' output,
 	@JobFilterList varchar(1024) = '',
 	@infoOnly tinyint = 0,
 	@PostLogEntryOnSuccess tinyint = 0,
 	@JobBatchSize int = 1,
	@MaxJobsToProcess int = 0,				-- Set to a positive number to limit the total number of jobs processed
	@PreviewSql tinyint = 0
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	set @infoOnly = IsNull(@infoOnly, 0)
	set @JobFilterList = IsNull(@JobFilterList, '')
	set @PreviewSql = IsNull(@PreviewSql, 0)
	
	set @JobsUpdated = 0
	set @message = ''

	declare @result int
	declare @UpdateEnabled tinyint
	declare @SkipPeptidesFromReversedProteins tinyint
	declare @JobsToUpdate int
	
	declare @S nvarchar(4000)
	declare @SqlWhereClause nvarchar(500)
	declare @MaxUniqueRowID int
	declare @MinUniqueRowID int
	declare @continue int
	
	declare @MatchCount int
	declare @JobStart int
	declare @JobEnd int
		
	---------------------------------------------------
	-- Create a temporary table
	---------------------------------------------------
	--
	CREATE TABLE #T_Jobs_To_Update (
		Unique_Row_ID int Identity(1,1),
		Job int NOT NULL,
		Null_Seq_ID_Count int NOT NULL
	)

	--------------------------------------------------------------
	-- Lookup the value of SkipPeptidesFromReversedProteins in T_Process_Step_Control
	-- Assume skipping is enabled if the value is not present
	--------------------------------------------------------------
	--
	SELECT @SkipPeptidesFromReversedProteins = Enabled
	FROM T_Process_Step_Control
	WHERE Processing_Step_Name = 'SkipPeptidesFromReversedProteins'
	--
	SELECT @myRowcount = @@rowcount, @myError = @@error
	
	Set @SkipPeptidesFromReversedProteins = IsNull(@SkipPeptidesFromReversedProteins, 1)
	
	---------------------------------------------------
	-- Look for jobs having Max_Obs_Area_In_Job=0 for all peptides
	-- In addition, count the number of peptides with null Seq_ID values 
	--  (skipping peptides with State_ID = 2 if @SkipPeptidesFromReversedProteins <> 0)
	---------------------------------------------------
	set @S = ''
	set @SqlWhereClause = ''
	set @S = @S + ' INSERT INTO #T_Jobs_To_Update (Job, Null_Seq_ID_Count)'
	set @S = @S + ' SELECT Job, SUM(CASE WHEN Seq_ID Is Null THEN 1 ELSE 0 END) AS Null_Seq_ID_Count'
	set @S = @S + ' FROM T_Peptides'
	If Len(@JobFilterList) > 0
		Set @SqlWhereClause = 'WHERE Job In (' + @JobFilterList + ')'
		
	If @SkipPeptidesFromReversedProteins <> 0
	Begin
		If Len(@SqlWhereClause) = 0
			Set @SqlWhereClause = 'WHERE '
		Else
			Set @SqlWhereClause = @SqlWhereClause + ' AND '
		--
		Set @SqlWhereClause = @SqlWhereClause + 'State_ID <> 2'
	End
	
	Set @S = @S + ' ' + @SqlWhereClause
	set @S = @S + ' GROUP BY Job'
	If Len(@JobFilterList) = 0
		set @S = @S + ' HAVING SUM(Max_Obs_Area_In_Job) = 0'
	set @S = @S + ' ORDER BY Job'

	If @PreviewSql = 1
		Print @S
	
	exec @result = sp_executesql @S
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Error looking for Jobs with undefined Max_Obs_Area_In_Job values'
		goto Done
	end

	-- Count the number of jobs in #T_Jobs_To_Update	
	SELECT @JobsToUpdate = COUNT(Job)
	FROM #T_Jobs_To_Update
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	if @JobsToUpdate > 0
	Begin -- <a>

		---------------------------------------------------
		-- See if any of the jobs in #T_Jobs_To_Update have 
		--  Null Seq_ID values; post an error if any do
		---------------------------------------------------			
		Set @MatchCount= 0
		
		SELECT @MatchCount = COUNT(*), @JobStart = MIN(Job), @JobEnd = MAX(Job) 
		FROM #T_Jobs_To_Update
		WHERE Null_Seq_ID_Count > 0
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @MatchCount > 0
		Begin
			Set @message = 'Found ' + Convert(varchar(12), @MatchCount)
			If @MatchCount = 1
				Set @message = @message + ' job with 1 or more peptides having null Seq_ID values (Job ' + convert(varchar(19), @JobStart) + ')'
			else
				Set @message = @message + ' jobs with 1 or more peptides having null Seq_ID values (Jobs ' + convert(varchar(19), @JobStart) + ' through ' +  convert(varchar(19), @JobEnd) + ')'
			
			Set @message = @message + '; cannot populate the Max_Obs_Area_In_Job column'
			
			If @infoOnly = 0
			Begin
				If @JobsToUpdate - @MatchCount > 0
					Set @message = @message + '; will skip the inappropriate jobs and process the remaining ones'
				
				execute PostLogEntry 'Error', @message, 'ComputeMaxObsAreaByJob', @duplicateEntryHoldoffHours=24

				-- Delete the invalid jobs and continue
				DELETE FROM #T_Jobs_To_Update
				WHERE Null_Seq_ID_Count > 0
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
			End
			Else
			Begin
				Set @myError = 54001
				SELECT @message AS ErrorMessage
				Goto Done
			End
		End
		

		If @infoOnly <> 0
			Set @JobBatchSize = 100000

		If @JobBatchSize < 1
			Set @JobBatchSize = 10

		SELECT @MinUniqueRowID = MIN(Unique_Row_ID)
		FROM #T_Jobs_To_Update
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		
		Set @Continue = 1
		While @Continue <> 0
		Begin -- <b>
			Set @MaxUniqueRowID = @MinUniqueRowID + @JobBatchSize - 1

			---------------------------------------------------
			-- Compute the value for Max_Obs_Area_In_Job for the given jobs
			---------------------------------------------------
			--
			
			If @infoOnly <> 0
			Begin
				-- Return the Job and the number of rows that would be updated
				SELECT TP.Job, COUNT(TP.Peptide_ID) AS Peptide_Rows_To_Update				
				FROM T_Peptides TP
					INNER JOIN ( SELECT Peptide_ID
								FROM ( SELECT Pep.Peptide_id,
												Row_Number() OVER ( PARTITION BY Pep.Job, Pep.Seq_ID 
																	ORDER BY IsNull((Pep.Peak_Area * Pep.Peak_SN_Ratio), 0) DESC, Pep.Peptide_ID 
																) AS Area_Times_SN_RowNum
										FROM T_Peptides AS Pep
											INNER JOIN #T_Jobs_To_Update AS JTU
												ON Pep.Job = JTU.Job
										WHERE NOT Pep.Seq_ID IS NULL AND
										      JTU.Unique_Row_ID BETWEEN @MinUniqueRowID AND @MaxUniqueRowID
										) RankingQ
								WHERE Area_Times_SN_RowNum = 1 
								) FilterQ
					ON FilterQ.Peptide_ID = TP.Peptide_ID
				GROUP BY TP.Job
				ORDER BY TP.Job
			
			End
			Else
			Begin
				---------------------------------------------------
				-- Update T_Peptides using a Merge query
				---------------------------------------------------
				--

				MERGE T_Peptides as target
				USING (	SELECT Peptide_ID, 
						       CASE WHEN Area_Times_SN_RowNum = 1 Then 1 Else 0 END AS Max_Obs_Area_In_Job
				        FROM (	SELECT Pep.Job,
								       Peptide_ID,
								       Row_Number() OVER ( PARTITION BY Pep.Job, Pep.Seq_ID 
								                    ORDER BY IsNull((Pep.Peak_Area * Pep.Peak_SN_Ratio), 0) DESC, Pep.Peptide_ID ) AS Area_Times_SN_RowNum
								FROM T_Peptides AS Pep
								     INNER JOIN #T_Jobs_To_Update AS JTU
								       ON Pep.Job = JTU.Job
								WHERE NOT Pep.Seq_ID IS NULL AND
								      JTU.Unique_Row_ID BETWEEN @MinUniqueRowID AND @MaxUniqueRowID
				             ) RankingQ
					) AS Source (Peptide_id, Max_Obs_Area_In_Job)
				ON (target.Peptide_id = source.Peptide_id)
				WHEN Matched AND IsNull(Target.Max_Obs_Area_In_Job ,10) <> source.Max_Obs_Area_In_Job THEN
				UPDATE SET Max_Obs_Area_In_Job = source.Max_Obs_Area_In_Job;
	            	            
			End
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--
			if @myError <> 0
			begin
				set @message = 'Error populating Max_Obs_Area_In_Job in T_Peptides'
				goto Done
			end

			-- Count the number of jobs updated in this batch and update @JobsUpdated
			SELECT @myRowCount = COUNT(*)
			FROM #T_Jobs_To_Update JTU
			WHERE (JTU.Unique_Row_ID BETWEEN @MinUniqueRowID AND @MaxUniqueRowID)
			--
			Set @JobsUpdated = @JobsUpdated + @myRowCount
			
			-- Update @MinUniqueRowID
			Set @MinUniqueRowID = @MinUniqueRowID + @JobBatchSize
			
			-- See if any jobs remain in #T_Jobs_To_Update to process
			SELECT @Continue = Count(*)
			FROM #T_Jobs_To_Update
			WHERE Unique_Row_ID >= @MinUniqueRowID
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			If @myRowCount = 0
				Set @Continue = 0

			If @MaxJobsToProcess > 0 AND @MinUniqueRowID > @MaxJobsToProcess
				Set @Continue = 0

			If @PreviewSql <> 0
				Set @Continue = 0
				
			If @Continue > 0
			Begin
				-- Validate that updating is enabled, abort if not enabled
				exec VerifyUpdateEnabled @CallingFunctionDescription = 'ComputeMaxObsAreaByJob', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
				If @UpdateEnabled = 0
					Goto Done
			End

		End -- </b>
	End -- </a>

Done:
	If @myError <> 0
	Begin
		If Len(@message) = 0
			set @message = 'Error updating Max_Obs_Area_In_Job in T_Peptides, error code ' + convert(varchar(12), @myError)

		If @infoOnly = 0
			execute PostLogEntry 'Error', @message, 'ComputeMaxObsAreaByJob'

		Set @JobsUpdated = 0
	End
	Else
	Begin
		If @JobsUpdated > 0
		Begin
			set @message = 'Max_Obs_Area_In_Job updated for ' + convert(varchar(12), @JobsUpdated)
			If @JobsUpdated = 1
				set @message = @message + ' MS/MS Job'
			else
				set @message = @message + ' MS/MS Jobs'
				
			If Len(@JobFilterList) > 0
				set @message = @message + ': ' + @JobFilterList
			
			If @infoOnly <> 0 Or @PreviewSql <> 0
			Begin
				set @message = 'InfoOnly: ' + @message
				
				If @PreviewSql <> 0
					Print @message
				Else
					SELECT @message AS ComputeMaxObsAreaByJob_Message
			End
			Else
			Begin
				If @PostLogEntryOnSuccess <> 0
					execute PostLogEntry 'Normal', @message, 'ComputeMaxObsAreaByJob'
			End
		End
		Else
		Begin
			If @infoOnly <> 0
				Select 'InfoOnly: No jobs needing to be updated were found' As ComputeMaxObsAreaByJob_Message
		End
	End
	
	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[ComputeMaxObsAreaByJob] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[ComputeMaxObsAreaByJob] TO [MTS_DB_Lite] AS [dbo]
GO
