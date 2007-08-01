/****** Object:  StoredProcedure [dbo].[DeleteSeqCandidateDataForSkippedJobs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.DeleteSeqCandidateDataForSkippedJobs
/****************************************************
**
**	Desc: 
**		Deletes the entries in the T_Seq_Candidate tables
**		for jobs with Process_State @ProcessStateMatch that were matched against
**		a scrambled protein database
**
**	Return values: 0 if no error; otherwise error code
**
**	Auth:	mem
**	Date:	02/07/2007
**    
*****************************************************/
(
	@ProcessStateMatch int = 6,
	@JobListOverride varchar(4096)='',
	@CreatedHoldoffDays int = 32,			-- Only jobs created in this DB more than @CreatedHoldoffDays before the present will be examined; however, this parameter is ignored if @JobListOverride is used
	@InfoOnly tinyint = 0,
	@message varchar(256)='' output
)
AS
	set nocount on

	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Declare @JobListProcessed varchar(512)
	Set @JobListProcessed = ''
	
	Declare @DataDeleted tinyint
	Set @DataDeleted = 0
	
	declare @CommaLoc tinyint
	
	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Begin Try
		
		Set @CurrentLocation = 'Create temporary tables'
		
		-- Create a temporary table to hold the jobs to delete
		CREATE TABLE #JobListToDelete (
			Job int NOT NULL
		)

		CREATE CLUSTERED INDEX #IX_Tmp_JobListToDelete_Job ON #JobListToDelete (Job)

		If Len(@JobListOverride) > 0
		Begin
			Set @CurrentLocation = 'Parse @JobListOverride'
			
			-- Populate #JobListToDelete with the jobs in @JobListOverride
			INSERT INTO #JobListToDelete (Job)
			SELECT value
			FROM dbo.udfParseDelimitedList(@JobListOverride, ',')
			ORDER BY value
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
		End
		Else
		Begin
			Set @CurrentLocation = 'Query T_Analysis_description for available jobs'
			
			INSERT INTO #JobListToDelete (Job)
			SELECT Job
			FROM T_Analysis_description
			WHERE Process_State = @ProcessStateMatch AND (
					Organism_DB_Name LIKE '%scrambled.fasta' OR
					Organism_DB_Name LIKE '%reversed.fasta' OR
					Protein_Options_List LIKE 'seq[_]direction=reversed%' OR
					Protein_Options_List LIKE 'seq[_]direction=scrambled%') AND
				  DateDiff(day, Created, GetDate()) >= @CreatedHoldoffDays
			ORDER BY Job
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
		End
		
		Set @CurrentLocation = 'Validate jobs in #JobListToDelete'
		
		-- Look for jobs not present in T_Analysis_Description
		Set @JobListProcessed = ''
		SELECT @JobListProcessed = @JobListProcessed + Convert(varchar(12), JL.Job) + ','
		FROM #JobListToDelete JL LEFT OUTER JOIN
			T_Analysis_Description TAD ON JL.Job = TAD.Job
		WHERE TAD.Job Is Null
		ORDER BY JL.Job
		
		If Len(IsNull(@JobListProcessed, '')) > 0
		Begin
			Set @Message = 'Warning, invalid jobs specified: ' + left(@JobListProcessed, Len(@JobListProcessed)-1)		
			SELECT @Message AS Message
			Print @Message

			Set @Message = ''
			
			-- Delete the invalid jobs
			DELETE #JobListToDelete
			FROM #JobListToDelete JL LEFT OUTER JOIN
				T_Analysis_Description TAD ON JL.Job = TAD.Job
			WHERE TAD.Job Is Null
		End

		-- Update @JobListProcessed with the list of valid jobs
		Set @JobListProcessed = ''
		SELECT @JobListProcessed = @JobListProcessed + Convert(varchar(12), Job) + ', '
		FROM #JobListToDelete
		ORDER BY Job	

		If Len(IsNull(@JobListProcessed, '')) = 0
		Begin
			Set @Message = 'Error: no valid jobs were found'

			SELECT @Message AS Message
			Print @Message

			Goto Done
		End
		
		-- Remove the trailing comma from @JobListProcessed
		Set @JobListProcessed = left(@JobListProcessed, Len(@JobListProcessed)-1)

		If @infoOnly <> 0
		Begin
			SELECT TAD.Job, TAD.Dataset, 
				   TAD.Organism_DB_Name, TAD.Protein_Collection_List,  TAD.Protein_Options_List, 
				   TAD.Created, TAD.Last_Affected, TAD.Process_State
			FROM #JobListToDelete JL INNER JOIN 
				 T_Analysis_Description TAD ON JL.Job = TAD.Job
			ORDER BY TAD.Job
			
			Goto Done
		End
			
		Set @CurrentLocation = 'Delete data from the T_Seq_Candidate tables'
		
		DELETE T_Seq_Candidate_to_Peptide_Map
		FROM T_Seq_Candidate_to_Peptide_Map SCPM INNER JOIN
			#JobListToDelete JobList ON SCPM.Job = JobList.Job
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		If @myError <> 0 Goto Done
		If @myRowCount <> 0 Set @DataDeleted = 1
		
		DELETE T_Seq_Candidate_ModDetails
		FROM T_Seq_Candidate_ModDetails SCMD INNER JOIN
			#JobListToDelete JobList ON SCMD.Job = JobList.Job
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		If @myError <> 0 Goto Done
		If @myRowCount <> 0 Set @DataDeleted = 1
	    
		DELETE T_Seq_Candidates
		FROM T_Seq_Candidates SC INNER JOIN 
			#JobListToDelete JobList ON SC.Job = JobList.Job
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		If @myError <> 0 Goto Done
		If @myRowCount <> 0 Set @DataDeleted = 1
		
		-- Prepare the log message
		Set @message = 'Deleted T_Seq_Candidate data for jobs ' + @JobListProcessed
		If Len(@message) > 475
		Begin
			-- Find the next comma after position 475
			Set @commaLoc = CharIndex(',', @Message, 475)
			Set @message = Left(@message, @commaLoc) + '...'
		End

		If @DataDeleted <> 0
		Begin
			exec PostLogEntry 'Normal', @message, 'DeleteSeqCandidateDataForSkippedJobs'
			SELECT @message
		End
		Else
			set @message = 'The specified jobs did not have any data in the T_Seq_Candidate tables'

	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'DeleteSeqCandidateDataForSkippedJobs')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
								@ErrorNum = @myError output, @message = @message output
		Goto Done
	End Catch

Done:
	Return @myError


GO
