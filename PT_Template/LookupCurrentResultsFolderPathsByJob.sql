/****** Object:  StoredProcedure [dbo].[LookupCurrentResultsFolderPathsByJob] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure [dbo].[LookupCurrentResultsFolderPathsByJob]
/****************************************************
** 
**  Desc:    Determines the best results folder path for the 
**           jobs present in temporary table #TmpResultsFolderPaths
**
**           The calling procedure must create this table
**           prior to calling this procedure
**
**           CREATE TABLE #TmpResultsFolderPaths (
**               Job INT NOT NULL,
**               Results_Folder_Path varchar(512),
**               Source_Share varchar(128),
**               Required_File_List varchar(max)
**           )
**
**  Return values: 0: success, otherwise, error code
**
**  Auth:   mem
**  Date:   04/17/2007 mem - Ticket #423
**          11/21/2011 mem - Added column Required_File_List to #TmpResultsFolderPaths
**          10/10/2013 mem - Adding support for MyEMSL
**                         - Added @ShowDebugInfo
**          12/09/2013 mem - Updated to support new states in CacheMyEMSLFiles
**          12/11/2013 mem - Now showing more debug statements
**          10/11/2017 mem - Add "Folder not found" debug statement
**          03/19/2018 mem - Add additional debug statements
**    
*****************************************************/
(
    @CheckLocalServerFirst tinyint = 1,        -- Set to 1 to preferably use the Vol_Server path (e.g. \\Proto-5\LTQ_1\2008_2\); set to 0 to preferably use the Vol_Client path (e.g. \\a2.emsl.pnl.gov\dmsarch\LTQ_1\2008_2\)
    @message varchar(512)='' output,
    @ShowDebugInfo tinyint=0
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
    Declare @Instrument varchar(255)

    Declare @VolClient varchar(255)
    Declare @VolServer varchar(255)
    Declare @MyEMSLState tinyint

    Declare @FolderExists tinyint
    Declare @StoragePathClient varchar(512)
    Declare @StoragePathServer varchar(512)
    Declare @StoragePathResults varchar(512)
    Declare @SourceServerShare varchar(255)

    Declare @RequiredFileList varchar(max)    
    Declare @FileCountFound int
    Declare @FileCountMissing int
    Declare @FirstMissingFile varchar(512)
    
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
            SELECT TOP 1 @Job = Job,
                         @RequiredFileList = Required_File_List
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
                Set @MyEMSLState = 0
                Set @StoragePath = ''
                Set @DatasetFolder = ''
                Set @ResultsFolder = ''
                Set @Instrument = ''

                Set @StoragePathResults = ''
                Set @SourceServerShare = ''
                
                SELECT    @VolClient = Vol_Client, 
                        @VolServer = Vol_Server,
                        @MyEMSLState = MyEMSLState,
                        @StoragePath = Storage_Path,
                        @DatasetFolder = Dataset_Folder,  
                        @ResultsFolder = Results_Folder,
                        @Instrument = Instrument
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
                        
                        If @MyEMSLState > 0
                        Begin
                            -- Files reside in MyEMSL
                            -- If we cannot find the files on the Storage Server then we will need to download and cache them
                            -- Example path for @VolClient: \\MyEMSL\svc-dms\LTQ_1\2008_2\DatasetName\ResultsFolderName
                            
                            If @VolClient LIKE '\\a2.emsl.pnl.gov\dmsarch%'
                                set @VolClient = Replace(@VolClient, '\\a2.emsl.pnl.gov\dmsarch', '\\MyEMSL\svc-dms')
                            Else
                                set @VolClient = '\\MyEMSL\svc-dms\' + @Instrument + '\'

                        End
                        Else
                        Begin
                            -- File can be accessed via samba
                            -- Example path for @VolClient: \\a2.emsl.pnl.gov\dmsarch\LTQ_1\2008_2\DatasetName\ResultsFolderName
                            set @VolClient = @VolClient
                        End

                        -- Define the archive or MyEMSL storage path
                        set @StoragePathClient = dbo.udfCombinePaths(
                                                dbo.udfCombinePaths(
                                                dbo.udfCombinePaths(@VolClient, @StoragePath), @DatasetFolder), @ResultsFolder)
                        
                        -- Example path for @StoragePathServer: \\Proto-5\LTQ_1\2008_2\DatasetName\ResultsFolderName
                        set @StoragePathServer = dbo.udfCombinePaths(
                                                 dbo.udfCombinePaths(
                                                 dbo.udfCombinePaths(@VolServer, @StoragePath), @DatasetFolder), @ResultsFolder)

                        If Right(@StoragePathClient, 1) <> '\'
                            Set @StoragePathClient = @StoragePathClient + '\'
                            
                        If Right(@StoragePathServer, 1) <> '\'
                            Set @StoragePathServer = @StoragePathServer + '\'

                        -- Use @CheckLocalServerFirst to determine which path to check first
                        -- If the first path checked isn't found, then try the other path
                        -- If neither path is found, then leave @SourceServerShare empty
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
                                If @StoragePathClient LIKE '\\MyEMSL%'
                                Begin
                                            If @ShowDebugInfo > 0
                                        Print '@StoragePathClient starts with \\MyEMSL'
                                    Set @FolderExists = 1
                                End
                                Else
                                Begin
                                            If @ShowDebugInfo > 0
                                        Print 'Looking for @StoragePathClient ' + @StoragePathClient
                                    exec ValidateFolderExists @StoragePathClient, @CreateIfMissing = 0, @FolderExists = @FolderExists output
                                End
                                
                                If @FolderExists <> 0
                                Begin
                                            If @ShowDebugInfo > 0
                                        Print 'Folder exists: ' + @StoragePathClient
                                    Set @StoragePathResults = @StoragePathClient
                                    Set @SourceServerShare = @VolClient
                                End
                                        Else
                                        Begin
                                            If @ShowDebugInfo > 0
                                        Print 'Folder not found: ' + @StoragePathClient
                                        End
                            End
                        
                            If @FolderCheckIteration = 1
                            Begin
                                If @StoragePathServer LIKE '\\MyEMSL%'
                                Begin
                                    If @ShowDebugInfo > 0
                                        Print '@StoragePathServer starts with \\MyEMSL'
                                    Set @FolderExists = 1
                                End
                                Else
                                Begin
                                    If @ShowDebugInfo > 0
                                        Print 'Looking for @StoragePathServer ' + @StoragePathServer
                                    exec ValidateFolderExists @StoragePathServer, @CreateIfMissing = 0, @FolderExists = @FolderExists output
                                End
                                                                
                                If @FolderExists <> 0
                                Begin
                                    If @ShowDebugInfo > 0
                                        Print 'Folder exists: ' + @StoragePathServer
                                    Set @StoragePathResults = @StoragePathServer
                                    Set @SourceServerShare = @VolServer
                                End
                                Else
                                Begin
                                    If @ShowDebugInfo > 0
                                        Print 'Folder not found: ' + @StoragePathServer
                                End
                            End
                            
                            -- Note that we can only retrieve files from MyEMSL if @RequiredFileList contains one or more files
                            -- The MTS caching automation code does not support retrieval of *.*
                            
                            If @FolderExists <> 0 And IsNull(@RequiredFileList, '') <> ''
                            Begin
                                -- Also make sure the folder contains the required files
                                Declare @ValidateFiles tinyint = 1
                                
                                If @StoragePathResults LIKE '\\MyEMSL%'
                                Begin
                                    -- Set this to 0 for now; we'll change it back to 1 if @CacheState = 3                                    
                                    Set @ValidateFiles = 0
                                    
                                    Declare @CacheState tinyint
                                    Declare @LocalCacheFolderPath varchar(255)
                                    Declare @LocalResultsFolderPath varchar(512)
                                    
                                    If @ShowDebugInfo > 0
                                        Print 'Calling CacheMyEMSLFiles with ' + @RequiredFileList
                                    
                                    exec CacheMyEMSLFiles @Job, @RequiredFileList, 
                                                @CacheState = @CacheState output, 
                                                @LocalCacheFolderPath = @LocalCacheFolderPath output, 
                                                @LocalResultsFolderPath = @LocalResultsFolderPath output,
                                                @ShowDebugInfo=@ShowDebugInfo

                                    -- @CacheState values:
                                    -- State 0 means the Job is not in MyEMSL
                                    -- State 1 means the Job was added to the download queue (or was already in the download queue)
                                    -- State 2 means the Job's files are currently being cached
                                    -- State 3 means the specified files have been cached locally and are ready to use
                                    -- State 4 means there was an error caching the files locally (either a download error occurred, or over 24 hours has elapsed since the job was added to the queue)

                                    If @ShowDebugInfo > 0
                                    Begin
                                        Print 'Return values from CacheMyEMSLFiles'
                                        Print '  @CacheState = ' + convert(varchar(12), @CacheState)
                                        Print '  @LocalCacheFolderPath = ' + @LocalCacheFolderPath
                                        Print '  @LocalResultsFolderPath = ' + @LocalResultsFolderPath
                                    End
                                    
                                    If @CacheState IN (1,2)
                                    Begin
                                        -- Still waiting for files
                                        Set @StoragePathResults    = ''
                                    End
                                    
                                    If @CacheState = 3
                                    Begin
                                        -- Files have been cached and are ready to use
                                        -- Update the paths to be stored in #TmpResultsFolderPaths
                                        Set @StoragePathResults = @LocalResultsFolderPath
                                        Set @SourceServerShare = @LocalCacheFolderPath
                                        
                                        Set @ValidateFiles = 1
                                    End                                    
                                    
                                    If @CacheState <> 3
                                    Begin
                                        Set @FolderExists = 0
                                        Set @StoragePathResults = ''
                                        Set @SourceServerShare = ''
                                    End
                                    
                                End
                                
                                If @FolderExists <> 0 And @ValidateFiles = 1
                                Begin
                                    If @ShowDebugInfo > 0
                                        Print 'Looking for ' + @StoragePathServer
                                        
                                    exec ValidateFilesExist @StoragePathResults, @RequiredFileList, 
                                                @FileCountFound = @FileCountFound output, 
                                                @FileCountMissing = @FileCountMissing output, 
                                                @FirstMissingFile = @FirstMissingFile output, 
                                                @ShowDebugInfo=@ShowDebugInfo
                                    
                                    If @FileCountMissing > 0
                                    Begin
                                        Set @message = 'Storage folder is missing one or more required files, including ' + dbo.udfCombinePaths(@StoragePathResults, @FirstMissingFile)
                                        
                                        If @IterationCount = 0
                                            Exec PostLogEntry 'Warning', @message, 'LookupCurrentResultsFolderPathsByJob'
                                        Else
                                            Exec PostLogEntry 'Error', @message, 'LookupCurrentResultsFolderPathsByJob'
                                            
                                        set @message = ''
                                        Set @FolderExists = 0
                                    End
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
                            Source_Share = @SourceServerShare
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
GRANT VIEW DEFINITION ON [dbo].[LookupCurrentResultsFolderPathsByJob] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[LookupCurrentResultsFolderPathsByJob] TO [MTS_DB_Lite] AS [dbo]
GO
