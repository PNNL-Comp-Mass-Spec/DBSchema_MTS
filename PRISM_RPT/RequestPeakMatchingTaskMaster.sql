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
**			 then continues calling RequestPeakMatchingTask in each database until all have been called.
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
**						   - Now populating fields Tool_Version and Tool_Query_Date in T_Peak_Matching_Activity
**			12/11/2005 mem - Moved call to CheckStalledPeakMatchingProcessors to the End of this SP
**			12/22/2005 mem - Added output parameters @LimitToPMTsFromDataset and @InternalStdExplicit
**			03/11/2006 mem - Now calling VerifyUpdateEnabled on each server to verify that updating is enabled
**			10/09/2006 mem - Added parameter @MinimumPeptideProphetProbability
**			02/19/2007 mem - Added Try/Catch error handling
**			12/21/2007 mem - Updated to use T_Analysis_Task_Candidate_DBs to determine which DBs to query (however, if @restrictToMtdbName = 1, then will always check the given DB, regardless of the contents of T_Analysis_Task_Candidate_DBs)
**			01/02/2008 mem - Now updating Last_Processing_Date in T_Analysis_Task_Candidate_DBs when a task is assigned
**			01/04/2008 mem - Switched to using T_Analysis_Job to track assigned tasks instead of T_Peak_Matching_History
**						   - Added parameter @infoOnly
**			01/08/2008 mem - Updated to store the settings in T_Peak_Matching_Params_Cached if @CacheSettingsForAnalysisManager = 1
**			02/02/2010 mem - Now updating Results_URL in T_Analysis_Job
**						   - Now populating T_Analysis_Job_Target_Jobs
**			10/12/2010 mem - Changed required tool version to %3.48.43%
**			01/31/2011 mem - Changed required tool version to %3.48.44[1-9]%
**			08/17/2011 mem - Changed required tool version to %3.48.44[8-9]% or %3.48.45[0-9]%
**			11/10/2011 mem - Changed required tool version to %3.49.4[6-7][0-9]%
**			10/22/2014 mem - Updated @duplicateEntryHoldoffHours to 2
**			08/09/2016 mem - Changed required tool version to %3.49.4[8-9][0-9]%
**
*****************************************************/
(
	@processorName varchar(128),
	@clientPerspective tinyint = 1,					-- 0 means running SP from local server; 1 means running SP from client
	@priorityMin tinyint = 1,						-- only tasks with a priority >= to this value will get returned  (priority 1 tasks are processed before priority 2 tasks)
	@priorityMax tinyint = 10,						-- only tasks with a priority <= to this value will get returned
	@restrictToMtdbName tinyint = 0,				-- If 1, will only check the DB named mtdbName on serverName (ignored if @mtdbName or @serverName is blank)
	@taskID int = 0 output,
	@taskPriority tinyint = 0 output,				-- the actual priority of the task
	@analysisJob int = 0 output,					-- DMS Analysis Job
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
	@outputFolderPath varchar(512) = '' output,
	@logFilePath varchar(255) = '' output,
	@taskAvailable tinyint = 0 output,
	@message varchar(512) = '' output,
	@DBSchemaVersion real = 1 output,
	@toolVersion varchar(128) = 'Unknown',
	@MinimumPeptideProphetProbability real=0 output,
	@AssignedJobID int = 0 output,
	@CacheSettingsForAnalysisManager tinyint = 0,
	@infoOnly tinyint = 0
)
As
	set nocount on

	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	declare @Continue tinyint,
			@WorkingStatus int,
			@WorkingTaskID int,
			@WorkingJob int,
			@WorkingTaskStart datetime,
			@WorkingServerName varchar(128),
			@WorkingMTDBName varchar(128),
			@ErrorMessage varchar(512)

	set @WorkingStatus = 0
	set @WorkingTaskID = 0
	set @WorkingJob = 0
	set @WorkingTaskStart = 0
	set @WorkingServerName = ''
	set @WorkingMTDBName = ''

	declare @SPRowCount int
	declare @UpdateEnabled tinyint
	declare @DBCountChecked int
	set @SPRowCount = 0
	set @DBCountChecked = 0

	declare @TransferFolderPath varchar(255)
	declare @ResultsFolderName varchar(255)
	declare @ParamFileStoragePath varchar(255)
	declare @ParamFileName varchar(255)
	
	declare @TimeStarted datetime
	
	-- Note: @S needs to be unicode (nvarchar) for compatibility with sp_executesql
	declare @EntryID int,
			@S nvarchar(4000),
			@ServerID int,
			@CurrentServer varchar(255),
			@CurrentMTDB varchar(255),
			@DBPath varchar(512),
			@SPToExec varchar(512),
			@PreferredServerName varchar(255),
			@PreferredDBName varchar(255),
			@WorkingServerPrefix varchar(255),
			@ResultsURL varchar(512)

	set @S = ''
	set @CurrentServer = ''
	set @CurrentMTDB = ''
	set @DBPath = ''
	set @DBSchemaVersion = 1.0
	set @SPToExec = ''
	set @PreferredServerName = IsNull(@serverName, '')
	set @PreferredDBName = IsNull(@mtdbName, '')
	set @WorkingServerPrefix = ''
	set @CacheSettingsForAnalysisManager = IsNull(@CacheSettingsForAnalysisManager, 0)
	set @infoOnly = IsNull(@infoOnly, 0)
	
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
	set @ResultsURL = ''
	set @logFilePath = ''
	set @taskAvailable = 0
	set @AssignedJobID = 0

	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Declare @ToolID int
	Set @ToolID = 1

	Begin Try

		Set @CurrentLocation = 'Create temporary tables'
		
		---------------------------------------------------
		-- Create a temporary table to hold list of databases to process
		---------------------------------------------------
		CREATE TABLE #XMTDBNames (
			Entry_ID int identity(1,1),
			Server_Name varchar(128),
			Database_Name varchar(128)
		)

		CREATE CLUSTERED INDEX #IX_XMTDBNames_Entry_ID ON #XMTDBNames([Entry_ID]) ON [PRIMARY]
		
		---------------------------------------------------
		-- Populate the temporary table with list of mass tag
		-- databases that have tasks available according to T_Analysis_Task_Candidate_DBs
		---------------------------------------------------
		--
		INSERT INTO #XMTDBNames (Server_Name, Database_Name)
		SELECT Server_Name, Database_Name
		FROM T_Analysis_Task_Candidate_DBs
		WHERE Tool_ID = @ToolID AND Task_Count_New > 0
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0
		Begin
			set @message = 'could not load temporary table'
			goto done
		End

		If @restrictToMtdbName <> 0 And Len(@PreferredServerName) > 0 And Len(@PreferredDBName) > 0
		Begin

			-- Make sure #XMTDBNames contains the preferred DB
			If Not Exists ( SELECT * FROM #XMTDBNames WHERE Server_Name = @PreferredServerName AND Database_Name = @PreferredDBName)
			INSERT INTO #XMTDBNames (Server_Name, Database_Name)
			SELECT Server_Name, MT_DB_Name
			FROM MTS_Master.dbo.V_Active_MT_DBs
			WHERE Server_Name = @PreferredServerName AND
				  MT_DB_Name = @PreferredDBName
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			
		End

		Set @CurrentLocation = 'Validate that MS_Peak_Matching is enabled on each MTS server'

		---------------------------------------------------
		-- For each of the servers in #XMTDBNames, validate that MS_Peak_Matching is enabled
		-- Delete entries for a given server if updating is not enabled
		---------------------------------------------------
		Set @ServerID = -1
		Set @Continue = 1
		While @Continue = 1 and @myError = 0  
		Begin
			SELECT TOP 1 @CurrentServer = Server_Name, 
						 @ServerID = Server_ID
			FROM MTS_Master.dbo.V_Active_MTS_Servers		
			WHERE Server_ID > @ServerID
			ORDER BY Server_ID
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			
			If @myRowCount = 0
				Set @Continue = 0
			Else
			Begin
				Set @CurrentLocation = 'Call VerifyUpdateEnabled on ' + @CurrentServer
				
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
					DELETE FROM #XMTDBNames
					WHERE Server_Name = @CurrentServer
					
					If @infoOnly <> 0
						Print 'Note: Peak Matching is disabled on server "' + @CurrentServer + '"'
				End
			End
		End


		Set @CurrentLocation = 'Check @toolVersion'

		---------------------------------------------------
		-- Do not return any tasks if @toolVersion = 'Unknown'
		---------------------------------------------------
		Set @toolVersion = IsNull(@toolVersion, 'Unknown')
		If @toolVersion = 'Unknown'
		Begin
			Set @message = 'This version of Viper is out of date for automated peak matching; no tasks will be returned'
			Set @toolVersion = @toolVersion + ' - Unsupported version'
			print @message
			set @Continue = 0
		End
		Else
		Begin
			If Not (@toolVersion LIKE '%3.49.4[8-9][0-9]%')
			Begin
				Set @message = 'This version of Viper is not presently allowed to perform peak matching; tool version must be "3.49.480" through "3.49.499"; @toolVersion = ' + @toolVersion
				Set @toolVersion = @toolVersion + ' - Version not new enough'
				print @message
				set @Continue = 0
			End
			Else
				set @Continue = 1
		End

		---------------------------------------------------
		-- Step through the mass tag database list and call
		-- RequestPeakMatchingTask in each one (if it exists)
		-- If a peak matching task is found, then exit the
		-- While loop
		---------------------------------------------------

		Set @EntryID = 0

		While @Continue = 1 and @myError = 0  
		Begin -- <a>
		
			If Len(@PreferredServerName) > 0 And Len(@PreferredDBName) > 0
			Begin
				-- Look for @PreferredServerName and @PreferredDBName in XMTDBNames
				--
				SELECT TOP 1 
							@CurrentServer = Server_Name, 
							@CurrentMTDB = Database_Name
				FROM	#XMTDBNames 
				WHERE	Server_Name = @PreferredServerName AND
						Database_Name = @PreferredDBName
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount

				If @myRowCount > 0
				Begin
					-- Now that we've looked for the preferred DB, delete it from #XMTDBNames
					DELETE FROM	#XMTDBNames 
					WHERE	Server_Name = @PreferredServerName AND
							Database_Name = @PreferredDBName
				End
				
				-- Set these to '' so that we don't check for the preferred DB on the next loop
				Set @PreferredServerName = ''
				Set @PreferredDBName = ''
			End
			Else
			Begin
				-- Get next available entry from XMTDBNames
				--
				SELECT TOP 1 
						@EntryID = Entry_ID,
						@CurrentServer = Server_Name, 
						@CurrentMTDB = Database_Name
				FROM	#XMTDBNames 
				WHERE	Entry_ID > @EntryID
				ORDER BY Server_Name, Database_Name
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				--		
				if @myRowCount = 0
					set @Continue = 0
			End

			If @myRowCount > 0
			Begin -- <b>
			
				Set @CurrentLocation = 'Prepare for call to RequestPeakMatchingTask on ' + @CurrentMTDB
				
				-- Construct the working server prefix
				If Lower(@@ServerName) = Lower(@CurrentServer)
					Set @WorkingServerPrefix = ''
				Else
					Set @WorkingServerPrefix = @CurrentServer + '.'

				-- Define the full path to the DB; note that @WorkingServerPrefix will be blank or will End in a period
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
				
					Begin Try
						
						Set @CurrentLocation = 'Look for RequestPeakMatchingTask in ' + @DBPath + '.dbo.sysobjects'
						
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

							Set @CurrentLocation = 'Call ' + @SPToExec

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
															@message = @message output,
															@infoOnly = @infoOnly

							End
							
							If @myError <> 0
							Begin
								Set @message = 'Error calling ' + @SPToExec
								Goto Done
							End
							
							set @DBCountChecked = @DBCountChecked  + 1

							-- If a task was found, and no error occurred, then set @Continue = 0 so that the While loop exits
							If @TaskAvailable = 1 And @myError = 0
							Begin -- <e>
							
								If @infoOnly <> 0
									Goto Done

								Set @CurrentLocation = 'Task found; update T_Analysis_Task_Candidate_DBs'
							
								Set @Continue = 0
								
								-- Parse @outputFolderPath to populate @ResultsURL
								-- For example, change
								--  from: \\porky\MTD_Peak_Matching\results\MT_Shewanella_ProdTest_Formic_P460\LTQ_Orb\Job566121_auto_pm_2253
								--    to: http://porky/pm/results/MT_Shewanella_ProdTest_Formic_P460/LTQ_Orb/Job566121_auto_pm_2253/Index.html
								
								Set @ResultsURL = REPLACE(@outputFolderPath, '\\', 'http://')
								Set @ResultsURL = REPLACE(@ResultsURL, '\MTD_Peak_Matching\', '/pm/')
								Set @ResultsURL = REPLACE(@ResultsURL, '\', '/') + '/Index.html'
								
								Set @serverName = @CurrentServer
								Set @mtdbName = @CurrentMTDB
								Set @TimeStarted = GETDATE()
								
								-- Update Last_Processing_Date in T_Analysis_Task_Candidate_DBs
								UPDATE T_Analysis_Task_Candidate_DBs
								SET Last_Processing_Date = @TimeStarted
								WHERE Server_Name = @CurrentServer AND
									  Database_Name = @CurrentMTDB AnD
									  Tool_ID = @ToolID
								--
								SELECT @myError = @@error, @myRowCount = @@rowcount


								Set @CurrentLocation = 'Task found; add a new entry to T_Analysis_Job'
								
								-- Add a new entry to T_Analysis_Job
								-- Cache the identity value assigned to the new row
								INSERT INTO T_Analysis_Job (
												Job_Start, Tool_ID, Comment, State_ID,
												Task_ID, Task_Server, Task_Database,
												Assigned_Processor_Name, Tool_Version,
												DMS_Job_Count, DMS_Job_Min, DMS_Job_Max,
												Output_Folder_Path,
												Results_URL)
								VALUES (@TimeStarted, @ToolID, '', 2,
										@TaskID, @serverName, @mtdbName,
										@ProcessorName, @toolVersion, 
										1, @analysisJob, @analysisJob,
										@outputFolderPath,
										@ResultsURL)
								--
								SELECT @myError = @@error, @myRowCount = @@rowcount, @AssignedJobID = SCOPE_IDENTITY()


								Set @CurrentLocation = 'Add a new entry to T_Analysis_Job_Target_Jobs'
								
								INSERT INTO T_Analysis_Job_Target_Jobs (Job_ID, DMS_Job)
								VALUES (@AssignedJobID, @analysisJob)
								--
								SELECT @myError = @@error, @myRowCount = @@rowcount


								Set @CurrentLocation = 'Add a new entry to T_Peak_Matching_Activity'

								-- Update status of Processor in T_Peak_Matching_Activity
								-- First make sure an entry exists for @ProcessorName
								IF NOT EXISTS (SELECT Assigned_Processor_Name FROM T_Peak_Matching_Activity WHERE Assigned_Processor_Name = @ProcessorName)
								Begin
									INSERT INTO T_Peak_Matching_Activity (
											Assigned_Processor_Name, Tool_Version, Tool_Query_Date)
									SELECT @ProcessorName, @toolVersion, GetDate()
									--
									SELECT @myError = @@error, @myRowCount = @@rowcount
								End
								Else
									Set @myError = 0
						
								
								If @myError = 0
								Begin -- <f>
									-- Next, lookup the current status for @ProcessorName in T_Peak_Matching_Activity
									-- If the status is 1, then the processor didn't finish processing the
									--  previous analysis; in this case, post an error to the log
									SELECT	@WorkingStatus = Working, @WorkingServerName = Server_Name,
											@WorkingMTDBName = Database_Name, @WorkingTaskID = Task_ID, 
											@WorkingJob = Job, @WorkingTaskStart = Task_Start
									FROM T_Peak_Matching_Activity
									WHERE Assigned_Processor_Name = @ProcessorName
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
										Set @ErrorMessage = @ErrorMessage + '; ProcessingStartTime = ' + convert(varchar(19), @WorkingTaskStart)
										
										Exec PostLogEntry 'Error', @ErrorMessage, 'RequestPeakMatchingTaskMaster'
									End
									
									-- Finally, update the status for @ProcessorName to have Working = 1
									-- Record the details of the current peak matching task
									UPDATE T_Peak_Matching_Activity
									SET Tool_Version = @toolVersion,
										Tool_Query_Date = GetDate(),
										Working = 1,
										Server_Name = @serverName,
										Database_Name = @mtdbName,
										Task_ID = @TaskID,
										Job = @analysisJob,
										Output_Folder_Path = @outputFolderPath,
										Task_Start = @TimeStarted,
										Task_Finish = NULL,
										Job_ID = @AssignedJobID
									WHERE Assigned_Processor_Name = @ProcessorName
									--
									SELECT @myError = @@error, @myRowCount = @@rowcount
								End -- </f>
								
								Set @CurrentLocation = 'Call UpdateCachedAnalysisTasksOneTool from RequestPeakMatchingTaskMaster'
								
								-- Call UpdateCachedAnalysisTasksOneTool for this DB
								Exec @myError = UpdateCachedAnalysisTasksOneTool @ToolID, @serverName, @mtdbName, @message = @message output
								
								If @CacheSettingsForAnalysisManager <> 0
								Begin
									-- Make sure @AssignedJobID is not already in T_Peak_Matching_Params_Cached
									DELETE FROM T_Peak_Matching_Params_Cached
									WHERE Job_ID = @AssignedJobID
									--
									SELECT @myError = @@error, @myRowCount = @@rowcount

									-- Split @outputFolderPath into @TransferFolderPath and @ResultsFolderName
									Exec @myError = SplitPath @outputFolderPath, @TransferFolderPath output, @ResultsFolderName output
									
									-- Split @paramFilePath into @ParamFileName and @ParamFileStoragePath
									Exec @myError = SplitPath @iniFilePath, @ParamFileStoragePath output, @ParamFileName output
									
									-- Cache the parameters in T_Peak_Matching_Params_Cached
									INSERT INTO T_Peak_Matching_Params_Cached (
											Job_ID,
											Task_ID,
											Task_Server,
											Task_Database,
											Priority,
											DMS_Job,
											Minimum_High_Normalized_Score,
											Minimum_High_Discriminant_Score,
											Minimum_Peptide_Prophet_Probability,
											Minimum_PMT_Quality_Score,
											Experiment_Filter,
											Experiment_Exclusion_Filter,
											Limit_To_PMTs_From_Dataset,
											Internal_Std_Explicit,
											NET_Value_Type,
											ParamFileStoragePath,
											ParamFileName,
											TransferFolderPath,
											ResultsFolderName
										)
									VALUES (
											@AssignedJobID,
											@TaskID, 
											@serverName, 
											@mtdbName,
											@taskPriority,
											@analysisJob,
											@MinimumHighNormalizedScore,
											@MinimumHighDiscriminantScore,
											@MinimumPeptideProphetProbability,
											@MinimumPMTQualityScore,
											@ExperimentFilter,
											@ExperimentExclusionFilter,
											@LimitToPMTsFromDataset,
											@InternalStdExplicit,
											@NETValueType,
											@ParamFileStoragePath,
											@ParamFileName,
											@TransferFolderPath,
											@ResultsFolderName
										)
								End
																
							End -- </e1>
							Else 
							Begin -- <e>
								Set @serverName = ''
								Set @mtdbName = ''
								Set @TaskAvailable = 0
							End -- </e2>

						End -- </d>
					
					End Try
					Begin Catch
						-- Error caught; log the error but continue processing
						Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'RequestPeakMatchingTaskMaster')
						exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
												@ErrorNum = @myError output, @message = @message output,
								                @duplicateEntryHoldoffHours = 2
					End Catch
					
				End -- </c>
	
			End -- </b>	
				
			-- Only check the preferred database if @RestrictToMtdbName is 1
			--
			If @RestrictToMtdbName = 1
				Set @Continue = 0
					   
		End -- </a>

		Set @CurrentLocation = 'Done checking all DBs'

		Set @message = IsNull(@message, '')
		If Len(@message) > 0
			Set @message = @message + '; '
		
		Set @message = @message + 'Checked ' + Convert(varchar(9), @DBCountChecked) + ' DB'
		If @DBCountChecked <> 1
			Set @message = @message + 's'

		If @TaskAvailable = 0 And @myError = 0
		Begin
			-- No available tasks were found
			-- Update the Viper tool version listed in T_Peak_Matching_Activity
			-- if it doesn't match @toolVersion
			UPDATE T_Peak_Matching_Activity
			SET Tool_Version = @toolVersion, Tool_Query_Date = GetDate()
			WHERE Assigned_Processor_Name = @ProcessorName
		End

		---------------------------------------------------
		-- Call CheckStalledPeakMatchingProcessors to look for stalled processors
		---------------------------------------------------
		
		Exec CheckStalledPeakMatchingProcessors 48

	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'RequestPeakMatchingTaskMaster')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
								@ErrorNum = @myError output, @message = @message output,
								@duplicateEntryHoldoffHours = 2
		Goto Done
	End Catch

	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	Return @myError

GO
GRANT EXECUTE ON [dbo].[RequestPeakMatchingTaskMaster] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[RequestPeakMatchingTaskMaster] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[RequestPeakMatchingTaskMaster] TO [MTS_DB_Lite] AS [dbo]
GO
