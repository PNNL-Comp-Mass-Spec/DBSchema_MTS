/****** Object:  StoredProcedure [dbo].[RequestPeakMatchingTask] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
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
**			10/09/2006 mem - Added parameter @MinimumPeptideProphetProbability
**			12/29/2006 mem - Updated to allow @TaskID values of 0
**			03/17/2007 mem - Updated to preferentially use Instrument to determine the output folder prefix
**						   - Updated to look for the results folder at the Vol_Server location, and, if not found, return the Vol_Client location
**						   - Added parameter @infoOnly
**			01/03/2008 mem - Moved output folder name logic to after the Transaction Commit
**			01/10/2008 mem - No longer including the DB_Name in the final output folder name since that can lead to path lengths over 255 characters when the .Ini file is copied over
**			06/16/2009 mem - Now storing Exactive results in folder 'Exactive'
**			02/02/2010 mem - Now storing Velos Orbitrap results (VOrbi) in folder 'LTQ_Orb'
**			10/18/2012 mem - Now storing IMS results in folder 'IMS'
**			05/06/2013 mem - Now storing QExactive results 'QExact'
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
	@mtdbName varchar(128)='' output,
	@confirmedOnly tinyint=0 output,
	@modList varchar(128)='' output,
	@MinimumHighNormalizedScore real=0 output,
	@MinimumHighDiscriminantScore real=0 output,
	@MinimumPeptideProphetProbability real=0 output,
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
	@message varchar(512)='' output,
	@infoOnly tinyint=0						-- Set to 1 to preview the next peak matching task that would be assigned
)
As
	set nocount on

	Declare @IniFileName varchar(255)
	set @IniFileName = ''
	
	declare @myError int
	declare @myRowCount int
	set @myError = 0
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
	set @MinimumPeptideProphetProbability = 0
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
		Task_ID  int, 
		Job int
	) 

	---------------------------------------------------
	-- populate temporary table with a small pool of 
	-- Peak Matching tasks
	-- Note:  This takes no locks on any tables
	---------------------------------------------------

	INSERT INTO #XPD (Task_ID, Job)
	SELECT TOP 5 Task_ID, Job
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
	WHERE ([Function] = 'Peak Matching Results')
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Could not get root path for Peak Matching Parameters'
		goto done
	end


	declare @iniRootPathClient varchar(255)
	declare @iniRootPathServer varchar(255)

	SELECT     
		@iniRootPathClient = Client_Path, 
		@iniRootPathServer = Server_Path
	FROM MT_Main.dbo.V_Folder_Paths
	WHERE ([Function] = 'Peak Matching Parameters')
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Could not get root path for Peak Matching Results'
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
	-- find a task matching the input request
	-- only grab the taskID and Job number at this time
	---------------------------------------------------

	SELECT TOP 1 
		@taskID = PM.Task_ID,
		@analysisJob = PM.Job
	FROM T_Peak_Matching_Task PM WITH (HoldLock)
		 INNER JOIN #XPD ON #XPD.Task_ID = PM.Task_ID 
	WHERE PM.Processing_State = 1
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

		
	If @infoOnly = 0
	Begin
		---------------------------------------------------
		-- set state and path for task
		---------------------------------------------------

		UPDATE T_Peak_Matching_Task
		SET 
			Processing_State = 2, 
			PM_Start = GETDATE(),
			PM_AssignedProcessorName = @ProcessorName
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
	Declare @OutputFolderBase varchar(256) = ''

	Declare @Instrument varchar(128)
	Declare @StoragePathClient varchar(256)
	Declare @LegacyStoragePath varchar(256)
	
	Declare @CharLoc int
	Declare @StartPos int
	
	SELECT	@Instrument = FAD.Instrument,
			@StoragePathClient = IsNull(FAD.Vol_Client, ''),
			@LegacyStoragePath = IsNull(FAD.Storage_Path, '')
	FROM	T_Peak_Matching_Task PM INNER JOIN
			T_FTICR_Analysis_Description FAD ON 
			PM.Job = FAD.Job
	WHERE (PM.Task_ID = @taskID)
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
	Else
	Begin
		If Len(@LegacyStoragePath) > 0
			Set @OutputFolderPrefix = @LegacyStoragePath
		Else
		Begin
			-- See if @StoragePathClient contains a server name plus a share and folder name
			-- If it does, extract out the final folder name
			-- For example, given "\\a2.emsl.pnl.gov\dmsarch\LTQ_FT1_2\" extract out "LTQ_FT1_2"
			set @CharLoc = CharIndex('\', Reverse(@StoragePathClient), 2)
			
			If @CharLoc > 0
			Begin
				Set @OutputFolderPrefix = Substring(@StoragePathClient, Len(@StoragePathClient) - @CharLoc + 2, 128) 
			End
		End
	End
	
	If Len(IsNull(@OutputFolderPrefix, '')) = 0
		Set @OutputFolderPrefix = 'Unknown'
	
	-- Shorten @OutputFolderPrefix when possible
	If @OutputFolderBase = '' AND @OutputFolderPrefix Like 'Exact[0-9]%'
		Set @OutputFolderBase = 'Exactive'

	If @OutputFolderBase = '' AND @OutputFolderPrefix Like '%VOrbi%'
		Set @OutputFolderBase = 'LTQ_Orb'

	If @OutputFolderBase = '' AND @OutputFolderPrefix Like 'IMS%'
		Set @OutputFolderBase = 'IMS'
	
	If @OutputFolderBase = '' AND @OutputFolderPrefix Like 'QExact%'
		Set @OutputFolderBase = 'QExact'

	
	If @OutputFolderBase = ''
	Begin
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
			Set @OutputFolderBase = SubString(@OutputFolderPrefix, 1, @CharLoc-1)

	End

	If @OutputFolderBase = ''
		Set @OutputFolderBase = @OutputFolderPrefix
	
	-- Construct the Output Folder Name
	declare @Output_Folder_Name varchar(255)
	set @Output_Folder_Name = 'Job' + convert(varchar(12), @analysisJob) + '_auto_pm_' + convert(varchar(12), @taskID)
	
	set @Output_Folder_Name = dbo.udfCombinePaths(@OutputFolderBase, @Output_Folder_Name)

	set @outputFolderPath = dbo.udfCombinePaths(dbo.udfCombinePaths(@outputFolderPath, DB_Name()), @Output_Folder_Name)
	

	---------------------------------------------------
	-- Update Output_Folder_Name if @infoOnly = 0
	---------------------------------------------------

	If @infoOnly = 0
	Begin
		UPDATE T_Peak_Matching_Task
		SET Output_Folder_Name = @Output_Folder_Name
		WHERE (Task_ID = @taskID)
	End
		
	---------------------------------------------------
	-- get task parameters
	---------------------------------------------------
	
	SELECT
		@confirmedOnly = Confirmed_Only, 
		@modList = Mod_List, 
		@MinimumHighNormalizedScore = Minimum_High_Normalized_Score,
		@MinimumHighDiscriminantScore = Minimum_High_Discriminant_Score,
		@MinimumPeptideProphetProbability = Minimum_Peptide_Prophet_Probability,
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
	-- Get path to analysis job results folder
	---------------------------------------------------
	
	Declare @analysisResultsFolderPathAlt varchar(255)
	Declare @FolderExists tinyint
	
	SELECT @analysisResultsFolderPath = dbo.udfCombinePaths(
										dbo.udfCombinePaths(
										dbo.udfCombinePaths(Vol_Client, Storage_Path), Dataset_Folder), Results_Folder),
		   @analysisResultsFolderPathAlt = dbo.udfCombinePaths(
										dbo.udfCombinePaths(
										dbo.udfCombinePaths(Vol_Server, Storage_Path), Dataset_Folder), Results_Folder)
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
	-- See if folder @analysisResultsFolderPathAlt exists
	-- If it does, preferentially use it
	---------------------------------------------------
	exec ValidateFolderExists @analysisResultsFolderPathAlt, @CreateIfMissing = 0, @FolderExists = @FolderExists output
	If @FolderExists <> 0
		Set @analysisResultsFolderPath = @analysisResultsFolderPathAlt
	
	---------------------------------------------------
	-- Define the log file path
	---------------------------------------------------

	set @logFilePath = dbo.udfCombinePaths(@outputFolderPath, 'Job' + convert(varchar(12), @analysisJob) + '_log.txt')

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
					@analysisJob AS Job,
					@analysisResultsFolderPath AS Results_Folder_Path,
					@mtdbName AS Database_Name,
					@confirmedOnly AS Confirmed_Only,
					@modList AS Mod_List,
					@MinimumHighNormalizedScore AS Minimum_High_Normalized_Score,
					@MinimumHighDiscriminantScore AS Minimum_High_Discriminant_Score,
					@MinimumPeptideProphetProbability AS Minimum_Peptide_Prophet_Probability,
					@MinimumPMTQualityScore AS Minimum_PMT_Quality_Score,
					@ExperimentFilter AS Experiment_Filter,
					@ExperimentExclusionFilter AS Experiment_Exclusion_Filter,
					@LimitToPMTsFromDataset AS Limit_To_PMTs_From_Dataset,
					@InternalStdExplicit AS Internal_Std_Explicit,
					@NETValueType AS NET_Value_Type,
					@iniFilePath AS Ini_File_Path,
					@outputFolderPath AS Output_Folder_Path,
					@logFilePath AS Log_File_Path
				End
			End
	
	End

	return @myError


GO
GRANT EXECUTE ON [dbo].[RequestPeakMatchingTask] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[RequestPeakMatchingTask] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[RequestPeakMatchingTask] TO [MTS_DB_Lite] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[RequestPeakMatchingTask] TO [pnl\MTSProc] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[RequestPeakMatchingTask] TO [pnl\svc-dms] AS [dbo]
GO
