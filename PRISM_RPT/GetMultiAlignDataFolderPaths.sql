/****** Object:  StoredProcedure [dbo].[GetMultiAlignDataFolderPaths] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.GetMultiAlignDataFolderPaths
/****************************************************
**
**	Desc:	Returns the folder paths associated with the given MultiAlign Task
**			Requires that @JobNum correspond to an entry in T_MultiAlign_Params_Cached
**
**			Uses V_MS_Analysis_Jobs of the database associated with the given job to determine the paths
**
**	Auth:	mem
**	Date:	01/15/2008
**
*****************************************************/
(
	@JobNum int,
	@message varchar(512) = '' output
)
As
	set nocount on

	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Declare @TaskID int
	Declare @TaskServer varchar(256)
	Declare @TaskDB varchar(256)
	Declare @DMSJobList varchar(max)
	
	Declare @WorkingServerPrefix varchar(512)
	Declare @DBPath varchar(512)
	Declare @S nvarchar(2048)
	
	Begin Try
		
		Set @CurrentLocation = 'Validate input parameters'
		
		If @JobNum Is Null
		Begin
			Set @message = '@JobNum cannot be null'
			Set @myError = 52000
			Goto Done
		End
		
		Set @message = ''

		---------------------------------------------------
		-- Look for @JobNum in T_MultiAlign_Params_Cached
		---------------------------------------------------
		
		Set @CurrentLocation = 'Query T_MultiAlign_Params_Cached'

		SELECT	@TaskID = Task_ID, 
				@TaskServer = Task_Server,
				@TaskDB = Task_Database, 
				@DMSJobList = DMS_Job_List
		FROM T_MultiAlign_Params_Cached
		WHERE (Job_ID = @JobNum)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myRowCount = 0
		Begin
			Set @message = 'Job ' + Convert(varchar(12), @JobNum) + ' not found in T_MultiAlign_Params_Cached'
			Set @myError = 52001
			Goto Done
		End
		
		If Len(IsNull(@DMSJobList, '')) = 0
		Begin
			Set @message = 'DMS_Job_List is blank for Job ' + Convert(varchar(12), @JobNum) + 'in T_MultiAlign_Params_Cached'
			Set @myError = 52002
			Goto Done
		End

		-- Construct the working server prefix
		If Lower(@@ServerName) = Lower(@TaskServer)
			Set @WorkingServerPrefix = ''
		Else
			Set @WorkingServerPrefix = @TaskServer + '.'

		-- Define the full path to the DB; note that @WorkingServerPrefix will be blank or will End in a period
		Set @DBPath = @WorkingServerPrefix + '[' + @TaskDB + ']'


		-- Populate a temporary Table with the jobs in @DMSJobList
		CREATE TABLE #TmpMultiAlignJobList (
			Job int NOT NULL,
			Results_Folder_Path varchar(512) NULL,
			Results_Folder_Path_Local varchar(512) NULL
		)

		INSERT INTO #TmpMultiAlignJobList (Job, Results_Folder_Path, Results_Folder_Path_Local)
		SELECT Value, '', ''
		FROM dbo.udfParseDelimitedIntegerList(@DMSJobList, ',')
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		
		-- Populate a temporary table with the path for each Job, as defined in #TmpMultiAlignJobList
		Set @S = ''
		Set @S = @S + ' UPDATE #TmpMultiAlignJobList '
		Set @S = @S + ' SET Results_Folder_Path = Src.Results_Folder_Path,'
		Set @S = @S +     ' Results_Folder_Path_Local = Src.Results_Folder_Path_Local'
		Set @S = @S + ' FROM #TmpMultiAlignJobList Target INNER JOIN '
		Set @S = @S +    ' ' + @DBPath + '.dbo.V_MS_Analysis_Jobs Src ON Target.Job = Src.Job'
		
		Exec sp_executesql @S
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		
		-- Return the data in #TmpMultiAlignJobList
		SELECT Job, Results_Folder_Path, Results_Folder_Path_Local
		FROM #TmpMultiAlignJobList
		ORDER BY Job
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'GetMultiAlignDataFolderPaths')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
								@ErrorNum = @myError output, @message = @message output
		Goto Done
	End Catch

	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	Return @myError

GO
