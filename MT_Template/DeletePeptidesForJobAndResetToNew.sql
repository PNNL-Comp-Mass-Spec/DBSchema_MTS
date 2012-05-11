/****** Object:  StoredProcedure [dbo].[DeletePeptidesForJobAndResetToNew] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE DeletePeptidesForJobAndResetToNew
/****************************************************
**
**	Desc: 
**		Deletes all peptides for the given job
**		If @ResetStateToNew = 1, then resets
**		  the job's state to 1 = new.
**
**	Return values: 0 if no error; otherwise error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	09/21/2004
**			12/14/2004 mem - Now accepts a list of jobs to delete and reset
**			12/11/2005 mem - Updated to support XTandem results
**			03/13/2006 mem - Now calling UpdateCachedHistograms if any data is deleted from T_Peptides
**			09/05/2006 mem - Updated to use dbo.udfParseDelimitedList and to check for invalid job numbers
**						   - Now posting a log entry for the processed jobs
**			09/09/2006 mem - Updated to post a log entry only if rows were deleted from T_Peptides
**			12/01/2006 mem - Now using udfParseDelimitedIntegerList to parse @JobListToDelete
**			11/05/2008 mem - Added support for Inspect results (type IN_Peptide_Hit)
**			10/06/2011 mem - Added support for MSGFDB results (type MSG_Peptide_Hit)
**			01/06/2012 mem - Updated to use T_Peptides.Job
**    
*****************************************************/
(
	@JobListToDelete varchar(4096),			-- Comma separated list of jobs to delete
	@ResetStateToNew tinyint = 0
)
AS
	set nocount on

	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Declare @commaLoc int
	Declare @Message varchar(512)
	Declare @JobListProcessed varchar(512)
	Set @JobListProcessed = ''
	
	Declare @DataDeleted int
	Set @DataDeleted = 0
	
	-- Create a temporary table to hold the jobs to delete
	
	CREATE TABLE #JobListToDelete (
		Job int NOT NULL ,
	)

	CREATE CLUSTERED INDEX #IX_Tmp_JobListToDelete_Job ON #JobListToDelete (Job)

	-- Populate #JobListToDelete with the jobs in @JobListToDelete
	INSERT INTO #JobListToDelete (Job)
	SELECT value
	FROM dbo.udfParseDelimitedIntegerList(@JobListToDelete, ',')
	ORDER BY value
	
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

	DELETE T_Score_Sequest
	FROM T_Peptides INNER JOIN T_Score_Sequest 
		 ON T_Peptides.Peptide_ID = T_Score_Sequest.Peptide_ID
		 INNER JOIN #JobListToDelete ON T_Peptides.Job = #JobListToDelete.Job
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto Done
	
	DELETE T_Score_Discriminant
	FROM T_Peptides INNER JOIN T_Score_Discriminant 
		 ON T_Peptides.Peptide_ID = T_Score_Discriminant.Peptide_ID
		 INNER JOIN #JobListToDelete ON T_Peptides.Job = #JobListToDelete.Job
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto Done

	DELETE T_Score_XTandem
	FROM T_Peptides INNER JOIN T_Score_XTandem 
		 ON T_Peptides.Peptide_ID = T_Score_XTandem.Peptide_ID
		 INNER JOIN #JobListToDelete ON T_Peptides.Job = #JobListToDelete.Job
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto Done

	DELETE T_Score_Inspect
	FROM T_Peptides INNER JOIN T_Score_Inspect
		 ON T_Peptides.Peptide_ID = T_Score_Inspect.Peptide_ID
		 INNER JOIN #JobListToDelete ON T_Peptides.Job = #JobListToDelete.Job
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto Done

	DELETE T_Score_MSGFDB
	FROM T_Peptides INNER JOIN T_Score_MSGFDB
		 ON T_Peptides.Peptide_ID = T_Score_MSGFDB.Peptide_ID
		 INNER JOIN #JobListToDelete ON T_Peptides.Job = #JobListToDelete.Job
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto Done

	DELETE T_Peptides 
	FROM T_Peptides
		 INNER JOIN #JobListToDelete ON T_Peptides.Job = #JobListToDelete.Job
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	If @myError <> 0 Goto Done

	-- Update T_Mass_Tags.Number_of_Peptides and .High_Normalized_Score, if necessary
	If @myRowCount > 0
	Begin
		Set @DataDeleted = 1
		Exec UpdateCachedHistograms @InvalidateButDoNotProcess=1
		Exec ComputeMassTagsAnalysisCounts
	End

	If @DataDeleted = 0 And @ResetStateToNew = 0
		Set @message = 'Did not find any data to delete for jobs ' + @JobListProcessed
	Else
	Begin
		Set @DataDeleted = 1
		
		-- Prepare the log message
		Set @message = 'Deleted data for jobs ' + @JobListProcessed
		If Len(@message) > 475
		Begin
			-- Find the next comma after position 475
			Set @commaLoc = CharIndex(',', @Message, 475)
			Set @message = Left(@message, @commaLoc) + '...'
		End
	End
		
	If @ResetStateToNew <> 0
	Begin
		UPDATE T_Analysis_Description
		SET State = 1
		FROM T_Analysis_Description
			 INNER JOIN #JobListToDelete ON T_Analysis_Description.Job = #JobListToDelete.Job
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		If @myError <> 0 Goto Done
		
		Set @message = @message + '; Job states have been reset to 1'
	End

	If @DataDeleted <> 0
		exec PostLogEntry 'Normal', @message, 'DeletePeptidesForJobAndResetToNew'
	
Done:
	Return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[DeletePeptidesForJobAndResetToNew] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[DeletePeptidesForJobAndResetToNew] TO [MTS_DB_Lite] AS [dbo]
GO
