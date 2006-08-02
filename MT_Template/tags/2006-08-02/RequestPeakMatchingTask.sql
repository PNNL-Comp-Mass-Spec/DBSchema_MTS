SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[RequestPeakMatchingTask]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[RequestPeakMatchingTask]
GO


CREATE Procedure dbo.RequestPeakMatchingTask
/****************************************************
**
**	Desc: 
**		Looks for a task in T_Peak_Matching_Task with a
**      Processing_State value = 1
**      If found, task is assigned to caller, 
**      @TaskAvailable is set to 1, and the task 
**      information is returned in the output arguments
**      If not found or error, then @message will contain
**      explanatory text.
**
**	Auth:	grk
**	Date:	5/21/2003
**			06/20/2003 mem - 
**			06/23/2003 mem - 
**			07/01/2003 mem - 
**			07/07/2003 mem - 
**			07/22/2003 mem - 
**			10/06/2003 mem - Now checking if Ini_File_Name contains a UNC path (begins with \\)
**			11/26/2003 mem - Assignment logic includes GANET task queue
**			12/29/2003 mem - Added NetValueType parameter and check for existence of T_GANET_Update_Task
**			01/06/2004 mem - Added support for Minimum_PMT_Quality_Score
**			05/20/2004 mem - Added state 7 as a T_GANET_Update_Task.Processing_State value that will prevent a peak matching task from being returned
**			09/20/2004 mem - Updated for new MTDB schema
**			12/31/2004 mem - Updated parsing of @OutputFolderPrefix to keep LTQ_FT intact
**			02/05/2005 mem - Added parameters @MinimumHighDiscriminantScore, @ExperimentFilter, and @ExperimentExclusionFilter and switched from using data type decimal(9,5) to real
**			12/20/2005 mem - Added parameters @LimitToPMTsFromDataset and @InternalStdExplicit
**			01/14/2006 mem - Updated parsing of @OutputFolderPrefix to keep LTQ_Orb intact
**			07/01/2007 mem - Removed check for jobs in T_GANET_Update_Task since NET alignment now occurs in the Peptide DB
**			07/18/2006 mem - Updated to use dbo.udfCombinePaths
**    
*****************************************************/
(
	@processorName varchar(128),
	@clientPerspective tinyint = 1,				-- 0 means running SP from local server; 1 means running SP from client
	@priorityMin tinyint = 1,					-- only tasks with a priority >= to this value will get returned
	@priorityMax tinyint = 10,					-- only tasks with a priority <= to this value will get returned
	@taskID int=0 output,
	@taskPriority tinyint=0 output,				-- the actual priority of the task
	@analysisJob int=0 output,
	@analysisResultsFolderPath varchar(256)='' output,
	@mtdbName varchar(128)='' output,				-- if provided, will preferentially query that mass tag database first
	@confirmedOnly tinyint=0 output,
	@modList varchar(128)='' output,
	@MinimumHighNormalizedScore real=0 output,
	@MinimumHighDiscriminantScore real=0 output,
	@MinimumPMTQualityScore real=0 output,
	@ExperimentFilter varchar(64)='' output,
	@ExperimentExclusionFilter varchar(64)='' output,
	@LimitToPMTsFromDataset tinyint = 0 output,
	@InternalStdExplicit varchar(255) = '' output,
	@NETValueType tinyint=0 output,
	@iniFilePath varchar(255)='' output,
	@outputFolderPath varchar(255)='' output,
	@logFilePath varchar(255)='' output,
	@taskAvailable tinyint=0 output,
	@message varchar(512)='' output
)
As
	set nocount on

	Declare @IniFileName varchar(255)
	set @IniFileName = ''
	
	declare @myError int
	set @myError = 0

	declare @myRowCount int
	set @myRowCount = 0
	
	set @message = ''
		
	---------------------------------------------------
	-- clear the output arguments
	---------------------------------------------------
	set @taskID = 0
	set @analysisJob = 0
	set @analysisResultsFolderPath = ''
	set @mtdbName = db_name()
	set @confirmedOnly = 0
	set @modList = ''
	set @MinimumHighNormalizedScore = 0
	set @MinimumHighDiscriminantScore = 0
	set @MinimumPMTQualityScore = 0
	set @ExperimentFilter = ''
	set @ExperimentExclusionFilter = ''
	set @LimitToPMTsFromDataset = 0
	set @InternalStdExplicit = ''
	set @NETValueType = 0
	
	set @iniFilePath = ''
	set @outputFolderPath = ''
	set @logFilePath = ''
	set @TaskAvailable = 0
	set @message = ''

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

	Create TABLE #XPD (
		ID  int, 
		Job int
	) 

	---------------------------------------------------
	-- populate temporary table with a small pool of 
	-- dataset archive requests for given storage server
	-- Note:  This takes no locks on any tables
	---------------------------------------------------

	INSERT INTO #XPD
	SELECT TOP 5 
		Task_ID as ID, Job
	FROM T_Peak_Matching_Task
	WHERE	Processing_State = 1
			AND Priority >= @PriorityMin
			AND Priority <= @PriorityMax
			AND Len(LTrim(RTrim(Ini_File_Name))) > 0
	ORDER BY Priority, Task_ID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'could not load temporary table'
		goto done
	end
	
	---------------------------------------------------
	-- bail if no candidates identified
	---------------------------------------------------
	
	if @myRowCount = 0
	begin
		set @message = 'no candidate tasks found'
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
	WHERE     ([Function] = 'Peak Matching Results')
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'could not get root path for Peak Matching Parameters'
		goto done
	end


	declare @iniRootPathClient varchar(255)
	declare @iniRootPathServer varchar(255)

	SELECT     
		@iniRootPathClient = Client_Path, 
		@iniRootPathServer = Server_Path
	FROM         MT_Main.dbo.V_Folder_Paths
	WHERE ([Function] = 'Peak Matching Parameters')
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'could not get root path for Peak Matching Results'
		goto done
	end

	---------------------------------------------------
	-- initialize paths with root path parts
	---------------------------------------------------

	if @ClientPerspective > 0
		begin
		set @outputFolderPath = @parRootPathClient
		set @iniFilePath = @iniRootPathClient
		end
	else
		begin
		set @outputFolderPath = @parRootPathServer
		set @iniFilePath = @iniRootPathServer
		end

	---------------------------------------------------
	-- Start transaction
	---------------------------------------------------
	--
	declare @transName varchar(32)
	set @transName = 'RequestPeakMatchingTask'
	begin transaction @transName
	
	---------------------------------------------------
	-- find a job matching the input request
	-- only grab the taskID and Job number at this time
	---------------------------------------------------

	SELECT TOP 1 
		@taskID = Task_ID,
		@analysisJob = T_Peak_Matching_Task.Job
	FROM T_Peak_Matching_Task WITH (HoldLock)
		 INNER JOIN #XPD ON #XPD.ID = T_Peak_Matching_Task.Task_ID 
	WHERE Processing_State = 1
	--
	SELECT @myError = @@error
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

	if @taskID = 0
	begin
		rollback transaction @transName
		set @message = 'Could not find viable record'
		goto done
	end

	---------------------------------------------------
	-- generate folder and file names and set paths
	---------------------------------------------------

	Declare @OutputFolderPrefix varchar(128)
	Declare @UnderscoreLoc int
	Declare @StartPos int

	SELECT	@OutputFolderPrefix = IsNull(T_FTICR_Analysis_Description.Storage_Path, 'Unknown')
	FROM	T_Peak_Matching_Task LEFT OUTER JOIN
			T_FTICR_Analysis_Description ON 
			T_Peak_Matching_Task.Job = T_FTICR_Analysis_Description.Job
	WHERE (Task_ID = @taskID)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @myError = 111
		set @message = 'Could not get Storage_Path name'
		goto done
	end

	If Len(@OutputFolderPrefix) = 0
		Set @OutputFolderPrefix = 'Unknown'
		
	-- Truncate @OutputFolderPrefix following the _ (if present)
	-- If @OutputFolderPrefix contains LTQ_FT, then skip the first underscore
	Set @StartPos = CharIndex('LTQ_FT', Upper(@OutputFolderPrefix))
	If @StartPos >= 1
		Set @StartPos = @StartPos + 5
	Else
	Begin
		Set @StartPos = CharIndex('LTQ_Orb', Upper(@OutputFolderPrefix))
		If @StartPos >= 1
			Set @StartPos = @StartPos + 5
		Else
			Set @StartPos = 0
	End
		
	Set @UnderscoreLoc = CharIndex('_', @OutputFolderPrefix, @StartPos)
	If @UnderscoreLoc > 2
		Set @OutputFolderPrefix = SubString(@OutputFolderPrefix, 1, @UnderscoreLoc-1)
	
	declare @Output_Folder_Name varchar (255)
	set @Output_Folder_Name = DB_Name() + '_Job' + cast(@analysisJob as varchar(12)) + '_auto_pm_' + cast(@taskID as varchar(12))
	set @Output_Folder_Name = dbo.udfCombinePaths(@OutputFolderPrefix, @Output_Folder_Name)

	set @outputFolderPath = dbo.udfCombinePaths(dbo.udfCombinePaths(@outputFolderPath, DB_Name()), @Output_Folder_Name)
	
	---------------------------------------------------
	-- set state and path for task
	---------------------------------------------------

	UPDATE T_Peak_Matching_Task
	SET 
		Processing_State = 2, 
		PM_Start = GETDATE(),
		PM_AssignedProcessorName = @ProcessorName, 
		Output_Folder_Name = @Output_Folder_Name
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
	
	---------------------------------------------------
	-- commit transaction
	---------------------------------------------------
	commit transaction @transName

	---------------------------------------------------
	-- get task parameters
	---------------------------------------------------
	
	SELECT
		@confirmedOnly = Confirmed_Only, 
		@modList = Mod_List, 
		@MinimumHighNormalizedScore = Minimum_High_Normalized_Score,
		@MinimumHighDiscriminantScore = Minimum_High_Discriminant_Score,
		@MinimumPMTQualityScore = Minimum_PMT_Quality_Score,
		@ExperimentFilter = Experiment_Filter,
		@ExperimentExclusionFilter = Experiment_Exclusion_Filter,
		@LimitToPMTsFromDataset = Limit_To_PMTs_From_Dataset,
		@InternalStdExplicit = Internal_Std_Explicit,
		@NetValueType = NET_Value_Type,
 		@IniFileName = LTrim(RTrim(Ini_File_Name)), 
		@taskPriority = Priority
	FROM T_Peak_Matching_Task
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
	
	-- Check for @IniFileName containing a UNC path
	-- If it does not contain a UNC path, prepend @IniFileName with @iniFilePath
	If Len(@IniFileName) > 2
	Begin
		If SubString(@IniFileName, 1, 2) = '\\'
			Set @iniFilePath = @IniFileName
		Else
			Set @iniFilePath = dbo.udfCombinePaths(@iniFilePath, @IniFileName)
	End
	
	---------------------------------------------------
	-- get path to analysis job results folder
	---------------------------------------------------
	
	SELECT @analysisResultsFolderPath = dbo.udfCombinePaths(
										dbo.udfCombinePaths(
										dbo.udfCombinePaths(Vol_Client, Storage_Path), Dataset_Folder), Results_Folder)
	FROM T_FTICR_Analysis_Description
	WHERE (Job = @analysisJob)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @myError = 113
		set @message = 'Could not get task parameters'
		goto done
	end


	---------------------------------------------------
	-- Define the log file path
	---------------------------------------------------

	set @logFilePath = dbo.udfCombinePaths(@outputFolderPath, 'Job' + cast(@analysisJob as varchar(9)) + '_log.txt')

	---------------------------------------------------
	-- If we get to this point, then all went fine
	-- Update TaskAvailable
	---------------------------------------------------
	Set @TaskAvailable = 1

	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[RequestPeakMatchingTask]  TO [DMS_SP_User]
GO

