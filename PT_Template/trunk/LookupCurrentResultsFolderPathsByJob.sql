/****** Object:  StoredProcedure [dbo].[LookupCurrentResultsFolderPathsByJob] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.LookupCurrentResultsFolderPathsByJob
/****************************************************
** 
**	Desc:	Determines the best results folder path for the 
**			 jobs present in temporary table #TmpResultsFolderPaths
**			The calling procedure must create this table
**			 prior to calling this procedure
**
**			CREATE TABLE #TmpResultsFolderPaths (
**				Job INT NOT NULL,
**				Results_Folder_Path varchar(512),
**				Source_Share varchar(128)
**			)
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	04/16/2007 mem - Ticket #423
**    
*****************************************************/
(
	@CheckLocalServerFirst tinyint = 1,		-- Set to 1 to preferably use the local server path (Vol_Server); set to 0 to preferably use the client path (Vol_Client)
	@message varchar(512)='' output
)
As
set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0
	
	set @message = ''

	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Declare @Job int
	Declare @Continue tinyint
	Declare @JobNotFoundCount int
	Set @JobNotFoundCount = 0
	
	Declare @StoragePath varchar(255)
	Declare @DatasetFolder varchar(255)
	Declare @ResultsFolder varchar(255)
	Declare @VolClient varchar(255)
	Declare @VolServer varchar(255)

	Declare @FolderExists tinyint
	Declare @StoragePathClient varchar(512)
	Declare @StoragePathServer varchar(512)
	Declare @StoragePathResults varchar(512)
	Declare @SorceServerShare varchar(255)
	
	Declare @FolderCheckIteration tinyint
	Declare @IterationCount tinyint

	Begin Try
		Set @CurrentLocation = 'Process jobs in #TmpResultsFolderPaths'
		
		Set @Job = 0
		
		SELECT @Job = MIN(Job)-1
		FROM #TmpResultsFolderPaths
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		Set @Job = IsNull(@Job, 0)
		Set @Continue = 1
		
		While @Continue = 1
		Begin -- <a>
			SELECT TOP 1 @Job = Job
			FROM #TmpResultsFolderPaths
			WHERE Job > @Job
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
		
			If @myRowCount = 0
				Set @Continue = 0
			Else
			Begin -- <b>
				Set @CurrentLocation = 'Determine results for path for job ' + Convert(varchar(12), @Job)
				
				-----------------------------------------------
				-- Lookup folder path information in T_Analysis_Description
				-----------------------------------------------

				Set @VolClient = ''
				Set @VolServer = ''
				Set @StoragePath = ''
				Set @DatasetFolder = ''
				Set @ResultsFolder = ''
				Set @StoragePathResults = ''
				Set @SorceServerShare = ''
				
				SELECT	@VolClient = Vol_Client, 
						@VolServer = Vol_Server,
						@StoragePath = Storage_Path,
						@DatasetFolder = Dataset_Folder,  
						@ResultsFolder = Results_Folder
				FROM T_Analysis_Description
				WHERE (Job = @job)
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
		
				If @myRowCount = 0
				Begin
					-- Job not found; post a warning entry to the log
					Set @message = 'Job ' + Convert(varchar(12), @Job) + ' not found in T_Analysis_Description'
					
					If @JobNotFoundCount = 0
						Exec PostLogEntry 'Error', @message, 'LookupCurrentResultsFolderPathsByJob'
					Else
						Exec PostLogEntry 'Warning', @message, 'LookupCurrentResultsFolderPathsByJob'
					
					Set @JobNotFoundCount = @JobNotFoundCount + 1
					Set @message = ''
				End
				Else
				Begin -- <c>
					Begin Try
						---------------------------------------------------
						-- Get path to the analysis job results folder for job @Job
						---------------------------------------------------
						--	
						set @StoragePathClient = dbo.udfCombinePaths(
												 dbo.udfCombinePaths(
												 dbo.udfCombinePaths(@VolClient, @StoragePath), @DatasetFolder), @ResultsFolder)
						
						set @StoragePathServer = dbo.udfCombinePaths(
												 dbo.udfCombinePaths(
												 dbo.udfCombinePaths(@VolServer, @StoragePath), @DatasetFolder), @ResultsFolder)


						-- Use @CheckLocalServerFirst to determine which path to check first
						-- If the first path checked isn't found, then try the other path
						-- If neither path is found, then leave @SorceServerShare null
						If @CheckLocalServerFirst = 0
							Set @FolderCheckIteration = 0
						Else
							Set @FolderCheckIteration = 1
						
						Set @IterationCount = 0
						Set @FolderExists = 0
						While @IterationCount < 2 And @FolderExists = 0
						Begin
							If @FolderCheckIteration = 0
							Begin
								exec ValidateFolderExists @StoragePathClient, @CreateIfMissing = 0, @FolderExists = @FolderExists output
								If @FolderExists <> 0
								Begin
									Set @StoragePathResults = @StoragePathClient
									Set @SorceServerShare = @VolClient
								End
							End
						
							If @FolderCheckIteration = 1
							Begin
								exec ValidateFolderExists @StoragePathServer, @CreateIfMissing = 0, @FolderExists = @FolderExists output
								If @FolderExists <> 0
								Begin
									Set @StoragePathResults = @StoragePathServer
									Set @SorceServerShare = @VolServer
								End
							End
							
							If @FolderCheckIteration = 0
								Set @FolderCheckIteration = 1
							Else
								Set @FolderCheckIteration = 0
								
							Set @IterationCount = @IterationCount + 1
						End
						
						UPDATE #TmpResultsFolderPaths
						SET Results_Folder_Path = @StoragePathResults,
							Source_Share = @SorceServerShare
						WHERE Job = @Job
					
					End Try
					Begin Catch
						-- Error caught; log the error but continue processing
						Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'LookupCurrentResultsFolderPathsByJob')
						exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
												@ErrorNum = @myError output, @message = @message output
					End Catch		
				End -- </c>
			End -- </b>
		End -- </a>
		
		set @message = ''
		
	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'LookupCurrentResultsFolderPathsByJob')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
								@ErrorNum = @myError output, @message = @message output
		Goto Done
	End Catch		
	
Done:
	
	Return @myError


GO
