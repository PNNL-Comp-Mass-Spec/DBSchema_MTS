SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[CheckAllFiltersForAvailableAnalyses]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[CheckAllFiltersForAvailableAnalyses]
GO


CREATE PROCEDURE dbo.CheckAllFiltersForAvailableAnalyses
/****************************************************
**
**	Desc: 
**		Checks all the peptides for the all the 
**		available analyses against the all the 
**		cleavage filters
**
**	Return values: 0:  success, otherwise, error code
**
**	Parameters:
**
**		Auth: grk
**		Date: 11/02/2001
**			  08/07/2004 mem - added @ProcessStateMatch, @NextProcessState, @numJobsToProcess, and @numJobsProcessed parameters
**			  08/24/2004 mem - Switched to using T_Process_Config instead of T_Filter_List
**			  11/24/2004 mem - Updated call to CheckFilterForAvailableAnalysesBulk to no longer pass @NextProcessState
**							   Moved updating of Process_State from CheckFilterForAvailableAnalysesBulk to this SP
**			  03/07/2005 mem - Updated to reflect changes to T_Process_Config that now use just one column to identify a configuration setting type
**			  11/26/2005 mem - Added parameter @ProcessStateFilterEvaluationRequired and passing this parameter to 
**							 - Now calling CheckFilterForAvailableAnalysesBulk for jobs in state @ProcessStateFilterEvaluationRequired
**    
*****************************************************/
	@ProcessStateMatch int = 60,
	@ProcessStateFilterEvaluationRequired int = 65,
	@NextProcessState int = 70,
	@numJobsToProcess int = 50000,
	@numJobsProcessed int = 0 OUTPUT
As
	set nocount on

	Declare @myError int,
			@myRowCount int

	set @myError = 0
	set @myRowCount = 0

	declare @message varchar(255)
	declare @count int
	
	declare @filterSetID int
	declare @filterCountTotal int
	
	-----------------------------------------------------------
	-- temporary table for filters to check
	-----------------------------------------------------------
	-- create it
	--
	CREATE TABLE #FilterSets (
		Filter_ID int
	)
	-- populate it
	--
	INSERT INTO #FilterSets
	   (Filter_ID)
	SELECT Convert(int, Value)
	FROM T_Process_Config
	WHERE [Name] = 'MTDB_Export_Filter_ID'
	--
	SELECT @myError = @@error, @myRowCount = @@RowCount
	--
	if @myError <> 0
	begin
		set @message = 'Error populating #FilterSets temporary table'
		set @myError = 51
		goto Done
	end

	set @filterCountTotal = @myRowCount

	-----------------------------------------------------------
	-- loop through each filter and check all analyses against the filter
	-----------------------------------------------------------
	set @filterSetID = 1
	while @filterSetID <> 0
	begin
		set @filterSetID = 0
		set @count = 0
		-- get next filter
		--
		SELECT TOP 1 @filterSetID = Filter_ID 
		FROM #FilterSets
		
		if @filterSetID <> 0
		begin
			-- process analyses in state @ProcessStateMatch for this filter
			--
			exec @myError = CheckFilterForAvailableAnalysesBulk
									@filterSetID, 
									0,						-- @ReprocessAllJobs: 0=Do not reprocess all jobs
									@ProcessStateMatch, 
									@ProcessStateFilterEvaluationRequired,
									@numJobsToProcess,		-- Maximum number of jobs to process
									@count OUTPUT			-- Number of jobs processed

			if @myError <> 0
			begin
				set @message = 'Error calling CheckFilterForAvailableAnalysesBulk: ' + convert(varchar(11), @myError)
				set @myError = 52
				Goto done
			end
			
			-- Update maximum number of jobs processed by CheckFilterForAvailableAnalysesBulk
			If @count > @numJobsProcessed
				Set @numJobsProcessed = @count


			-- process analyses in state @ProcessStateFilterEvaluationRequired for this filter
			--
			exec @myError = CheckFilterForAvailableAnalysesBulk
									@filterSetID, 
									0,						-- @ReprocessAllJobs: 0=Do not reprocess all jobs
									@ProcessStateFilterEvaluationRequired, 
									@ProcessStateFilterEvaluationRequired,
									@numJobsToProcess,		-- Maximum number of jobs to process
									@count OUTPUT			-- Number of jobs processed

			if @myError <> 0
			begin
				set @message = 'Error calling CheckFilterForAvailableAnalysesBulk: ' + convert(varchar(11), @myError)
				set @myError = 52
				Goto done
			end


			-- get rid of entry just processed
			--
			DELETE FROM #FilterSets
			WHERE Filter_ID = @filterSetID
			
		end
	end


	-- Update the Process_State value
	-- Note that Last_Affected is not updated here since CheckFilterForAvailableAnalysesBulk updates it
	UPDATE T_Analysis_Description
	SET Process_State = @NextProcessState
	WHERE (Process_State = @ProcessStateMatch OR Process_State = 65) AND 
	      Job IN (	SELECT TAD.Job
					FROM T_Analysis_Description AS TAD INNER JOIN
						 T_Analysis_Filter_Flags AS AFF ON TAD.Job = AFF.Job
					GROUP BY TAD.Job
					HAVING COUNT(AFF.Filter_ID) >= @filterCountTotal
				 )	
	--
	SELECT @myError = @@error, @myRowCount = @@RowCount



	-----------------------------------------------
	-- exit the stored procedure
	-----------------------------------------------
	-- 
Done:

	-- Post a log entry if an error exists
	if @myError <> 0
		execute PostLogEntry 'Error', @message, 'CheckAllFiltersForAvailableAnalyses'

	return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

