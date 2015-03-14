/****** Object:  StoredProcedure [dbo].[UpdateResultsForAvailableAnalyses] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.UpdateResultsForAvailableAnalyses
/****************************************************
**
**	Desc: 
**      Calls LoadPeptidesForOneAnalysis for all jobs in 
**		  T_Analysis_Description with Process_State = @ProcessStateMatch and 
**		  ResultType: 'Peptide_Hit', 'XT_Peptide_Hit', 'IN_Peptide_Hit', or 'MSG_Peptide_Hit'
**
**		Sets @UpdateExistingData to 1 when loading the data to update existing results for each job
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	12/23/2011 mem - Initial version (modelled after LoadResultsForAvailableAnalyses)
**			12/05/2012 mem - Now using tblPeptideHitResultTypes to determine the valid Peptide_Hit result types
**    
*****************************************************/
(
	@ProcessStateMatch int = 55,
	@NextProcessState int = 60,
	@numJobsToProcess int = 50000,
	@numJobsProcessed int = 0 OUTPUT
)
AS
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	Set @myRowCount = 0
	Set @myError = 0
	
	Set @numJobsProcessed = 0
	
	declare @result int
	declare @UpdateEnabled tinyint
	declare @message varchar(255)
	declare @ErrorType varchar(50)

	Declare @jobAvailable int = 0
	
	declare @Job int
	declare @AnalysisTool varchar(64)
	declare @ResultType varchar(64)
	declare @numLoaded int
	declare @jobProcessed int
	
	declare @NextProcessStateToUse int
	
	declare @count int = 0

	declare @clientStoragePerspective tinyint = 1

	declare @UpdateExistingData tinyint = 1

	-----------------------------------------------------------
	-- See if any jobs are available to process
	-----------------------------------------------------------
	
	If Exists (SELECT * FROM T_Analysis_Description WHERE Process_State = @ProcessStateMatch)
		Set @jobAvailable = 1
	Else
	Begin
		Set @jobAvailable = 0
		Set @message = 'No analyses were available'
		Goto Done
	End

	-----------------------------------------------------------
	-- Create a temporary table to track the jobs that have been processed
	-- We use this table to avoid trying to re-process the same job repeatedly (if the processing fails, but Process_State doesn't get updated)
	-----------------------------------------------------------
	
	CREATE TABLE #Tmp_Processed_Jobs (
		Job int NOT NULL
	)

	CREATE CLUSTERED INDEX #IX_Tmp_Processed_Jobs ON #Tmp_Processed_Jobs (Job)
	

	-----------------------------------------------
	-- Lookup state of Synopsis File error ignore in T_Process_Step_Control
	-----------------------------------------------
	--
	Declare @IgnoreSynopsisFileFilterErrorsOnImport int = 0
	
	SELECT @IgnoreSynopsisFileFilterErrorsOnImport = enabled 
	FROM T_Process_Step_Control
	WHERE (Processing_Step_Name = 'IgnoreSynopsisFileFilterErrorsOnImport')


	-----------------------------------------------
	-- loop through new analyses and load peptides for each
	-----------------------------------------------
	--
	Set @job = 0
	Set @AnalysisTool = ''
	Set @ResultType = ''

	while @jobAvailable <> 0 AND @myError = 0
	Begin -- <a>
		
		-----------------------------------------------------------
		-- Get next available analysis from #Tmp_Available_Jobs
		-- Link into T_Analysis_Description to make sure the job
		--  is still in state @AvailableState and to lookup additional info
		-----------------------------------------------------------
		--
		Set @job = 0
		--
		SELECT TOP 1 @job = TAD.Job, 
					 @AnalysisTool = TAD.Analysis_Tool, 
					 @ResultType = TAD.ResultType
		FROM T_Analysis_Description TAD INNER JOIN
			 dbo.tblPeptideHitResultTypes() RTL ON TAD.ResultType = RTL.ResultType
		WHERE TAD.Process_State = @ProcessStateMatch AND 
			  NOT TAD.Job IN (SELECT Job FROM #Tmp_Processed_Jobs)
		ORDER BY TAD.Import_Priority, TAD.Job
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		If @myError <> 0
		Begin
			Set @message = 'Failure to fetch next analysis'
			Goto Done
		End
	
		If @myRowCount <> 1
			Set @jobAvailable = 0
		Else
		Begin -- <b>
		
			-- Add this job to #Tmp_Processed_Jobs
			INSERT INTO #Tmp_Processed_Jobs (Job)
			VALUES (@Job)
			
			-- Process the job
			Set @jobProcessed = 0
			
			If (@AnalysisTool IN ('Sequest', 'AgilentSequest', 'XTandem', 'Inspect', 'MSGFDB', 'MSAlign') OR @ResultType LIKE '%Peptide_Hit')
			Begin
				Set @NextProcessStateToUse = @NextProcessState
				exec @result = LoadPeptidesForOneAnalysis
							@NextProcessStateToUse,
							@Job, 
							@UpdateExistingData,
							@message output,
							@numLoaded output,
							@clientStoragePerspective
			
				Set @jobProcessed = 1
			End

			If @jobProcessed = 0
			Begin
				Set @message = 'Unknown analysis tool ''' + @AnalysisTool + ''' for Job ' + Convert(varchar(11), @Job)
				execute PostLogEntry 'Error', @message, 'UpdateResultsForAvailableAnalyses'
				Set @message = ''
				--
			End		
			Else
			Begin -- <c>
				-- make log entry
				--
				If @result = 0
					execute PostLogEntry 'Normal', @message, 'UpdateResultsForAvailableAnalyses'
				Else
				Begin -- <d>
					-- Note that error codes 60002 and 60004 are defined in SP LoadPeptidesForOneAnalysis 
					If @result = 60002 or @result = 60004
					Begin
						If @IgnoreSynopsisFileFilterErrorsOnImport = 1
							Set @ErrorType = 'ErrorIgnore'
						Else
							Set @ErrorType = 'Error'
					End
					Else
						Set @ErrorType = 'Error'
					--
					
					execute PostLogEntry @ErrorType, @message, 'UpdateResultsForAvailableAnalyses'
				End -- </d>
				
				-- bump running count of peptides loaded
				--
				Set @count = @count + @numLoaded

				-- check number of jobs processed
				--
				Set @numJobsProcessed = @numJobsProcessed + 1
				If @numJobsProcessed >= @numJobsToProcess 
					Set @jobAvailable = 0

			End -- </c>

		End -- </b>

		-- Validate that updating is enabled, abort if not enabled
		exec VerifyUpdateEnabled @CallingFunctionDescription = 'UpdateResultsForAvailableAnalyses', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
		If @UpdateEnabled = 0
			Goto Done

	End -- </a>

	-----------------------------------------------
	-- exit the stored procedure
	-----------------------------------------------
	-- 
Done:

	-- Post a log entry if an error exists
	If @myError <> 0
		execute PostLogEntry 'Error', @message, 'UpdateResultsForAvailableAnalyses'

	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[UpdateResultsForAvailableAnalyses] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[UpdateResultsForAvailableAnalyses] TO [MTS_DB_Lite] AS [dbo]
GO
