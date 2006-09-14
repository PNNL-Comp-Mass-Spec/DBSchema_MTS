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
**		  ResultType = 'Peptide_Hit' or ResultType = 'XT_Peptide_Hit'
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
**    
*****************************************************/
(
	@ProcessStateMatch int = 10,
	@NextProcessState int = 20,
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
	
	Declare @UniqueID int
	Set @UniqueID = 0

	declare @Job int
	declare @AnalysisTool varchar(64)
	declare @ResultType varchar(64)
	declare @numLoaded int
	declare @jobprocessed int
	
	declare @NextProcessStateToUse int

	declare @count int
	Set @count = 0

	declare @clientStoragePerspective tinyint
	Set @clientStoragePerspective  = 1

	-----------------------------------------------------------
	-- Create a temporary table to track the available jobs,
	--  ordered by Import_Priority and then by Job
	-----------------------------------------------------------
	
	CREATE TABLE #Tmp_Available_Jobs (
		UniqueID int Identity(1,1) NOT NULL,
		Job int NOT NULL
	)

	-----------------------------------------------------------
	-- Populate #Tmp_Available_Jobs
	-----------------------------------------------------------
	
	INSERT INTO #Tmp_Available_Jobs (Job)
	SELECT Job
	FROM T_Analysis_Description
	WHERE Process_State = @ProcessStateMatch
	ORDER BY Import_Priority, Job
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	If @myError <> 0
	Begin
		Set @message = 'Error populating #Tmp_Available_Jobs'
		Goto Done
	End

	If @myRowCount > 0
		Set @jobAvailable = 1
	Else
		Set @jobAvailable = 0

	If @jobAvailable = 0
	Begin
		Set @message = 'No analyses were available'
		Goto Done
	End
	
	-----------------------------------------------
	-- Populate a temporary table with the list of known Result Types
	-----------------------------------------------
	CREATE TABLE #T_ResultTypeList (
		ResultType varchar(64)
	)
	
	INSERT INTO #T_ResultTypeList (ResultType) Values ('Peptide_Hit')
	INSERT INTO #T_ResultTypeList (ResultType) Values ('XT_Peptide_Hit')
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
	Set @UniqueID = 0

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
					 @ResultType = TAD.ResultType,
					 @UniqueID = AJ.UniqueID
		FROM #Tmp_Available_Jobs AJ INNER JOIN 
			 T_Analysis_Description TAD on AJ.Job = TAD.Job INNER JOIN
			 #T_ResultTypeList ON TAD.ResultType = #T_ResultTypeList.ResultType
		WHERE TAD.Process_State = @ProcessStateMatch AND AJ.UniqueID > @UniqueID
		ORDER BY AJ.UniqueID
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
			Set @jobprocessed = 0
			If (@AnalysisTool = 'Sequest' OR @AnalysisTool = 'AgilentSequest' OR @AnalysisTool = 'XTandem')
			Begin
				Set @NextProcessStateToUse = @NextProcessState
				exec @result = LoadPeptidesForOneAnalysis
							@NextProcessStateToUse,
							@Job, 
							@message output,
							@numLoaded output,
							@clientStoragePerspective
			
				Set @jobprocessed = 1
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
