/****** Object:  StoredProcedure [dbo].[RequestPeakMatchingTaskMaster] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.RequestPeakMatchingTaskMaster 
/****************************************************
**
**	Desc:	For each database listed in T_MT_Database_List, calls the RequestPeakMatchingTask SP
**			If @TaskAvailable = 1, then exits the loop and exits this SP, returning 
**			 the parameters returned by the RequestPeakMatchingTask SP.  If @TaskAvailable = 0, 
**			 then continues calling RequestPeakMatchingTaskin each database until all have been called.
**
**			If @serverName and @mtdbName are provided, then will check that DB first
**			If @RestrictToMtdbName = 1, then only checks @mtdbName (on @serverName)
**			Can limit which priority tasks to return using @PriorityMin and @PriorityMax
**
**			If a task is returned to the calling computer, then updates T_Peak_Matching_Activity 
**			with the relevant information
**
**	Auth:	mem
**	Date:	06/19/2003
**
**			06/20/2003
**			07/01/2003
**			07/22/2003
**			07/23/2003
**			08/14/2003
**			08/27/2003
**			12/29/2003 mem - Added NETValueType parameter
**			01/06/2004 mem - Added support for Minimum_PMT_Quality_Score
**			02/19/2004 mem - Added check to confirm that each database actually exists
**			09/20/2004 mem - Updated to support MTDB schema version 2
**			12/12/2004 mem - Ported to PRISM_RPT, updated to use MTS_Master, and added @serverName parameter
**			02/05/2005 mem - Added parameters @MinimumHighDiscriminantScore, @ExperimentFilter, and @ExperimentExclusionFilter and switched from using data type decimal(9,5) to real
**			05/20/2005 mem - Now populating T_Peak_Matching_History; also, renamed field Output_Folder_Name to Output_Folder_Path
**			11/08/2005 mem - Added call to CheckStalledPeakMatchingProcessors
**			11/23/2005 mem - Added brackets around @CurrentMTDB as needed to allow for DBs with dashes in the name
**			12/08/2005 mem - Added parameter @toolVersion
**						   - Now populating fields PM_ToolVersion and PM_ToolQueryDate in T_Peak_Matching_Activity
**			12/11/2005 mem - Moved call to CheckStalledPeakMatchingProcessors to the end of this SP
**			12/22/2005 mem - Added output parameters @LimitToPMTsFromDataset and @InternalStdExplicit
**			03/11/2006 mem - Now calling VerifyUpdateEnabled on each server to verify that updating is enabled
**			10/09/2006 mem - Added parameter @MinimumPeptideProphetProbability
**
*****************************************************/
(
	@processorName varchar(128),
	@clientPerspective tinyint = 1,				-- 0 means running SP from local server; 1 means running SP from client
	@priorityMin tinyint = 1,					-- only tasks with a priority >= to this value will get returned
	@priorityMax tinyint = 10,					-- only tasks with a priority <= to this value will get returned
	@restrictToMtdbName tinyint = 0,			-- If 1, will only check the DB named mtdbName on serverName
	@taskID int = 0 output,
	@taskPriority tinyint = 0 output,				-- the actual priority of the task
	@analysisJob int = 0 output,
	@analysisResultsFolderPath varchar(256) = '' output,
	@serverName varchar(128) = '' output,			-- Note: if @serverName and @mtdbName are provided, then will preferentially query that mass tag database first
	@mtdbName varchar(128)= ''  output,
	@amtsOnly tinyint = 0 output,					-- Not used by MTDB schema version 2
	@confirmedOnly tinyint = 0 output,
	@lockersOnly tinyint = 0 output,				-- Not used by MTDB schema version 2
	@LimitToPMTsFromDataset tinyint = 0 output,		-- Not used by MTDB schema version 1
	@mtSubsetID int = 0 output,						-- Not used by MTDB schema version 2
	@modList varchar(128) = '' output,
	@MinimumHighNormalizedScore real=0 output,
	@MinimumHighDiscriminantScore real=0 output,	-- Not used by MTDB schema version 1
	@MinimumPMTQualityScore real=0 output,
	@ExperimentFilter varchar(64)='' output,			-- Not used by MTDB schema version 1
	@ExperimentExclusionFilter varchar(64)='' output,	-- Not used by MTDB schema version 1
	@InternalStdExplicit varchar(255) = '' output,		-- Not used by MTDB schema version 1
	@NETValueType tinyint=0 output,
	@iniFilePath varchar(255) = '' output,
	@outputFolderPath varchar(255) = '' output,
	@logFilePath varchar(255) = '' output,
	@taskAvailable tinyint = 0 output,
	@message varchar(512) = '' output,
	@DBSchemaVersion real = 1 output,
	@toolVersion varchar(128) = 'Unknown',
	@MinimumPeptideProphetProbability real=0 output
)
As
	set nocount on

	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	declare @done int,
			@WorkingStatus int,
			@WorkingTaskID int,
			@WorkingJob int,
			@WorkingPMStart datetime,
			@WorkingServerName varchar(128),
			@WorkingMTDBName varchar(128),
			@ErrorMessage varchar(500)
	
	set @WorkingStatus = 0
	set @WorkingTaskID = 0
	set @WorkingJob = 0
	set @WorkingPMStart = 0
	set @WorkingServerName = ''
	set @WorkingMTDBName = ''
	
	declare @ActivityRowCount int
	declare @SPRowCount int
	declare @UpdateEnabled tinyint
	declare @DBCountChecked int

	set @ActivityRowCount = 0
	set @SPRowCount = 0
	set @DBCountChecked = 0
	
	declare @PMHistoryID int
	declare @TimeStarted datetime
	
	-- Note: @S needs to be unicode (nvarchar) for compatibility with sp_executesql
	declare @S nvarchar(2048),
			@ServerID int,
			@CurrentServer varchar(255),
			@CurrentMTDB varchar(255),
			@DBPath varchar(512),
			@SPToExec varchar(512),
			@PreferredServerName varchar(255),
			@PreferredDBName varchar(255),
			@WorkingServerPrefix varchar(255)

	set @S = ''
	set @CurrentServer = ''
	set @CurrentMTDB = ''
	set @DBPath = ''
	set @DBSchemaVersion = 1.0
	set @SPToExec = ''
	set @PreferredServerName = IsNull(@serverName, '')
	set @PreferredDBName = IsNull(@mtdbName, '')
	set @WorkingServerPrefix = ''
	
	set @message = ''
		
	---------------------------------------------------
	-- Clear the output arguments
	---------------------------------------------------
	set @taskID = 0
	set @analysisJob = 0
	set @analysisResultsFolderPath = ''
	set @serverName = ''
	set @mtdbName = ''
	set @amtsOnly = 0
	set @confirmedOnly = 0
	set @lockersOnly = 0
	set @mtsubsetID = 0
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
	set @taskAvailable = 0
	
	---------------------------------------------------
	-- Create a temporary table to hold list of databases to process
	---------------------------------------------------
	CREATE TABLE #XMTDBNames (
		Server_Name varchar(128),
		MTDB_Name varchar(128),
		Processed tinyint
	) 

	---------------------------------------------------
	-- Populate the temporary table with list of mass tag
	-- databases that are not deleted
	---------------------------------------------------
	INSERT INTO #XMTDBNames
	SELECT	Server_Name, MT_DB_Name, 0
	FROM	MTS_Master.dbo.V_Active_MT_DBs
	ORDER BY Server_Name, MT_DB_Name
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'could not load temporary table'
		goto done
	end


	---------------------------------------------------
	-- For each of the servers in #XMTDBNames, validate that MS_Peak_Matching is enabled
	-- Delete entries for a given server if updating is not enabled
	---------------------------------------------------
	Set @ServerID = -1
	Set @done = 0
	While @done = 0 and @myError = 0  
	Begin
		SELECT TOP 1 @CurrentServer = Server_Name, @ServerID = Server_ID
		FROM MTS_Master.dbo.V_Active_MTS_Servers		
		WHERE Server_ID > @ServerID
		ORDER BY Server_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myRowCount = 0
			Set @done = 1
		Else
		Begin
			-- Construct the working server prefix
			If Lower(@@ServerName) = Lower(@CurrentServer)
				Set @WorkingServerPrefix = ''
			Else
				Set @WorkingServerPrefix = @CurrentServer + '.'

			-- Query T_Process_Step_Control on the given server
			Set @S = ''
			Set @S = @S + ' exec ' + @WorkingServerPrefix + 'MT_Main.dbo.VerifyUpdateEnabled ''MS_Peak_Matching'','
			Set @S = @S + ' ''RequestPeakMatchingTaskMaster'', @AllowPausing = 0, @PostLogEntryIfDisabled = 0,'
			Set @S = @S + ' @MinimumHealthUpdateIntervalSeconds = 300, @UpdateEnabled = @UpdateEnabled output'

			Set @UpdateEnabled = 1
			EXEC sp_executesql @S, N'@UpdateEnabled int OUTPUT', @UpdateEnabled OUTPUT

			If IsNull(@UpdateEnabled, 1) <> 1
			Begin
				print 'Deleting rows for ' + @CurrentServer
				DELETE FROM #XMTDBNames
				WHERE Server_Name = @CurrentServer
			End
		End
	End

	---------------------------------------------------
	-- Do not return any tasks if @toolVersion = 'Unknown'
	---------------------------------------------------
	Set @toolVersion = IsNull(@toolVersion, 'Unknown')
	If @toolVersion = 'Unknown'
	Begin
		Set @message = 'This version of Viper is out of date for automated peak matching; no tasks will be returned'
		Set @toolVersion = @toolVersion + ' - Unsupported version'
		set @done = 1
	End
	Else
		set @done = 0

	---------------------------------------------------
	-- Step through the mass tag database list and call
	-- RequestPeakMatchingTask in each one (if it exists)
	-- If a peak matching task is found, then exit the
	-- while loop
	---------------------------------------------------
	WHILE @done = 0 and @myError = 0  
	BEGIN -- <a>
	
		If Len(@PreferredServerName) > 0 And Len(@PreferredDBName) > 0
			begin
				-- Look for @PreferredServerName and @PreferredDBName in XMTDBNames
				--
				SELECT	TOP 1 @CurrentServer = Server_Name, @CurrentMTDB = MTDB_Name
				FROM	#XMTDBNames 
				WHERE	Processed = 0 AND 
						Server_Name = @PreferredServerName AND
						MTDB_Name = @PreferredDBName
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				--	
				-- Set these to '' so that we don't check for it on the next loop
				Set @PreferredServerName = ''
				Set @PreferredDBName = ''
			end
		else
			begin
				-- Get next available entry from XMTDBNames
				--
				SELECT	TOP 1 @CurrentServer = Server_Name, @CurrentMTDB = MTDB_Name
				FROM	#XMTDBNames 
				WHERE	Processed = 0
				ORDER BY Server_Name, MTDB_Name
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				--		
				if @myRowCount = 0
					set @done = 1
			end

		If @myRowCount > 0
			begin -- <b>
			
				-- update Process_State entry for given MTDB to 1
				--
				UPDATE	#XMTDBNames
				SET		Processed = 1
				WHERE	Server_Name = @CurrentServer AND MTDB_Name = @CurrentMTDB
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				--
				if @myError <> 0 
				begin
					set @message = 'Could not update the mass tag database list temp table'
					set @myError = 51
					goto Done
				end
				
				-- Construct the working server prefix
				If Lower(@@ServerName) = Lower(@CurrentServer)
					Set @WorkingServerPrefix = ''
				Else
					Set @WorkingServerPrefix = @CurrentServer + '.'

				-- Define the full path to the DB; note that @WorkingServerPrefix will be blank or will end in a period
				Set @DBPath = @WorkingServerPrefix + '[' + @CurrentMTDB + ']'
				
				-- Check if the database actually exists
				Set @SPRowCount = 0
				Set @S = ''
				Set @S = @S + ' SELECT @SPRowCount = Count(*) '
				Set @S = @S + ' FROM ' + @WorkingServerPrefix + 'master.dbo.sysdatabases AS SD'
				Set @S = @S + ' WHERE SD.NAME = ''' + @CurrentMTDB + ''''

				EXEC sp_executesql @S, N'@SPRowCount int OUTPUT', @SPRowCount OUTPUT

				If (@SPRowCount > 0)
				Begin -- <c>
				
					-- Check if the RequestPeakMatchingTask SP exists for @CurrentMTDB

					Set @SPRowCount = 0
					Set @S = ''				
					Set @S = @S + ' SELECT @SPRowCount = COUNT(*)'
					Set @S = @S + ' FROM ' + @DBPath + '.dbo.sysobjects'
					Set @S = @S + ' WHERE name = ''RequestPeakMatchingTask'''
								
					EXEC sp_executesql @S, N'@SPRowCount int OUTPUT', @SPRowCount OUTPUT

					If (@SPRowCount > 0)
					Begin -- <d>

						-- Lookup the DB Schema Version
						--
						-- Lookup the DBSchemaVersion by calling GetDBSchemaVersion in @DBPath
						Set @SPToExec = @DBPath + '.dbo.GetDBSchemaVersion'
	
						Set @myError = 0
						Set @DBSchemaVersion = 1
						Exec @myError = @SPToExec @DBSchemaVersion output
						
						
						-- Call RequestPeakMatchingTask in @CurrentMTDB
						Set @SPToExec = @DBPath + '.dbo.RequestPeakMatchingTask'
						
						Set @TaskAvailable = 0
						If @DBSchemaVersion < 2
						Begin
							-- The following are not used in schema version 1
							Set @MinimumHighDiscriminantScore = 0
							Set @MinimumPeptideProphetProbability = 0
							Set @ExperimentFilter = ''
							Set @ExperimentExclusionFilter = ''
							Set @InternalStdExplicit = ''
							Set @LimitToPMTsFromDataset = 0
							
							Exec @myError = @SPToExec	@ProcessorName,
														@ClientPerspective, 
														@PriorityMin, 
														@PriorityMax,
														@taskID = @taskID output, 
														@taskPriority = @taskPriority output,
														@analysisJob = @analysisJob output,
														@analysisResultsFolderPath = @analysisResultsFolderPath output,
														@mtdbName = @mtdbName output,
														@amtsOnly = @amtsOnly  output,
														@confirmedOnly = @confirmedOnly output,
														@lockersOnly = @lockersOnly output,
														@mtsubsetID = @mtsubsetID output,
														@modList = @modList output,
														@MinimumHighNormalizedScore = @MinimumHighNormalizedScore output,
														@MinimumPMTQualityScore = @MinimumPMTQualityScore output,
														@NETValueType = @NETValueType output,
														@iniFilePath = @iniFilePath output,
														@outputFolderPath = @outputFolderPath output,
														@logFilePath = @logFilePath output,
														@TaskAvailable = @TaskAvailable output,
														@message = @message output
						End
						Else
						Begin
							-- The following are not used in schema version 2
							Set @amtsOnly = 0
							Set @lockersOnly = 0
							Set @mtsubsetID = 0
							
							Exec @myError = @SPToExec	@ProcessorName,
														@ClientPerspective, 
														@PriorityMin, 
														@PriorityMax,
														@taskID = @taskID output, 
														@taskPriority = @taskPriority output,
														@analysisJob = @analysisJob output,
														@analysisResultsFolderPath = @analysisResultsFolderPath output,
														@mtdbName = @mtdbName output,
														@confirmedOnly = @confirmedOnly output,
														@modList = @modList output,
														@MinimumHighNormalizedScore = @MinimumHighNormalizedScore output,
														@MinimumHighDiscriminantScore = @MinimumHighDiscriminantScore output,
														@MinimumPeptideProphetProbability = @MinimumPeptideProphetProbability output,
														@MinimumPMTQualityScore = @MinimumPMTQualityScore output,
														@ExperimentFilter = @ExperimentFilter output,
														@ExperimentExclusionFilter = @ExperimentExclusionFilter output,
														@LimitToPMTsFromDataset = @LimitToPMTsFromDataset output,
														@InternalStdExplicit = @InternalStdExplicit output,
														@NETValueType = @NETValueType output,
														@iniFilePath = @iniFilePath output,
														@outputFolderPath = @outputFolderPath output,
														@logFilePath = @logFilePath output,
														@TaskAvailable = @TaskAvailable output,
														@message = @message output

						End
						
						If @myError <> 0
						Begin
							Set @message = 'Error calling ' + @SPToExec
							Goto Done
						End
						
						set @DBCountChecked = @DBCountChecked  + 1

						-- If a task was found, and no error occurred, then set @done = 1 so that
						-- the while loop exits
						If @TaskAvailable = 1 And @myError = 0
							Begin
								Set @done = 1
								
								Set @serverName = @CurrentServer
								Set @mtdbName = @CurrentMTDB
								Set @TimeStarted = GETDATE()
								
								-- Add a new entry to T_Peak_Matching_History
								-- Cache the identity value assigned to the new row
								INSERT INTO T_Peak_Matching_History (
												PM_AssignedProcessorName, PM_ToolVersion,
												Server_Name, MTDBName, TaskID, Job, 
												PM_Start, Output_Folder_Path)
								VALUES (@ProcessorName, @toolVersion, 
										@serverName, @mtdbName, @TaskID, @analysisJob,
										@TimeStarted, @outputFolderPath)
								--
								SELECT @myError = @@error, @myRowCount = @@rowcount, @PMHistoryID = SCOPE_IDENTITY()

								
								-- Update status of Process in T_Peak_Matching_Activity
								-- First make sure an entry exists for @ProcessorName
								SELECT PM_AssignedProcessorName
								FROM T_Peak_Matching_Activity
								WHERE PM_AssignedProcessorName = @ProcessorName
								--
								SELECT @ActivityRowCount = @@RowCount, @myError = @@Error
								
								If @ActivityRowCount = 0 AND @myError = 0
									INSERT INTO T_Peak_Matching_Activity (
											PM_AssignedProcessorName, PM_ToolVersion, PM_ToolQueryDate)
									SELECT @ProcessorName, @toolVersion, GetDate()
								--
								SELECT @myError = @@error, @myRowCount = @@rowcount
								
								If @myError = 0
								Begin
									-- Next, lookup the current status for @ProcessorName in T_Peak_Matching_Activity
									-- If the status is 1, then the processor didn't finish processing the
									--  previous analysis; in this case, post an error to the log
									SELECT	@WorkingStatus = Working, @WorkingServerName = Server_Name,
											@WorkingMTDBName = MTDBName, @WorkingTaskID = TaskID, 
											@WorkingJob = Job, @WorkingPMStart = PM_Start
									FROM T_Peak_Matching_Activity
									WHERE PM_AssignedProcessorName = @ProcessorName
									--
									SELECT @myError = @@error, @myRowCount = @@rowcount

									IF @myRowCount = 1 AND @WorkingStatus <> 0
									Begin
										-- Post an error message to T_Log_Entries stating that the given processor requested
										-- a new task, but it had failed to mark an old one as processed
										Set @ErrorMessage = 'Processor ' + @ProcessorName + ' requested a new peak matching task, but it had failed to mark the previous one as completed; previous task info: '
										Set @ErrorMessage = @ErrorMessage + 'Server = ' + @WorkingServerName
										Set @ErrorMessage = @ErrorMessage + '; DB = ' + @WorkingMTDBName 
										Set @ErrorMessage = @ErrorMessage + '; TaskID = ' + convert(varchar(19), @WorkingTaskID)
										Set @ErrorMessage = @ErrorMessage + '; Job = ' + convert(varchar(19), @WorkingJob)
										Set @ErrorMessage = @ErrorMessage + '; ProcessingStartTime = ' + convert(varchar(19), @WorkingPMStart)
										
										Exec PostLogEntry 'Error', @ErrorMessage, 'PeakMatching'
									End
									
									-- Finally, update the status for @ProcessorName to have Working = 1
									-- Record the details of the current peak matching task
									UPDATE T_Peak_Matching_Activity
									SET PM_ToolVersion = @toolVersion, PM_ToolQueryDate = GetDate(), Working = 1, 
										Server_Name = @serverName, MTDBName = @mtdbName, 
										TaskID = @TaskID, Job = @analysisJob,
										Output_Folder_Path = @outputFolderPath,
										PM_Start = @TimeStarted, PM_Finish = NULL,
										PM_History_ID = @PMHistoryID
									WHERE PM_AssignedProcessorName = @ProcessorName
									--
									SELECT @myError = @@error, @myRowCount = @@rowcount
								End
								
							End
						Else
							Begin
								Set @serverName = ''
								Set @mtdbName = ''
								Set @TaskAvailable = 0
							End

					End -- </d>
						
				End -- </c>
	
			end -- </b>	
			
		-- Only check the preferred database if @RestrictToMtdbName is 1
		--
		If @RestrictToMtdbName = 1
			Set @done = 1
				   
	END -- </a>

	Set @message = IsNull(@message, '')
	If Len(@message) > 0
		Set @message = @message + '; '
	
	Set @message = @message + 'Checked ' + Convert(varchar(9), @DBCountChecked) + ' DB'
	If @DBCountChecked > 1
		Set @message = @message + 's'

	If @TaskAvailable = 0 And @myError = 0
	Begin
		-- No available tasks were found
		-- Update the Viper tool version listed in T_Peak_Matching_Activity
		-- if it doesn't match @toolVersion
		UPDATE T_Peak_Matching_Activity
		SET PM_ToolVersion = @toolVersion, PM_ToolQueryDate = GetDate()
		WHERE PM_AssignedProcessorName = @ProcessorName
	End

	---------------------------------------------------
	-- Call CheckStalledPeakMatchingProcessors to look for stalled processors
	---------------------------------------------------
	
	Exec CheckStalledPeakMatchingProcessors 48

	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	Return @myError

GO
GRANT EXECUTE ON [dbo].[RequestPeakMatchingTaskMaster] TO [DMS_SP_User]
GO
