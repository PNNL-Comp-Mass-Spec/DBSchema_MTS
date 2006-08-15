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
	set @myRowCount = 0
	set @myError = 0
	
	set @numJobsProcessed = 0
	
	declare @result int
	declare @UpdateEnabled tinyint
	declare @message varchar(255)
	declare @ErrorType varchar(50)
	
	declare @Job int
	declare @AnalysisTool varchar(64)
	declare @ResultType varchar(64)
	declare @numLoaded int
	declare @jobprocessed int
	
	declare @NextProcessStateToUse int

	declare @count int
	set @count = 0

	declare @clientStoragePerspective tinyint
	set @clientStoragePerspective  = 1

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
	-- get next available analysis 
	-----------------------------------------------
	-- 
	set @job = 0
	set @AnalysisTool = ''
	set @ResultType = ''
	--
	SELECT TOP 1 @Job = TAD.Job, @AnalysisTool = TAD.Analysis_Tool, @ResultType = TAD.ResultType
	FROM dbo.T_Analysis_Description TAD INNER JOIN
		 #T_ResultTypeList ON TAD.ResultType = #T_ResultTypeList.ResultType
	WHERE TAD.Process_State = @ProcessStateMatch
	ORDER BY TAD.Job ASC
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Failure to fetch first analysis'
		goto Done
	end

	-----------------------------------------------
	-- verify that we got a job, and bail out with
	-- an appropriate message if not
	-----------------------------------------------
	--
	if @Job = 0
	begin
		set @message = 'No analyses were available'
		goto Done
	end
	

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
	while @Job <> 0 AND @myError = 0
	begin -- <a>

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
			
			set @jobProcessed = 1
		End
		
		If @jobProcessed = 0
		 Begin
			set @message = 'Unknown analysis tool ''' + @AnalysisTool + ''' for Job ' + Convert(varchar(11), @Job)
			execute PostLogEntry 'Error', @message, 'LoadResultsForAvailableAnalyses'
			set @message = ''
			--
			-- Reset the state for this job to 3, since peptide loading failed
			Exec SetProcessState @Job, 3
		 End		
		Else
		 Begin -- <b>
			-- make log entry
			--
			if @result = 0
				execute PostLogEntry 'Normal', @message, 'LoadResultsForAvailableAnalyses'
			else
			begin
				-- Note that error codes 60002 and 60004 are defined in SP LoadPeptidesForOneAnalysis 
				if @result = 60002 or @result = 60004
				begin
					if @IgnoreSynopsisFileFilterErrorsOnImport = 1
						set @ErrorType = 'ErrorIgnore'
					else
						set @ErrorType = 'Error'
				end
				else
					set @ErrorType = 'Error'
				--
				
				execute PostLogEntry @ErrorType, @message, 'LoadResultsForAvailableAnalyses'
			end

			-- Update RowCount_Loaded in T_Analysis_Description
			UPDATE T_Analysis_Description
			SET RowCount_Loaded = IsNull(@numLoaded, 0)
			WHERE Job = @Job
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			
			-- bump running count of peptides loaded
			--
			set @count = @count + @numLoaded
			
			-- check number of jobs processed
			--
			set @numJobsProcessed = @numJobsProcessed + 1
			if @numJobsProcessed >= @numJobsToProcess goto Done
		 End -- </b>
		
		-- get next available analysis
		--
		set @job = 0
		--
		SELECT TOP 1 @Job = TAD.Job, @AnalysisTool = TAD.Analysis_Tool, @ResultType = TAD.ResultType
		FROM dbo.T_Analysis_Description TAD INNER JOIN
			#T_ResultTypeList ON TAD.ResultType = #T_ResultTypeList.ResultType
		WHERE TAD.Process_State = @ProcessStateMatch
		ORDER BY TAD.Job ASC
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		if @myError <> 0
		begin
			set @message = 'Failure to fetch next analysis'
			goto Done
		end

		-- Validate that updating is enabled, abort if not enabled
		exec VerifyUpdateEnabled @CallingFunctionDescription = 'LoadResultsForAvailableAnalyses', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
		If @UpdateEnabled = 0
			Goto Done

	end -- </a>

	-----------------------------------------------
	-- exit the stored procedure
	-----------------------------------------------
	-- 
Done:

	-- Post a log entry if an error exists
	if @myError <> 0
		execute PostLogEntry 'Error', @message, 'LoadResultsForAvailableAnalyses'

	Return @myError


GO
