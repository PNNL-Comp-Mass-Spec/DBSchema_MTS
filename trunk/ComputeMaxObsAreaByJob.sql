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
**    
*****************************************************/
(
 	@JobsUpdated int = 0 output,
 	@message varchar(255) = '' output,
 	@JobFilterList varchar(1024) = '',
 	@infoOnly tinyint = 0,
 	@PostLogEntryOnSuccess tinyint = 0,
 	@JobBatchSize int = 1,
	@MaxJobsToProcess int = 0				-- Set to a positive number to limit the total number of jobs processed
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	set @infoOnly = IsNull(@infoOnly, 0)
	set @JobFilterList = IsNull(@JobFilterList, '')
	
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
	set @S = @S + ' SELECT Analysis_ID, SUM(CASE WHEN Seq_ID Is Null THEN 1 ELSE 0 END) AS Null_Seq_ID_Count'
	set @S = @S + ' FROM T_Peptides'
	If Len(@JobFilterList) > 0
		Set @SqlWhereClause = 'WHERE Analysis_ID In (' + @JobFilterList + ')'
		
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
	set @S = @S + ' GROUP BY Analysis_ID'
	If Len(@JobFilterList) = 0
		set @S = @S + ' HAVING SUM(Max_Obs_Area_In_Job) = 0'
	set @S = @S + ' ORDER BY Analysis_ID'

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
			
			Set @message = @message + '; cannot populate the Max_Obs_Are_In_Job column'
			
			If @infoOnly = 0
			Begin
				If @JobsToUpdate - @MatchCount > 0
					Set @message = @message + '; will skip the inappropriate jobs and process the remaining ones'
				
				execute PostLogEntry 'Error', @message, 'ComputeMaxObsAreaByJob'

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

			If @infoOnly = 0
			Begin -- <c>
				---------------------------------------------------
				-- Reset Max_Obs_Area_In_Job to 0 for the jobs in #T_Jobs_To_Update
				---------------------------------------------------
				--
				UPDATE T_Peptides
				SET Max_Obs_Area_In_Job = 0
				FROM T_Peptides AS Pep INNER JOIN
					#T_Jobs_To_Update AS JTU ON Pep.Analysis_ID = JTU.Job
				WHERE (JTU.Unique_Row_ID BETWEEN @MinUniqueRowID AND @MaxUniqueRowID) AND
					  Max_Obs_Area_In_Job <> 0
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
			End -- </c>

			---------------------------------------------------
			-- Compute the value for Max_Obs_Area_In_Job for the given jobs
			-- Values for jobs in #T_Jobs_To_Update will have been reset to 0 above,
			--  causing them to be processed by this query
			---------------------------------------------------
			--
			
			set @S = ''

			If @infoOnly <> 0
			Begin
				-- Return the Job and the number of rows that would be updated
				set @S = @S + ' SELECT TP.Analysis_ID, COUNT(TP.Peptide_ID) AS Peptide_Rows_To_Update'
			End
			Else
			Begin
				set @S = @S + ' UPDATE T_Peptides'
				set @S = @S + ' SET Max_Obs_Area_In_Job = 1'
			End

			set @S = @S + ' FROM T_Peptides AS TP INNER JOIN'
			set @S = @S +      ' (	SELECT  Pep.Analysis_ID, Pep.Seq_ID, '
			set @S = @S +                 ' MIN(Pep.Peptide_ID) AS Min_Peptide_ID'
			set @S = @S +         ' FROM T_Peptides AS Pep INNER JOIN'
			set @S = @S +           ' (  SELECT Pep.Analysis_ID, Pep.Seq_ID,'
			set @S = @S +                        ' IsNull(MAX(Peak_Area * Peak_SN_Ratio), 0) AS Max_Area_Times_SN'
			set @S = @S +                 ' FROM T_Peptides AS Pep INNER JOIN'
			set @S = @S +                      ' #T_Jobs_To_Update AS JTU ON Pep.Analysis_ID = JTU.Job'
			set @S = @S +                 ' WHERE NOT Pep.Seq_ID IS NULL AND '
			set @S = @S +                       ' (JTU.Unique_Row_ID BETWEEN ' + Convert(varchar(19), @MinUniqueRowID) + ' AND ' + Convert(varchar(19), @MaxUniqueRowID) + ')'
			set @S = @S +                 ' GROUP BY Pep.Analysis_ID, Pep.Seq_ID'
			set @S = @S +              ' ) AS LookupQ ON'
			set @S = @S +              ' Pep.Analysis_ID = LookupQ.Analysis_ID AND'
			set @S = @S +              ' Pep.Seq_ID = LookupQ.Seq_ID AND'
			set @S = @S +              ' LookupQ.Max_Area_Times_SN = IsNull(Pep.Peak_Area * Pep.Peak_SN_Ratio, 0)'
			set @S = @S + ' GROUP BY Pep.Analysis_ID, Pep.Seq_ID'
			set @S = @S +  ' ) AS BestObsQ ON'
			set @S = @S +      ' TP.Peptide_ID = BestObsQ.Min_Peptide_ID'
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			If @infoOnly <> 0
			Begin
				set @S = @S + ' GROUP BY TP.Analysis_ID'
				set @S = @S + ' ORDER BY TP.Analysis_ID'
			End

			exec @result = sp_executesql @S
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
			
			If @infoOnly <> 0
			Begin
				set @message = 'InfoOnly: ' + @message
				Select @message AS ComputeMaxObsAreaByJob_Message
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
