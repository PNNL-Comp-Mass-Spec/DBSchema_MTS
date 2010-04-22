/****** Object:  StoredProcedure [dbo].[LoadResultsForAvailableAnalyses] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.LoadResultsForAvailableAnalyses
/****************************************************
**
**	Desc: 
**      Calls LoadPeptidesForOneAnalysis for all jobs in 
**		  T_Analysis_Description with Process_State = @ProcessStateMatch and 
**		  ResultType: 'Peptide_Hit', 'XT_Peptide_Hit', or 'IN_Peptide_Hit'
**
**		Calls LoadMASICResultsForOneAnalysis for all jobs with ResultType = 'SIC'
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	grk
**	Date:	10/31/2001
**          06/02/2004 mem - Updated to post an error entry to the log if the call to LoadSequestPeptidesForOneAnalysis returns a non-zero value
**          07/03/2004 mem - Changed to use of Process_State and ResultType fields for choosing next job
**							 Now calling LoadSequestPeptidesForOneAnalysis only if the Analysis Tool is Sequest or AgilentSequest; 
**							 other tools will need customized LoadPeptides stored procedures
**          07/07/2004 grk - Use new sequest peptide file extractor (discriminant scoring)
**			08/07/2004 mem - Added call to SetProcessState and added @numJobsProcessed
**			09/09/2004 mem - Added use of @IgnoreSynopsisFileFilterErrorsOnImport
**			12/13/2004 mem - Updated to call LoadMASICResultsForOneAnalysis
**			12/29/2004 mem - Fixed @NextProcessState usage bug
**			12/11/2005 mem - Added support for ResultType 'XT_Peptide_Hit'; now using LoadPeptidesForOneAnalysis rather than LoadSequestPeptidesForOneAnalysis
**			01/15/2006 mem - Updated comments
**			03/11/2006 mem - Now calling VerifyUpdateEnabled
**			07/03/2006 mem - Now populating field RowCount_Loaded in T_Analysis_Description
**			09/12/2006 mem - Added support for Import_Priority column in T_Analysis_Description
**			10/11/2007 mem - Now calling ReindexDatabase after varying amounts of data have been loaded
**			10/30/2007 mem - Fixed bug that examined the wrong table to determine the number of jobs that have reached state @NextProcessStateToUse
**			08/26/2008 mem - Switched to finding the next available job using T_Analysis_Description instead of a temporary table
**			10/16/2008 mem - Added support for Inspect results (type IN_Peptide_Hit)
**			10/04/2009 mem - Added support for scripted Peptide_Hit jobs (where the tool name isn't the traditional Sequest, X!Tandem, or Inspect)
**			11/04/2009 mem - Changed states examined when counting the number of jobs loaded to date
**    
*****************************************************/
(
	@ProcessStateMatch int = 10,
	@NextProcessState int = 15,
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

	Declare @jobAvailable int
	Set @jobAvailable = 0
	
	declare @Job int
	declare @AnalysisTool varchar(64)
	declare @ResultType varchar(64)
	declare @numLoaded int
	declare @jobProcessed int
	
	declare @NextProcessStateToUse int
	
	declare @JobCount int

	declare @LastReindexTime datetime
	Set @LastReindexTime = '1/1/2000'
	
	declare @ReindexDB int
	set @ReindexDB = 0
	
	declare @ReindexMessage varchar(512)
	set @ReindexMessage = ''
	
	declare @count int
	Set @count = 0

	declare @clientStoragePerspective tinyint
	Set @clientStoragePerspective  = 1

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
	-- Populate a temporary table with the list of known Result Types
	-----------------------------------------------
	CREATE TABLE #T_ResultTypeList (
		ResultType varchar(64)
	)
	
	INSERT INTO #T_ResultTypeList (ResultType) Values ('Peptide_Hit')
	INSERT INTO #T_ResultTypeList (ResultType) Values ('XT_Peptide_Hit')
	INSERT INTO #T_ResultTypeList (ResultType) Values ('IN_Peptide_Hit')
	INSERT INTO #T_ResultTypeList (ResultType) Values ('SIC')

	-----------------------------------------------
	-- Lookup state of Synopsis File error ignore in T_Process_Step_Control
	-----------------------------------------------
	--
	Declare @IgnoreSynopsisFileFilterErrorsOnImport int
	Set @IgnoreSynopsisFileFilterErrorsOnImport = 0
	
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
			 #T_ResultTypeList ON TAD.ResultType = #T_ResultTypeList.ResultType
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
			Set @ReindexDB = 0
			Set @ReindexMessage = ''
			
			If (@AnalysisTool IN ('Sequest', 'AgilentSequest', 'XTandem', 'Inspect') OR @ResultType LIKE '%Peptide_Hit')
			Begin
				Set @NextProcessStateToUse = @NextProcessState
				exec @result = LoadPeptidesForOneAnalysis
							@NextProcessStateToUse,
							@Job, 
							@message output,
							@numLoaded output,
							@clientStoragePerspective
			
				Set @jobProcessed = 1
				
				-- Count the number jobs that have ever entered states 15 or 20
				SELECT @JobCount = COUNT(*)
				FROM T_Event_Log
				WHERE Target_State IN (15, 20)
				
				-- Reindex after 25 and after 100 Peptide_Hit jobs have been loaded
				If @JobCount = 25 Or @JobCount = 100
					Set @ReindexDB = 1
			End

			If (@AnalysisTool = 'MASIC_Finnigan' OR @AnalysisTool = 'MASIC_Agilent')
			Begin
				Set @NextProcessStateToUse = 75
				
				exec @result = LoadMASICResultsForOneAnalysis
								@NextProcessStateToUse,
								@Job, 
								@message output,
								@numLoaded output,
								@clientStoragePerspective
				
				Set @jobProcessed = 1

				-- Count the number jobs currently in state 75
				SELECT @JobCount = COUNT(*)
				FROM T_Event_Log
				WHERE Target_State = 75
				
				-- Reindex after 25 SIC jobs have been loaded
				If @JobCount = 25
					Set @ReindexDB = 1
			End
			
			If @ReindexDB <> 0
			Begin
				-- Reindex, but not if we already did so in this procedure within the last 20 minutes
				
				If DateDiff(minute, @LastReindexTime, GetDate()) > 20
				Begin
					UPDATE T_Process_Step_Control
					SET Enabled = 1
					WHERE (Processing_Step_Name = 'ReindexDatabaseNow')
					
					Set @ReindexMessage = 'Database now contains ' + Convert(varchar(12), @JobCount) + ' ' + @ResultType + ' jobs; requesting that the tables be reindexed'
				End
				Else
					Set @ReindexDB = 0
			End
			
			If @jobProcessed = 0
			Begin
				Set @message = 'Unknown analysis tool ''' + @AnalysisTool + ''' for Job ' + Convert(varchar(11), @Job)
				execute PostLogEntry 'Error', @message, 'LoadResultsForAvailableAnalyses'
				Set @message = ''
				--
				-- Reset the state for this job to 3, since peptide loading failed
				Exec SetProcessState @Job, 3
			End		
			Else
			Begin -- <c>
				-- make log entry
				--
				If @result = 0
					execute PostLogEntry 'Normal', @message, 'LoadResultsForAvailableAnalyses'
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
					
					execute PostLogEntry @ErrorType, @message, 'LoadResultsForAvailableAnalyses'
				End -- </d>

				-- Update RowCount_Loaded in T_Analysis_Description
				UPDATE T_Analysis_Description
				Set RowCount_Loaded = IsNull(@numLoaded, 0)
				WHERE Job = @Job
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				
				-- bump running count of peptides loaded
				--
				Set @count = @count + @numLoaded
								
				-- Post a log entry if @ReindexMessage contains a message
				If Len(@ReindexMessage) > 0
					Exec PostLogEntry 'Normal', @ReindexMessage, 'LoadResultsForAvailableAnalyses'

				-- Check whether the database needs to be re-indexed
				-- Don't use the value in @ReindexDB; examine table T_Process_Step_Control in case the state was manually changed
				
				Set @ReindexDB = 0
				SELECT @ReindexDB = enabled 
				FROM T_Process_Step_Control
				WHERE (Processing_Step_Name = 'ReindexDatabaseNow')
				
				If @ReindexDB <> 0
				Begin
					Exec @myError = ReindexDatabase @message output
					Set @LastReindexTime = GetDate()
				End


				-- check number of jobs processed
				--
				Set @numJobsProcessed = @numJobsProcessed + 1
				If @numJobsProcessed >= @numJobsToProcess 
					Set @jobAvailable = 0

			End -- </c>
		End -- </b>

		-- Validate that updating is enabled, abort if not enabled
		exec VerifyUpdateEnabled @CallingFunctionDescription = 'LoadResultsForAvailableAnalyses', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
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
		execute PostLogEntry 'Error', @message, 'LoadResultsForAvailableAnalyses'

	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[LoadResultsForAvailableAnalyses] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[LoadResultsForAvailableAnalyses] TO [MTS_DB_Lite] AS [dbo]
GO
