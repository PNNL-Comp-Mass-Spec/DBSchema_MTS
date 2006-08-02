SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[LoadResultsForAvailableAnalyses]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[LoadResultsForAvailableAnalyses]
GO



CREATE PROCEDURE dbo.LoadResultsForAvailableAnalyses
/****************************************************
**
**	Desc: 
**      Calls LoadSequestPeptidesForOneAnalysis for all jobs in 
**		  T_Analysis_Description with Process_State = @ProcessStateMatch
**		  and ResultType = 'Peptide_Hit'
**		Calls LoadMASICResultsForOneAnalysis for all jobs with ResultType = 'SIC'
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**		Auth: grk
**		Date: 10/31/2001
**            06/02/2004 mem - Updated to post an error entry to the log if the call to LoadSequestPeptidesForOneAnalysis returns a non-zero value
**            07/03/2004 mem - Changed to use of Process_State and ResultType fields for choosing next job
**                             Now calling LoadSequestPeptidesForOneAnalysis only if the Analysis Tool is Sequest or AgilentSequest; 
**                             other tools will need customized LoadPeptides stored procedures
**            07/07/2004 grk - Use new sequest peptide file extractor (discriminant scoring)
**			  08/07/2004 mem - Added call to SetProcessState and added @numJobsProcessed
**			  09/09/2004 mem - Added use of @IgnoreSynopsisFileFilterErrorsOnImport
**			  12/13/2004 mem - Updated to call LoadMASICResultsForOneAnalysis
**			  12/29/2004 mem - Fixed @NextProcessState usage bug
**    
*****************************************************/
	@ProcessStateMatch int = 10,
	@NextProcessState int = 20,
	@numJobsToProcess int = 50000,
	@numJobsProcessed int = 0 OUTPUT
AS
	declare @myError int
	set @myError = 0
	
	set @numJobsProcessed = 0
	
	declare @result int
	declare @message varchar(255)
	declare @ErrorType varchar(50)
	
	declare @Job int
	declare @Analysis_Tool varchar(64)
	declare @numLoaded int
	declare @jobprocessed int
	
	declare @NextProcessStateToUse int

	declare @count int
	set @count = 0

	declare @clientStoragePerspective tinyint
	set @clientStoragePerspective  = 1

	-----------------------------------------------
	-- get next available analysis 
	-----------------------------------------------
	-- 
	set @job = 0
	set @Analysis_Tool = ''
	--
	SELECT TOP 1 @Job = Job, @Analysis_Tool = Analysis_Tool
	FROM dbo.T_Analysis_Description
	WHERE 
		(Process_State = @ProcessStateMatch)
		AND (ResultType IN ('Peptide_Hit', 'SIC'))
	ORDER BY Job ASC
	--
	set @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'failure to fetch first analysis'
		goto Done
	end

	-----------------------------------------------
	-- verify that we got a job, and bail out with
	-- an appropriate message if not
	-----------------------------------------------
	--
	if @Job = 0
	begin
		set @message = 'no analyses were available'
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
	begin --<loop>

		If (@Analysis_Tool = 'Sequest' OR @Analysis_Tool = 'AgilentSequest')
		 Begin
			Set @NextProcessStateToUse = @NextProcessState
			exec @result = LoadSequestPeptidesForOneAnalysis
						@NextProcessStateToUse,
						@Job, 
						@message out,
						@numLoaded out,
						@clientStoragePerspective
		
			Set @jobprocessed = 1
		 End
		Else
		 If (@Analysis_Tool = 'MASIC_Finnigan' OR @Analysis_Tool = 'MASIC_Agilent')
		  Begin
			Set @NextProcessStateToUse = 75
			exec @result = LoadMASICResultsForOneAnalysis
							@NextProcessStateToUse,
							@Job, 
							@message out,
							@numLoaded out,
							@clientStoragePerspective
			
			set @jobProcessed = 1
		  End
		 Else
		  Begin
			set @message = 'Unknown analysis tool ''' + @Analysis_Tool + ''' for Job ' + Convert(varchar(11), @Job)
			execute PostLogEntry 'Error', @message, 'LoadResultsForAvailableAnalyses'
			set @message = ''
			--
			-- Reset the state for this job to 3, since peptide loading failed
			Exec SetProcessState @Job, 3
			
			Set @jobProcessed = 0
		  End		
		
		if @jobprocessed = 1
		Begin
			-- make log entry
			--
			if @result = 0
				execute PostLogEntry 'Normal', @message, 'LoadResultsForAvailableAnalyses'
			else
			begin
				-- Note that error codes 60002 and 60004 are defined in SP LoadSequestPeptidesForOneAnalysis; do not change
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

			-- bump running count of peptides loaded
			--
			set @count = @count + @numLoaded
			
			-- check number of jobs processed
			--
			set @numJobsProcessed = @numJobsProcessed + 1
			if @numJobsProcessed >= @numJobsToProcess goto Done
		End
		
		-- get next available analysis
		--
		set @job = 0
		--
		SELECT TOP 1 @Job = Job, @Analysis_Tool = Analysis_Tool
		FROM dbo.T_Analysis_Description
		WHERE 
			(Process_State = @ProcessStateMatch)
			AND (ResultType IN ('Peptide_Hit', 'SIC'))
		ORDER BY Job ASC
		--
		set @myError = @@error
		--
		if @myError <> 0
		begin
			set @message = 'failure to fetch next analysis'
			goto Done
		end

	end --<loop>

	-----------------------------------------------
	-- exit the stored procedure
	-----------------------------------------------
	-- 
Done:

	-- Post a log entry if an error exists
	if @myError <> 0
		execute PostLogEntry 'Error', @message, 'LoadResultsForAvailableAnalyses'

	return @myError



GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

