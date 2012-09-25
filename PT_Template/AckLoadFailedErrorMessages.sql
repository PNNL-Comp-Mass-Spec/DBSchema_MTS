/****** Object:  StoredProcedure [dbo].[AckLoadFailedErrorMessages] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE AckLoadFailedErrorMessages
/****************************************************
**
**	Desc:	Looks Look for Jobs in state 15 that have previously 
**          failed loading but have now succeded
**            
**          Update the log entries for "Error calling OpenTextFile" 
**          to be "ErrorIgnore" instead of "Error"
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**	
**	Auth:	mem
**	Date:	08/03/2012 mem - Initial Version
**    
*****************************************************/
(
	@infoOnly tinyint = 0,
	@CheckAllRecentJobs tinyint = 0
)
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	declare @message varchar(256)
	
	declare @job int	
	declare @PathToFind varchar(512)
	declare @continue tinyint

	declare @RetryLoadCount int
	declare @MaxRetryLoadCount int
	Set @MaxRetryLoadCount = 5

	declare @tblLogEntryIDs table(Entry_ID int not null, Job int not null)

	------------------------------------
	-- Create a table to hold the jobs to process
	------------------------------------	

	Create Table #TmpJobsToProcess  (
		Job int not null
	)
	Create Clustered Index #IX_TmpJobsToProcess On #TmpJobsToProcess(Job)
	
	Set @message = ''
	Set @infoOnly = IsNull(@infoOnly, 0)
	Set @CheckAllRecentJobs = IsNull(@CheckAllRecentJobs, 0)
	
	------------------------------------
	-- Find jobs in T_Analysis_Description with state 15
	------------------------------------	
	--
	INSERT INTO #TmpJobsToProcess( Job )
	SELECT Job
	FROM T_Analysis_Description
	WHERE Process_State = 15
	ORDER BY Job
	
	If @CheckAllRecentJobs <> 0
	Begin
		------------------------------------
		-- Find jobs that recently changed from state 9 to state 10
		------------------------------------
			
		INSERT INTO #TmpJobsToProcess( Job )
		SELECT Job
		FROM T_Analysis_Description
		WHERE (Process_State > 15) AND
		      (Job IN ( SELECT Target_ID
		                FROM T_Event_Log
		                WHERE Target_Type = 1 AND
		                      Target_State = 10 AND
		                      Prev_Target_State = 9 AND
		                      (DATEDIFF(DAY, entered, GETDATE()) < 7) ))

	End
	
	------------------------------------
	-- Process each job in #TmpJobsToProcess
	------------------------------------	
	--
	set @job = -1
	set @continue = 1
	
	While @continue = 1
	Begin
		SELECT TOP 1 @Job = TAD.Job,
		             @PathToFind = dbo.udfCombinePaths(dbo.udfCombinePaths(Vol_Client, Dataset_Folder), Results_Folder)
		FROM #TmpJobsToProcess J
		     INNER JOIN T_Analysis_Description TAD
		       ON J.Job = TAD.Job
		WHERE TAD.Job > @job
		ORDER BY TAD.Job
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myRowCount = 0
			Set @continue = 0
		Else
		Begin
			
			INSERT INTO @tblLogEntryIDs (Entry_ID, Job)
			SELECT Entry_ID, @Job
			FROM T_Log_Entries
			WHERE (Type = 'error') AND
				(posted_by = 'LoadResultsForAvailableAnalyses') AND
				(message LIKE 'Error%' + @PathToFind + '%') AND
				DateDiff(DAY, posting_time, GetDate()) < 7
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
				
		End
	End

	If @InfoOnly <> 0
	Begin
		SELECT J.Job,
		       E.Entry_ID,
		       LE.Message
		FROM #TmpJobsToProcess J
		     LEFT OUTER JOIN @tblLogEntryIDs E
		       ON J.Job = E.Job
		     LEFT OUTER JOIN T_Log_Entries LE
		       ON E.Entry_ID = LE.Entry_ID
		ORDER BY J.Job

	End
	Else
	Begin
		UPDATE T_Log_Entries
		SET Type = 'ErrorIgnore'
		WHERE Entry_ID IN ( SELECT Entry_ID
		                    FROM @tblLogEntryIDs ) And Type = 'Error'
		
	End
	
	
	return @myError


GO
