/****** Object:  StoredProcedure [dbo].[RequestMultiAlignTask] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.RequestMultiAlignTask
/****************************************************
**
**	Desc: 
**		Looks for a task in T_MultiAlign_Task with a
**      Processing_State value = 1
**      If found, task is assigned to caller, 
**      @TaskAvailable is set to 1, and the task 
**      information is returned in the output arguments
**      If not found or error, then @message will contain
**      explanatory text.
**
**	Auth:	mem
**	Date:	01/03/2008 mem
**			01/10/2008 mem - No longer including the DB_Name in the final output folder name since that can lead to path lengths over 255 characters when the .Ini file is copied over
**    
*****************************************************/
(
	@processorName varchar(128),
	@priorityMin tinyint = 1,					-- only tasks with a priority >= to this value will get returned
	@priorityMax tinyint = 10,					-- only tasks with a priority <= to this value will get returned
	@taskID int=0 output,
	@taskPriority tinyint=0 output,				-- the actual priority of the task
	@analysisJobList varchar(8000)='' output,
	@mtdbName varchar(128)='' output,
	@MinimumHighNormalizedScore real=0 output,
	@MinimumHighDiscriminantScore real=0 output,
	@MinimumPeptideProphetProbability real=0 output,
	@MinimumPMTQualityScore real=0 output,
	@ExperimentFilter varchar(64)='' output,
	@ExperimentExclusionFilter varchar(64)='' output,
	@LimitToPMTsFromDataset tinyint = 0 output,
	@InternalStdExplicit varchar(255) = '' output,
	@NETValueType tinyint=0 output,
	@paramFilePath varchar(255)='' output,
	@outputFolderPath varchar(255)='' output,
	@logFilePath varchar(255)='' output,
	@taskAvailable tinyint=0 output,
	@message varchar(512)='' output,
	@infoOnly tinyint=0						-- Set to 1 to preview the next MultiAlign task that would be assigned
)
As
	set nocount on

	Declare @ParamFileName varchar(255)
	set @ParamFileName = ''
	
	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0
	
	declare @JobMin int
	declare @JobMax int
	
	set @message = ''
		
	---------------------------------------------------
	-- clear the output arguments
	---------------------------------------------------
	set @taskID = 0
	set @analysisJobList = ''
	set @mtdbName = db_name()
	set @MinimumHighNormalizedScore = 0
	set @MinimumHighDiscriminantScore = 0
	set @MinimumPeptideProphetProbability = 0
	set @MinimumPMTQualityScore = 0
	set @ExperimentFilter = ''
	set @ExperimentExclusionFilter = ''
	set @LimitToPMTsFromDataset = 0
	set @InternalStdExplicit = ''
	set @NETValueType = 0
	
	set @paramFilePath = ''
	set @outputFolderPath = ''
	set @logFilePath = ''
	set @TaskAvailable = 0
	set @message = ''

	set @infoOnly = IsNull(@infoOnly, 0)
	
	---------------------------------------------------
	-- Do not assign a task if any jobs in T_Analysis_Description have a state of 1
	---------------------------------------------------
	
	SELECT @myRowCount = count(*)
	FROM T_Analysis_Description
	WHERE State = 1
	--
	set @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Error trying to check for new jobs in T_Analysis_Description'
		goto done
	end

	-- bail if there are any new jobs
	--
	if @myRowCount > 0
	begin
		set @message = 'New jobs present in T_Analysis_Description; no task assigned'
		goto done
	end

	---------------------------------------------------
	-- temporary table to hold candidate requests
	---------------------------------------------------

	CREATE TABLE #XPD (
		Task_ID  int
	) 

	---------------------------------------------------
	-- populate temporary table with a small pool of 
	-- available MultiAlign tasks
	---------------------------------------------------

	INSERT INTO #XPD (Task_ID)
	SELECT TOP 5 Task_ID
	FROM T_MultiAlign_Task
	WHERE	Processing_State = 1
			AND Priority >= @PriorityMin
			AND Priority <= @PriorityMax
			AND Len(LTrim(RTrim(Param_File_Name))) > 0
			AND Job_Count > 0
	ORDER BY Priority, Task_ID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Could not load temporary table #XPD'
		goto done
	end
	
	---------------------------------------------------
	-- bail if no candidates identified
	---------------------------------------------------
	
	if @myRowCount = 0
	begin
		set @message = 'No candidate tasks found'
		goto done
	end


	---------------------------------------------------
	-- get root paths to folders
	---------------------------------------------------

	declare @parRootPathClient varchar(255)
	declare @parRootPathServer varchar(255)

	SELECT
		@parRootPathClient = Client_Path, 
		@parRootPathServer = Server_Path
	FROM MT_Main.dbo.V_Folder_Paths
	WHERE ([Function] = 'MultiAlign Results')
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Could not get root path for MultiAlign Results'
		goto done
	end


	declare @ParamRootPathClient varchar(255)
	declare @ParamRootPathServer varchar(255)

	SELECT     
		@ParamRootPathClient = Client_Path, 
		@ParamRootPathServer = Server_Path
	FROM MT_Main.dbo.V_Folder_Paths
	WHERE ([Function] = 'MultiAlign Parameters')
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 OR @myRowCount = 0
	begin
		set @message = 'Could not get root path for MultiAlign Parameters'
		goto done
	end

	---------------------------------------------------
	-- initialize paths with root path parts
	---------------------------------------------------

	set @outputFolderPath = @parRootPathClient
	set @paramFilePath = @ParamRootPathClient

	---------------------------------------------------
	-- Start transaction
	---------------------------------------------------
	--
	declare @transName varchar(32)
	set @transName = 'RequestMultiAlignTask'
	begin transaction @transName
	
	---------------------------------------------------
	-- find a task matching the input request
	-- only grab the taskID at this time
	---------------------------------------------------

	SELECT TOP 1 
		@taskID = MaT.Task_ID
	FROM T_MultiAlign_Task MaT WITH (HoldLock)
		 INNER JOIN #XPD ON #XPD.Task_ID = MaT.Task_ID 
	WHERE MaT.Processing_State = 1
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		rollback transaction @transName
		set @message = 'Error trying to find viable record'
		goto done
	end
	
	---------------------------------------------------
	-- bail if no task found
	---------------------------------------------------

	if @myRowCount = 0
	begin
		rollback transaction @transName
		set @message = 'Could not find viable record'
		goto done
	end

	---------------------------------------------------
	-- Populate @analysisJobList
	---------------------------------------------------
	
	Set @analysisJobList = Null
	
	SELECT @analysisJobList = COALESCE(@analysisJobList + ',', '') + Convert(varchar(12), Job)
	FROM T_MultiAlign_Task_Jobs
	WHERE Task_ID = @taskID
	ORDER BY Job
	
	If Len(IsNull(@analysisJobList, '')) = 0
	Begin
		-- No Jobs Defined
		Set @analysisJobList = ''
		
		set @myError = 113
		set @message = 'Jobs not defined in T_MultiAlign_Task_Jobs for Task_ID ' + Convert(varchar(12), @taskID) + '; unable to continue'

		if @infoOnly = 0
		Begin
			-- Set the task to state 4=Failed so it isn't repeatedly chosen as a candidate
			UPDATE T_MultiAlign_Task
			SET Processing_State = 4, 
				Task_Start = GETDATE()
			WHERE (Task_ID = @taskID)
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			Execute PostLogEntry 'Error', @message, 'RequestMultiAlignTask'
		End
		
		commit transaction @transName		
		
		goto done
	End


	---------------------------------------------------
	-- Determine the minimum and maximum job numbers in T_MultiAlign_Task_Jobs
	---------------------------------------------------

	SELECT @JobMin = MIN(Job), 
		   @JobMax = MAX(Job)
	FROM T_MultiAlign_Task_Jobs
	WHERE Task_ID = @taskID
	GROUP BY Task_ID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	Set @JobMin = IsNull(@JobMin, 0)
	Set @JobMax = IsNull(@JobMax, 0)
	
	If @infoOnly = 0
	Begin
		---------------------------------------------------
		-- set state and path for task
		---------------------------------------------------

		UPDATE T_MultiAlign_Task
		SET 
			Processing_State = 2, 
			Task_Start = GETDATE(),
			Task_AssignedProcessorName = @ProcessorName
		WHERE (Task_ID = @taskID)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0
		begin
			rollback transaction @transName
			set @message = 'Update operation failed'
			goto done
		end	
	End

	---------------------------------------------------
	-- commit transaction
	---------------------------------------------------
	commit transaction @transName

	---------------------------------------------------
	-- generate folder and file names and set paths
	---------------------------------------------------

	Declare @OutputFolderPrefix varchar(256)
	Declare @Instrument varchar(256)
	
	Declare @CharLoc int
	Declare @StartPos int
	
	Set @Instrument = 'Unknown'
	SELECT	TOP 1 @Instrument = FAD.Instrument
	FROM	T_MultiAlign_Task MaT INNER JOIN
			T_MultiAlign_Task_Jobs MTJ on MaT.Task_ID = MTJ.Task_ID LEFT OUTER JOIN
			T_FTICR_Analysis_Description FAD ON 
			MTJ.Job = FAD.Job
	WHERE (MaT.Task_ID = @taskID)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 OR @myRowCount = 0
	begin
		set @myError = 111
		set @message = 'Could not get Storage_Path'
		goto done
	end

	If Len(@Instrument) > 0
		Set @OutputFolderPrefix = @Instrument
	
	If Len(IsNull(@OutputFolderPrefix, '')) = 0
		Set @OutputFolderPrefix = 'Unknown'
		
	-- Truncate @OutputFolderPrefix following the _ (if present)
	-- If @OutputFolderPrefix contains LTQ_FT or LTQ_Orb, then skip the first underscore
	Set @StartPos = CharIndex('LTQ_FT', Upper(@OutputFolderPrefix))
	If @StartPos >= 1
		Set @StartPos = @StartPos + 5
	Else
	Begin
		Set @StartPos = CharIndex('LTQ_ORB', Upper(@OutputFolderPrefix))
		If @StartPos >= 1
			Set @StartPos = @StartPos + 5
		Else
			Set @StartPos = 0
	End
		
	Set @CharLoc = CharIndex('_', @OutputFolderPrefix, @StartPos)
	If @CharLoc > 2
		Set @OutputFolderPrefix = SubString(@OutputFolderPrefix, 1, @CharLoc-1)
	
	-- Construct the Output Folder Name
	declare @Output_Folder_Name varchar(255)
	set @Output_Folder_Name = 'MA_' + convert(varchar(12), @taskID)
	
	If @JobMin = @JobMax
		set @Output_Folder_Name = @Output_Folder_Name + '_Job' + convert(varchar(12), @JobMin)
	Else
		set @Output_Folder_Name = @Output_Folder_Name + '_Jobs' + convert(varchar(12), @JobMin) + '-' + convert(varchar(12), @JobMax)

	set @Output_Folder_Name = dbo.udfCombinePaths(@OutputFolderPrefix, @Output_Folder_Name)

	set @outputFolderPath = dbo.udfCombinePaths(dbo.udfCombinePaths(@outputFolderPath, DB_Name()), @Output_Folder_Name)


	---------------------------------------------------
	-- Update Output_Folder_Name if @infoOnly = 0
	---------------------------------------------------

	If @infoOnly = 0
	Begin
		UPDATE T_MultiAlign_Task
		SET Output_Folder_Name = @Output_Folder_Name
		WHERE (Task_ID = @taskID)
	End
	
	---------------------------------------------------
	-- get task parameters
	---------------------------------------------------
	
	SELECT
		@MinimumHighNormalizedScore = Minimum_High_Normalized_Score,
		@MinimumHighDiscriminantScore = Minimum_High_Discriminant_Score,
		@MinimumPeptideProphetProbability = Minimum_Peptide_Prophet_Probability,
		@MinimumPMTQualityScore = Minimum_PMT_Quality_Score,
		@ExperimentFilter = Experiment_Filter,
		@ExperimentExclusionFilter = Experiment_Exclusion_Filter,
		@LimitToPMTsFromDataset = Limit_To_PMTs_From_Dataset,
		@InternalStdExplicit = Internal_Std_Explicit,
		@NetValueType = NET_Value_Type,
 		@ParamFileName = LTrim(RTrim(Param_File_Name)), 
		@taskPriority = Priority
	FROM T_MultiAlign_Task
	WHERE (Task_ID = @taskID)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @myError = 112
		set @message = 'Could not get task parameters'
		goto done
	end
	
	-- Check for @ParamFileName containing a UNC path
	-- If it does not contain a UNC path, prepend @ParamFileName with @paramFilePath
	If Len(@ParamFileName) > 2
	Begin
		If SubString(@ParamFileName, 1, 2) = '\\'
			Set @paramFilePath = @ParamFileName
		Else
			Set @paramFilePath = dbo.udfCombinePaths(@paramFilePath, @ParamFileName)
	End
	
	---------------------------------------------------
	-- Define the log file path
	---------------------------------------------------

	set @logFilePath = dbo.udfCombinePaths(@outputFolderPath, 'MultiAlign_Task_' + convert(varchar(12), @taskID) + '_log.txt')

	---------------------------------------------------
	-- If we get to this point, then all went fine
	-- Update @TaskAvailable
	---------------------------------------------------
	Set @TaskAvailable = 1
	
	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:

	If @infoOnly <> 0
	Begin
		-- Display the status message and task parameters (if a task is available)
		
		If @myError <> 0
			SELECT @Message AS Message, @myError AS ErrorCode
		Else
		Begin
			If @taskAvailable = 0
				SELECT @Message AS Message
			Else
			Begin
				If Len(@Message) = 0
					Set @Message = 'Task found'
					
				SELECT 
					@Message AS Message, 
					@taskID AS TaskID,
					@taskPriority AS TaskPriority,
					@analysisJobList AS Job_List,
					@mtdbName AS Database_Name,
					@MinimumHighNormalizedScore AS Minimum_High_Normalized_Score,
					@MinimumHighDiscriminantScore AS Minimum_High_Discriminant_Score,
					@MinimumPeptideProphetProbability AS Minimum_Peptide_Prophet_Probability,
					@MinimumPMTQualityScore AS Minimum_PMT_Quality_Score,
					@ExperimentFilter AS Experiment_Filter,
					@ExperimentExclusionFilter AS Experiment_Exclusion_Filter,
					@LimitToPMTsFromDataset AS Limit_To_PMTs_From_Dataset,
					@InternalStdExplicit AS Internal_Std_Explicit,
					@NETValueType AS NET_Value_Type,
					@paramFilePath AS Param_File_Path,
					@outputFolderPath AS Output_Folder_Path,
					@logFilePath AS Log_File_Path
				End
			End
	
	End

	return @myError


GO
GRANT EXECUTE ON [dbo].[RequestMultiAlignTask] TO [DMS_SP_User]
GO
GRANT VIEW DEFINITION ON [dbo].[RequestMultiAlignTask] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[RequestMultiAlignTask] TO [MTS_DB_Lite]
GO
GRANT EXECUTE ON [dbo].[RequestMultiAlignTask] TO [pnl\MTSProc]
GO
