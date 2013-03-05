/****** Object:  StoredProcedure [dbo].[CheckAllFiltersForAvailableAnalyses] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.CheckAllFiltersForAvailableAnalyses
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
**			12/05/2012 mem - Added support for MTDB_Export_Filter_ID_by_Experiment
**    
*****************************************************/
(
	@ProcessStateMatch int = 60,
	@ProcessStateFilterEvaluationRequired int = 65,
	@NextProcessState int = 70,
	@ProcessStateAllStepsComplete int = 70,
	@numJobsToProcess int = 50000,
	@numJobsProcessed int = 0 OUTPUT,
	@infoOnly tinyint = 0
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
	Declare @ExperimentFilter varchar(128)
	
	Declare @continue tinyint
	Declare @EntryID int

	-----------------------------------------------------------
	-- Validate the inputs
	-----------------------------------------------------------
	--
	Set @ProcessStateMatch = IsNull(@ProcessStateMatch, 60)
	Set @ProcessStateFilterEvaluationRequired = IsNull(@ProcessStateFilterEvaluationRequired, 65)
	Set @NextProcessState = IsNull(@NextProcessState, 70)
	Set @ProcessStateAllStepsComplete = IsNull(@ProcessStateAllStepsComplete, 70)
	Set @numJobsToProcess = IsNull(@numJobsToProcess, 50000)
	Set @numJobsProcessed = 0
	Set @infoOnly = IsNull(@infoOnly, 0)
	
	-----------------------------------------------------------
	-- Create a temporary table to keep track of the FilterSetIDs that apply to each job
	-----------------------------------------------------------

	CREATE TABLE #Tmp_Job_Applicable_FilterSetIDs (
		Job int NOT NULL,
		Filter_Set_ID int NOT NULL,
		Evaluated tinyint NOT NULL
	)

	CREATE UNIQUE CLUSTERED INDEX #IX_Tmp_Job_Applicable_FilterSetIDs ON #Tmp_Job_Applicable_FilterSetIDs (Job, Filter_Set_ID)

	-----------------------------------------------------------
	-- Create a temporary table for filters to check
	-----------------------------------------------------------

	CREATE TABLE #FilterSets (
		Entry_ID int identity(1,1),
		Filter_Set_ID int,
		Custom_Filter_Table_Name varchar(128) NOT NULL,
		Experiment_Filter varchar(128) NOT NULL
	)

	-----------------------------------------------------------
	-- Populate #FilterSets using 'MTDB_Export_Filter_ID' entries
	-----------------------------------------------------------
	--
	INSERT INTO #FilterSets (Filter_Set_ID, Custom_Filter_Table_Name, Experiment_Filter)
	SELECT Convert(int, Value), '', ''
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

	-----------------------------------------------------------
	-- Populate #FilterSets using 'MTDB_Export_Custom_Filter_ID_and_Table' entries
	-----------------------------------------------------------
	--
	CREATE TABLE #TmpConfigDefs (
		Value1 varchar(512) NOT NULL,
		Value2 varchar(512) NOT NULL,
	)

	declare @ConfigListMatchCount int = 0

	exec ParseConfigListDualKey 'MTDB_Export_Custom_Filter_ID_and_Table', @ConfigListMatchCount output

	If @ConfigListMatchCount > 0
	Begin

		IF Exists (SELECT * FROM #TmpConfigDefs WHERE ISNUMERIC(Value1) <> 1)
		Begin
			set @message = 'Invalid entry for "MTDB_Export_Custom_Filter_ID_and_Table" found in T_Process_Config; should look something like "10, T_Custom_Peptide_Filter_Criteria"'
			Set @myError = 53
			Goto Done
		End
		
		INSERT INTO #FilterSets (Filter_Set_ID, Custom_Filter_Table_Name, Experiment_Filter)
		SELECT CONVERT(int, Value1), Value2, ''
		FROM #TmpConfigDefs
		WHERE ISNUMERIC(Value1) = 1 And IsNull(Value2, '') <> ''
		--
		SELECT @myError = @@error, @myRowCount = @@RowCount
		--
		if @myError <> 0
		begin
			set @message = 'Error populating #FilterSets temporary table using #TmpConfigDefs for MTDB_Export_Custom_Filter_ID_and_Table'
			set @myError = 52
			goto Done
		end

	End
	
	-----------------------------------------------------------
	-- Populate #FilterSets using 'MTDB_Export_Filter_ID_by_Experiment' entries
	-----------------------------------------------------------
	--
	Truncate table #TmpConfigDefs

	exec ParseConfigListDualKey 'MTDB_Export_Filter_ID_by_Experiment', @ConfigListMatchCount output

	If @ConfigListMatchCount > 0
	Begin

		IF Exists (SELECT * FROM #TmpConfigDefs WHERE ISNUMERIC(Value1) <> 1)
		Begin
			set @message = 'Invalid entry for "MTDB_Export_Filter_ID_by_Experiment" found in T_Process_Config; should look something like "117, Experiment_Filter_Spec"'
			Set @myError = 54
			Goto Done
		End
		
		INSERT INTO #FilterSets (Filter_Set_ID, Custom_Filter_Table_Name, Experiment_Filter)
		SELECT CONVERT(int, Value1), '', Value2
		FROM #TmpConfigDefs
		WHERE ISNUMERIC(Value1) = 1 And IsNull(Value2, '') <> ''
		--
		SELECT @myError = @@error, @myRowCount = @@RowCount
		--
		if @myError <> 0
		begin
			set @message = 'Error populating #FilterSets temporary table using #TmpConfigDefs for MTDB_Export_Filter_ID_by_Experiment'
			set @myError = 55
			goto Done
		end

	End
	
	-----------------------------------------------------------
	-- Populate #Tmp_Job_Applicable_FilterSetIDs
	-- Ignore Filter_IDs below 100 since those can have custom experiment and parameter file filters
	-----------------------------------------------------------
	--
	Set @continue = 1
	Set @EntryID = 0
	--
	While @continue = 1
	Begin -- <a1>
		-- Get next filter
		--
		SELECT TOP 1 @EntryID = Entry_ID,
		             @filterSetID = Filter_Set_ID,
		             @ExperimentFilter = Experiment_Filter		             
		FROM #FilterSets
		Where Entry_ID > @EntryID And Filter_Set_ID >= 100
		ORDER BY Entry_ID
		--
		SELECT @myError = @@error, @myRowCount = @@RowCount

		If @myRowCount = 0
			Set @continue = 0
		Else
		Begin
			-- Append the matching jobs to #Tmp_Job_Applicable_FilterSetIDs
			-- Using the Left Outer Join to avoid duplicate entries
			
			INSERT INTO #Tmp_Job_Applicable_FilterSetIDs (Job, Filter_Set_ID, Evaluated)
			SELECT JobsQ.Job, JobsQ.Filter_Set_ID, 0 AS Evaluated
			FROM ( SELECT TAD.Job, @filterSetID AS Filter_Set_ID
			       FROM T_Analysis_Description TAD INNER JOIN
			            dbo.tblPeptideHitResultTypes() RTL ON TAD.ResultType = RTL.ResultType			       
			       WHERE @ExperimentFilter = '' OR
			             (TAD.Experiment LIKE @ExperimentFilter) 
			     ) JobsQ
			     LEFT OUTER JOIN #Tmp_Job_Applicable_FilterSetIDs JAF
			       ON JobsQ.Job = JAF.Job AND
			          JobsQ.Filter_Set_ID = JAF.Filter_Set_ID
			WHERE JAF.Job IS NULL
			--
			SELECT @myError = @@error, @myRowCount = @@RowCount
			
		End
		
	End-- </a1>
	
	If @infoOnly <> 0
		SELECT *
		FROM #FilterSets
		ORDER BY Entry_ID
		
	-----------------------------------------------------------
	-- Loop through each filter and check the appropriate jobs against the filter
	-----------------------------------------------------------
	--
	Set @continue = 1
	Set @EntryID = 0
	--	
	While @continue = 1
	Begin -- <a2>
		-- get next filter
		--
		SELECT TOP 1 @EntryID = Entry_ID,
		             @filterSetID = Filter_Set_ID,
		             @CustomFilterTableName = Custom_Filter_Table_Name,
		             @ExperimentFilter = Experiment_Filter		             
		FROM #FilterSets
		Where Entry_ID > @EntryID
		ORDER BY Entry_ID
		--
		SELECT @myError = @@error, @myRowCount = @@RowCount

		If @myRowCount = 0
			Set @continue = 0
		Else
		Begin -- <b>
			-- process analyses in state @ProcessStateMatch for this filter
			--
			set @count = 0
		
			exec @myError = CheckFilterForAvailableAnalysesBulk
									@filterSetID, 
									0,											-- @ReprocessAllJobs: 0=Do not reprocess all jobs
									@ProcessStateMatch,							-- @ProcessStateMatch
									@ProcessStateFilterEvaluationRequired,
									@ProcessStateAllStepsComplete,
									@numJobsToProcess,							-- Maximum number of jobs to process
									@CustomFilterTableName = @CustomFilterTableName,
									@ExperimentFilter = @ExperimentFilter,
									@numJobsProcessed = @count OUTPUT,			-- Number of jobs processed
									@infoOnly = @infoOnly

			if @myError <> 0
			begin
				set @message = 'Error calling CheckFilterForAvailableAnalysesBulk: ' + convert(varchar(11), @myError)
				set @myError = 56
				Goto done
			end
			
			-- Update maximum number of jobs processed by CheckFilterForAvailableAnalysesBulk
			If @count > @numJobsProcessed
				Set @numJobsProcessed = @count


			-- process analyses in state @ProcessStateFilterEvaluationRequired for this filter
			--
			exec @myError = CheckFilterForAvailableAnalysesBulk
									@filterSetID, 
									0,											-- @ReprocessAllJobs: 0=Do not reprocess all jobs
									@ProcessStateFilterEvaluationRequired,		-- @ProcessStateMatch
									@ProcessStateFilterEvaluationRequired,
									@ProcessStateAllStepsComplete,
									@numJobsToProcess,							-- Maximum number of jobs to process
									@CustomFilterTableName = @CustomFilterTableName,
									@ExperimentFilter = @ExperimentFilter,
									@numJobsProcessed = @count OUTPUT,			-- Number of jobs processed
									@infoOnly = @infoOnly

			if @myError <> 0
			begin
				set @message = 'Error calling CheckFilterForAvailableAnalysesBulk: ' + convert(varchar(11), @myError)
				set @myError = 57
				Goto done
			end
			
		end -- </b>

		-- Validate that updating is enabled, abort if not enabled
		exec VerifyUpdateEnabled @CallingFunctionDescription = 'CheckAllFiltersForAvailableAnalyses', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
		If @UpdateEnabled = 0
			Goto Done

	end -- </a2>


	-----------------------------------------------------------
	-- Update the state for jobs that have had all of their applicable filters evaluated
	-----------------------------------------------------------
	--
	-- First udate #Tmp_Job_Applicable_FilterSetIDs
	--
	UPDATE #Tmp_Job_Applicable_FilterSetIDs
	SET Evaluated = 1
	FROM #Tmp_Job_Applicable_FilterSetIDs JAF
	     INNER JOIN T_Analysis_Filter_Flags AFF
	       ON JAF.Job = AFF.Job AND
	          JAF.Filter_Set_ID = AFF.Filter_ID
	
	If @infoOnly <> 0
	Begin
		-- Preview the jobs that could be updated
		SELECT TAD.Job,
		       TAD.Process_State,
		       FilterCheckStats.Filter_Set_Count,
		       FilterCheckStats.Filter_Set_Count_Evaluated
		FROM T_Analysis_Description TAD
		     INNER JOIN ( SELECT Job,
		                         COUNT(*) AS Filter_Set_Count,
		                         Sum(CASE WHEN Evaluated = 1 THEN 1 ELSE 0 END) AS Filter_Set_Count_Evaluated
		                  FROM #Tmp_Job_Applicable_FilterSetIDs
		                  GROUP BY Job ) AS FilterCheckStats
		       ON FilterCheckStats.Job = TAD.Job
		WHERE (TAD.Process_State IN (@ProcessStateMatch, @ProcessStateFilterEvaluationRequired))
		ORDER BY TAD.Job

	End
	Else
	Begin	
		-- Update the Process_State value
		-- Note that Last_Affected is not updated here since CheckFilterForAvailableAnalysesBulk updates it
		UPDATE T_Analysis_Description
		SET Process_State = @NextProcessState
		WHERE Process_State IN (@ProcessStateMatch, @ProcessStateFilterEvaluationRequired) AND
		      Job IN ( SELECT Job
		               FROM #Tmp_Job_Applicable_FilterSetIDs
		               GROUP BY Job
		               HAVING Min(Evaluated) = 1 )
		--
		SELECT @myError = @@error, @myRowCount = @@RowCount
	End
	
	-----------------------------------------------
	-- exit the stored procedure
	-----------------------------------------------
	-- 
Done:

	-- Post a log entry if an error exists
	if @myError <> 0 And @infoOnly = 0
		execute PostLogEntry 'Error', @message, 'CheckAllFiltersForAvailableAnalyses'

	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[CheckAllFiltersForAvailableAnalyses] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[CheckAllFiltersForAvailableAnalyses] TO [MTS_DB_Lite] AS [dbo]
GO
