/****** Object:  StoredProcedure [dbo].[CheckAllFiltersForAvailableAnalyses] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE Procedure CheckAllFiltersForAvailableAnalyses
/****************************************************
**
**	Desc:	Compare the peptides for each of the available analyses 
**			against all of the defined filter sets
**
**	Return values: 0:  success, otherwise, error code
**
**	Parameters:
**
**	Auth: 	grk
**	Date:	11/02/2001
**			08/07/2004 mem - added @ProcessStateMatch, @NextProcessState, @numJobsToProcess, and @numJobsProcessed parameters
**			08/24/2004 mem - Switched to using T_Process_Config instead of T_Filter_List
**			11/24/2004 mem - Updated call to CheckFilterForAvailableAnalysesBulk to no longer pass @NextProcessState
**							 Moved updating of Process_State from CheckFilterForAvailableAnalysesBulk to this SP
**			03/07/2005 mem - Updated to reflect changes to T_Process_Config that now use just one column to identify a configuration setting type
**			11/26/2005 mem - Added parameter @ProcessStateFilterEvaluationRequired and passing this parameter to 
**						   - Now calling CheckFilterForAvailableAnalysesBulk for jobs in state @ProcessStateFilterEvaluationRequired
**			03/11/2006 mem - Now calling VerifyUpdateEnabled
**			07/04/2006 mem - Added parameter @ProcessStateAllStepsComplete
**			09/17/2011 mem - Now checking T_Process_Config for entries of type MTDB_Export_Custom_Filter_ID_and_Table; these should have @filterSetID < 100
**    
*****************************************************/
(
	@ProcessStateMatch int = 60,
	@ProcessStateFilterEvaluationRequired int = 65,
	@NextProcessState int = 70,
	@ProcessStateAllStepsComplete int = 70,
	@numJobsToProcess int = 50000,
	@numJobsProcessed int = 0 OUTPUT
)
As
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @UpdateEnabled tinyint
	declare @message varchar(255)
	declare @count int
	
	declare @filterSetID int
	declare @CustomFilterTableName varchar(128)
	declare @filterCountTotal int
	
	-----------------------------------------------------------
	-- Create temporary table for filters to check
	-----------------------------------------------------------

	CREATE TABLE #FilterSets (
		Filter_ID int,
		Custom_Filter_Table_Name varchar(128) NULL
	)

	-----------------------------------------------------------
	-- Populate #FilterSets using 'MTDB_Export_Filter_ID' entries
	-----------------------------------------------------------
	--
	INSERT INTO #FilterSets (Filter_ID, Custom_Filter_Table_Name)
	SELECT Convert(int, Value), ''
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
	-- Populate #FilterSets using 'MTDB_Export_Custom_Filter_ID_and_Table' entries
	-----------------------------------------------------------
	--
	CREATE TABLE #TmpConfigDefs (
		Value1 varchar(512) NOT NULL,
		Value2 varchar(512) NOT NULL,
	)

	declare @CustomFilterMatchCount int = 0

	exec ParseConfigListDualKey 'MTDB_Export_Custom_Filter_ID_and_Table', @CustomFilterMatchCount output

	If @CustomFilterMatchCount > 0
	Begin

		IF Exists (SELECT * FROM #TmpConfigDefs WHERE ISNUMERIC(Value1) <> 1)
		Begin
			set @message = 'Invalid entry for "MTDB_Export_Custom_Filter_ID_and_Table" found in T_Process_Config; should look something like "10, T_Custom_Peptide_Filter_Criteria"'
			Set @myError = 53
			Goto Done
		End
		
		INSERT INTO #FilterSets (Filter_ID, Custom_Filter_Table_Name)
		SELECT CONVERT(int, Value1), Value2
		FROM #TmpConfigDefs
		WHERE ISNUMERIC(Value1) = 1
		--
		SELECT @myError = @@error, @myRowCount = @@RowCount
		--
		if @myError <> 0
		begin
			set @message = 'Error populating #FilterSets temporary table using #TmpConfigDefs'
			set @myError = 52
			goto Done
		end

		set @filterCountTotal = @filterCountTotal + @myRowCount

	End
	
	-----------------------------------------------------------
	-- loop through each filter and check all analyses against the filter
	-----------------------------------------------------------
	set @filterSetID = 1
	while @filterSetID <> 0
	begin -- <a>
		-- get next filter
		--
		set @filterSetID = 0
		set @count = 0
		SELECT TOP 1 @filterSetID = Filter_ID,
		             @CustomFilterTableName = Custom_Filter_Table_Name
		FROM #FilterSets
		
		if @filterSetID <> 0
		begin -- <b>
			-- process analyses in state @ProcessStateMatch for this filter
			--
			exec @myError = CheckFilterForAvailableAnalysesBulk
									@filterSetID, 
									0,						-- @ReprocessAllJobs: 0=Do not reprocess all jobs
									@ProcessStateMatch, 
									@ProcessStateFilterEvaluationRequired,
									@ProcessStateAllStepsComplete,
									@numJobsToProcess,		-- Maximum number of jobs to process
									@CustomFilterTableName,
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
									@ProcessStateFilterEvaluationRequired,		-- @ProcessStateMatch
									@ProcessStateFilterEvaluationRequired,
									@ProcessStateAllStepsComplete,
									@numJobsToProcess,		-- Maximum number of jobs to process
									@CustomFilterTableName,
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
			
		end -- </b>

		-- Validate that updating is enabled, abort if not enabled
		exec VerifyUpdateEnabled @CallingFunctionDescription = 'CheckAllFiltersForAvailableAnalyses', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
		If @UpdateEnabled = 0
			Goto Done

	end -- </a>


	-- Update the Process_State value
	-- Note that Last_Affected is not updated here since CheckFilterForAvailableAnalysesBulk updates it
	UPDATE T_Analysis_Description
	SET Process_State = @NextProcessState
	WHERE (Process_State = @ProcessStateMatch OR Process_State = @ProcessStateFilterEvaluationRequired) AND 
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
GRANT VIEW DEFINITION ON [dbo].[CheckAllFiltersForAvailableAnalyses] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[CheckAllFiltersForAvailableAnalyses] TO [MTS_DB_Lite] AS [dbo]
GO
