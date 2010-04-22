/****** Object:  StoredProcedure [dbo].[CheckStaleJobs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.CheckStaleJobs
/****************************************************
** 
**	Desc: 	Looks for Jobs in T_Analysis_Description with a processing state between
**			@JobProcessingStateMin and @JobProcessingStateMax and with Last_Affected
**			over @maxHoursProcessing hours old; posts a log entry if any are found
**
**	Return values: 0: success, otherwise, error code
** 
**	Auth: 	mem
**	Date: 	10/31/2005
**			06/28/2006 mem - Updated call to PostLogEntry to include single quotes around CheckStaleJobs
**			08/27/2008 mem - Added a job count to the stale jobs message
**    
*****************************************************/
(
	@maxHoursProcessing int = 48,
	@JobProcessingStateMin int = 10,
	@JobProcessingStateMax int = 69,
	@message varchar(255) = '' output
)
As
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @JobCount int
	declare @JobMin int
	declare @JobMax int
	declare @DateMax datetime
	declare @StateRange varchar(64)

	set @message = ''

	--------------------------------------------------------------
	-- Create a temporary table to hold the stale jobs
	--------------------------------------------------------------
	CREATE TABLE #StaleJobs (
		Job int NOT NULL,
		Last_Affected datetime NULL
	) 
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	If @myError <> 0
	Begin
		Set @message = 'Could not create temporary table #StaleJobs'
		goto Done
	End

	
	--------------------------------------------------------------
	-- Populate #StaleJobs with any stale jobs
	--------------------------------------------------------------
	--
	INSERT INTO #StaleJobs (Job, Last_Affected)
	SELECT	Job, IsNull([Last_Affected], [Created])
	FROM	T_Analysis_Description
	WHERE	([Process_State] Between @JobProcessingStateMin AND @JobProcessingStateMax) AND
			DateDiff(Minute, IsNull([Last_Affected], [Created]), GetDate()) > @maxHoursProcessing * 60
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	If @myRowCount > 0
	Begin

		--------------------------------------------------------------
		-- Post a log entry summarizing the stale jobs
		--------------------------------------------------------------

		SELECT @JobCount = COUNT(Job), @DateMax = MAX(Last_Affected),
			   @JobMin = MIN(Job), @JobMax = MAX(Job)
		FROM #StaleJobs
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		Set @StateRange = Convert(varchar(9), @JobProcessingStateMin) + ' and ' + Convert(varchar(9), @JobProcessingStateMax)	
		If @JobCount <= 1
			Set @message = 'Stale job found: Job ' + Convert(varchar(12), @JobMin) + ' has a state between ' + @StateRange + ' and was'
		Else
			Set @message = 'Stale jobs found: ' + Convert(varchar(12), @JobCount) + ' jobs (' + Convert(varchar(12), @JobMin) + ' to ' + Convert(varchar(12), @JobMax) + ') have states between ' + @StateRange + ' and were'
	
		Set @message = @message + ' last updated over ' + Convert(varchar(9), @maxHoursProcessing) + ' hours ago (' + Convert(varchar(30), @DateMax) + ')'
	
		-- Post this message at intervals of at least 24 hours
		execute PostLogEntry 'Error', @message, 'CheckStaleJobs', 24
	End

	
Done:
	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[CheckStaleJobs] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[CheckStaleJobs] TO [MTS_DB_Lite] AS [dbo]
GO
