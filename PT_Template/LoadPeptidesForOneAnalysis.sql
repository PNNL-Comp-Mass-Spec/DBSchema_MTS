/****** Object:  StoredProcedure [dbo].[LoadPeptidesForOneAnalysis] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure [dbo].[LoadPeptidesForOneAnalysis]
/****************************************************
**
**	Desc: 
**		Loads all the peptides for the given analysis job
**		that have scores above the minimum thresholds.
**		Update's the job's state to @NextProcessState if success
**
**		Uses SP LoadSequestPeptidesBulk or SP LoadXTandemPeptidesBulk to bulk load the data
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	grk
**	Date:	11/11/2001
**			06/02/2004 mem - Updated to not change @myError from a non-zero value back to 0 after call to SetPeptideLoadComplete
**			07/03/2004 mem - Customized for loading Sequest results
**			07/14/2004 grk - Use new sequest peptide file extractor (discriminant scoring)
**			               - Eliminated code that created new synopsis file
**			07/21/2004 mem - Switched from using SetPeptideLoadComplete to SetProcessState
**			08/07/2004 mem - Added check for no peptides loaded for job
**			08/21/2004 mem - Removed @dt parameter from call to GetScoreThresholds
**			08/24/2004 mem - Switched to using the Peptide Import Filter Set ID from T_Process_Config
**			09/09/2004 mem - Added validation of the number of columns in the synopsis file
**			10/15/2004 mem - Moved file validation code to ValidateDelimitedFile
**			03/07/2005 mem - Updated to reflect changes to T_Process_Config that now use just one column to identify a configuration setting type
**			06/25/2005 mem - Reworded the error message posted when a synopsis file is empty
**			12/11/2005 mem - Renamed SP to LoadPeptidesForOneAnalysis and added support for XTandem results
**			01/15/2006 mem - Now passing @PeptideSeqInfoFilePath and @PeptideSeqModDetailsFilePath to LoadSequestPeptidesBulk and LoadXTandemPeptidesBulk
**						   - Now passing @LineCountToSkip=1 to ValidateDelimitedFile for XTandem results
**			01/25/2006 mem - Now including the Filter_Set_ID value used for peptide import when posting the success message to the log
**			02/13/2006 mem - Updated @ColumnCountExpected for XTandem results files to be 16 (was 17); change required because protein information is now stored in the _SeqToProteinMap.txt file
**						   - Now constructing paths for all four SeqInfo related files and passing to LoadSequestPeptidesBulk or LoadXTandemPeptidesBulk
**			06/04/2006 mem - Now passing @LineCountToSkip as an output parameter to let ValidateDelimitedFile determine whether or not a header row is present
**			07/18/2006 mem - Updated to use dbo.udfCombinePaths
**			08/01/2006 mem - Updated to define the Peptide Prophet results file path
**			08/10/2006 mem - Now updating the status message if using the Seq_Candidate tables and/or if Peptide Prophet data was loaded
**			03/20/2007 mem - Updated to look for the results folder at the Vol_Server location, and, if not found, return the Vol_Client location
**			04/16/2007 mem - Now using LookupCurrentResultsFolderPathsByJob to determine the results folder path (Ticket #423)
**			08/19/2008 mem - Added support for Peptide_Import_Filter_ID_by_Campaign in T_Process_Config
**			10/10/2008 mem - Added support for Inspect results (type IN_Peptide_Hit)
**			01/06/2009 mem - Increased @ColumnCountExpected to 25 for Inspect results (inspect Syn files should have 25 or 27 columns)
**			07/22/2009 mem - Added Try/Catch error handling
**			07/23/2010 mem - Added support for MSGF results
**			10/12/2010 mem - Now setting @completionCode to 9 when ValidateDelimitedFile returns a result code = 63 or when LoadSequestPeptidesBulk, LoadXTandemPeptidesBulk, or LoadInspectPeptidesBulk return 52099
**			08/19/2011 mem - Now passing @SynFileColumnCount and @SynFileHeader to LoadSequestPeptidesBulk, LoadXTandemPeptidesBulk, and LoadInspectPeptidesBulk
**			08/22/2011 mem - Added support for MSGFDB results (type MSG_Peptide_Hit)
**			09/01/2011 mem - Updated to use Result_File_Suffix in T_Analysis_Description to possibly override the default file suffix
**			11/21/2011 mem - Now populating Required_File_List in #TmpResultsFolderPaths
**			11/28/2011 mem - Now passing @ScanGroupInfoFilePath to LoadMSGFDBPeptidesBulk
**			12/23/2011 mem - Added switch @UpdateExistingData
**			12/29/2011 mem - Added call to ComputeMaxObsAreaByJob
**			12/30/2011 mem - Added call to LoadToolVersionInfoOneJob
**			12/04/2012 mem - Added support for MSAlign results (type MSA_Peptide_Hit)
**			12/06/2012 mem - Expanded @message to varchar(1024)
**			03/25/2013 mem - Now setting @completionCode to 5 if just one peptide is loaded
**			12/09/2013 mem - Now leaving the job state unchanged if the results folder path is empty but the job is present in MyEMSL
**			12/12/2013 mem - If the synopsis file needs to be cached from MyEMSL, then now calling LookupCurrentResultsFolderPathsByJob a second time to assure that the additional required files are cached
**						   - Added @showDebugInfo
**			11/28/2016 mem - Change the default file suffix for MGSF+ results to be _msgfplus (but still support _msgfdb)
**						   - Only call SetProcessState if @infoOnly is 0
**			10/11/2017 mem - Add "Auto-defined @ResultFileSuffix" debug statements
**
*****************************************************/
(
	@NextProcessState int = 20,
	@job int,
	@UpdateExistingData tinyint,
	@message varchar(1024)='' OUTPUT,
	@numLoaded int=0 out,
	@clientStoragePerspective tinyint = 1,
	@infoOnly tinyint = 0,
	@showDebugInfo tinyint = 0
	
)
AS
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
		
	declare @completionCode int = 3				-- Set to state 'Load Failed' for now

	-----------------------------------------------
	-- Validate the inputs
	-----------------------------------------------
	
	set @message = ''
	set @numLoaded = 0
	Set @UpdateExistingData = IsNull(@UpdateExistingData, 0)
	Set @infoOnly = IsNull(@infoOnly, 0)
	
	declare @jobStr varchar(12)
	set @jobStr = cast(@job as varchar(12))
	
	declare @result int
	declare @SynFileExtension varchar(32)
	declare @SynFileExtensionAlt varchar(32)
	
	Declare @RequiredFileList varchar(max)
	
	declare @ResultToSeqMapFileExtension varchar(48)
	declare @ResultToSeqMapFileExtensionAlt varchar(48)
	
	declare @SeqInfoFileExtension varchar(48)
	declare @SeqInfoFileExtensionAlt varchar(48)
	
	declare @SeqModDetailsFileExtension varchar(48)
	declare @SeqModDetailsFileExtensionAlt varchar(48)
	
	declare @SeqToProteinMapFileExtension varchar(48)
	declare @SeqToProteinMapFileExtensionAlt varchar(48)
	
	declare @PeptideProphetFileExtension varchar(48)
	
	declare @MSGFFileExtension varchar(48)
	declare @MSGFFileExtensionAlt varchar(48)
	
	declare @ScanGroupInfoFileExtension varchar(48) = ''
	declare @ScanGroupInfoFileExtensionAlt varchar(48) = ''
	
    declare @AnalysisToolName varchar(128)
    
	declare @ColumnCountExpected int
	declare @LineCountToSkip int

	Declare @ErrMsg varchar(256) = ''
	Declare @ReturnCode int
	
	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Begin Try

		-----------------------------------------------
		-- Get Peptide Import Filter Set ID
		-----------------------------------------------
		-- 
		--
		Declare @FilterSetID int
		Set @FilterSetID = 0
		
		SELECT TOP 1 @FiltersetID = Convert(int, Value)
		FROM T_Process_Config
		WHERE [Name] = 'Peptide_Import_Filter_ID'
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		if @FilterSetID = 0 Or @myRowCount = 0
		begin
			set @message = 'Could not get Peptide Import Filter Set ID for job ' + @jobStr
			set @myError = 60000
			goto Done
		end
		
		-----------------------------------------------
		-- Check for the existence of Peptide_Import_Filter_ID_by_Campaign
		-- If present, then parse out the campaign name and see if this job's campaign matches
		-- If it does, then use the Peptide_Import_Filter_ID_by_Campaign value instead of @FilterSetID
		-----------------------------------------------

		Declare @ValueText varchar(256)
		Declare @CampaignFilter varchar(128)
		Declare @FilterSetIDByCampaign int
		Declare @CommaLoc int
		
		Set @ValueText = ''
		Set @CampaignFilter = ''
		Set @FilterSetIDByCampaign = 0
		
		Set @ValueText = ''
		SELECT @ValueText = Value
		FROM T_Process_Config 
		WHERE [Name] = 'Peptide_Import_Filter_ID_by_Campaign'
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		If @myRowCount > 0 And Len(IsNull(@ValueText,'')) > 0
		Begin
			Set @CommaLoc = CharIndex(',', @ValueText)
			
			If @CommaLoc > 1
			Begin
				Set @CampaignFilter = LTRIM(RTRIM(Substring(@ValueText, @CommaLoc + 1, 256)))
				Set @FilterSetIDByCampaign = CONVERT(int, LTRIM(RTRIM(Substring(@ValueText, 1, @CommaLoc - 1))))			
			End
		End
		
		-----------------------------------------------
		-- Get result type, dataset name, and campaign for this job
		-----------------------------------------------
		Declare @ResultType varchar(64)
		Declare @Dataset  varchar(128) = ''
		Declare @Campaign varchar(128) = ''
		
		Declare @ResultFileSuffix varchar(32) = ''
		Declare @ResultFileSuffixAlt varchar(32) = ''
		
		declare @CurrentJobState int
		declare @MyEMSLState tinyint

		declare @StoragePathResults varchar(512)
		declare @SourceServer varchar(255)
			
		SELECT	@ResultType = ResultType,
				@Dataset = Dataset,
				@Campaign = Campaign,
				@ResultFileSuffix = IsNull(Result_File_Suffix, ''),
				@CurrentJobState = Process_State,
				@MyEMSLState = MyEMSLState
		FROM T_Analysis_Description
		WHERE (Job = @job)
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		If @myRowCount = 0 OR Len(IsNull(@Dataset, '')) = 0
		Begin
			set @message = 'Could not get dataset information for job ' + @jobStr
			set @myError = 60001
			goto Done
		End
		
		-- See if @Campaign matches @CampaignFilter
		-- If they do, update @FilterSetID; otherwise, set @FilterSetIDByCampaign to 0 so that we don't update the LogEntry below
		If @Campaign = @CampaignFilter
			Set @FilterSetID = @FilterSetIDByCampaign
		Else
			Set @FilterSetIDByCampaign = 0
			
		-- Validate ResultType and define the file extensions
		set @ColumnCountExpected = 0
		If @ResultType = 'Peptide_Hit'
		Begin
			If LTRIM(RTRIM(@ResultFileSuffix)) = ''
			Begin
				Set @ResultFileSuffix = '_syn'
				If @showDebugInfo > 0
					Print 'Auto-defined @ResultFileSuffix as ' + @ResultFileSuffix
			End
			
			set @SynFileExtension = @ResultFileSuffix + '.txt'
			set @ColumnCountExpected = 19			-- Sequest Synopsis files created after August 2011 will have 20 columns

			set @ResultToSeqMapFileExtension = @ResultFileSuffix + '_ResultToSeqMap.txt'
			set @SeqInfoFileExtension = @ResultFileSuffix + '_SeqInfo.txt'
			set @SeqModDetailsFileExtension = @ResultFileSuffix + '_ModDetails.txt'
			set @SeqToProteinMapFileExtension = @ResultFileSuffix + '_SeqToProteinMap.txt'
			set @PeptideProphetFileExtension = @ResultFileSuffix + '_PepProphet.txt'
			set @MSGFFileExtension = @ResultFileSuffix + '_MSGF.txt'
			
			set @AnalysisToolName = 'Sequest'
		End
		
		If @ResultType = 'XT_Peptide_Hit'
		Begin
			If LTRIM(RTRIM(@ResultFileSuffix)) = ''
			Begin
				Set @ResultFileSuffix = '_xt'
				If @showDebugInfo > 0
					Print 'Auto-defined @ResultFileSuffix as ' + @ResultFileSuffix
			End
				
			set @SynFileExtension = @ResultFileSuffix + '.txt'
			set @ColumnCountExpected = 16			-- X!Tandem _xt.txt files created after August 2011 will have 17 columns

			set @ResultToSeqMapFileExtension = @ResultFileSuffix + '_ResultToSeqMap.txt'
			set @SeqInfoFileExtension = @ResultFileSuffix + '_SeqInfo.txt'
			set @SeqModDetailsFileExtension = @ResultFileSuffix + '_ModDetails.txt'
			set @SeqToProteinMapFileExtension = @ResultFileSuffix + '_SeqToProteinMap.txt'
			set @PeptideProphetFileExtension = @ResultFileSuffix + '_PepProphet.txt'
			set @MSGFFileExtension = @ResultFileSuffix + '_MSGF.txt'
			
			set @AnalysisToolName = 'XTandem'
		End

		If @ResultType = 'IN_Peptide_Hit'
		Begin
			If LTRIM(RTRIM(@ResultFileSuffix)) = ''
			Begin
				Set @ResultFileSuffix = '_inspect_syn'
				If @showDebugInfo > 0
					Print 'Auto-defined @ResultFileSuffix as ' + @ResultFileSuffix
			End
				
			set @SynFileExtension = @ResultFileSuffix + '.txt'
			set @ColumnCountExpected = 25			-- Inspect synopsis files created after August 2011 will have 28 columns

			set @ResultToSeqMapFileExtension = @ResultFileSuffix + '_ResultToSeqMap.txt'
			set @SeqInfoFileExtension = @ResultFileSuffix + '_SeqInfo.txt'
			set @SeqModDetailsFileExtension = @ResultFileSuffix + '_ModDetails.txt'
			set @SeqToProteinMapFileExtension = @ResultFileSuffix + '_SeqToProteinMap.txt'
			set @PeptideProphetFileExtension = ''
			set @MSGFFileExtension = @ResultFileSuffix + '_MSGF.txt'
			
			set @AnalysisToolName = 'Inspect'
		End
		
		If @ResultType = 'MSG_Peptide_Hit'
		Begin
			If LTRIM(RTRIM(@ResultFileSuffix)) = ''
			Begin
				Set @ResultFileSuffix = '_msgfplus_syn'							
				Set @ResultFileSuffixAlt = '_msgfdb_syn'
				If @showDebugInfo > 0
					Print 'Auto-defined @ResultFileSuffix as ' + @ResultFileSuffix + ' (with an alternate of ' + @ResultFileSuffixAlt + ')'
			End

			set @SynFileExtension    = @ResultFileSuffix    + '.txt'
			set @SynFileExtensionAlt = @ResultFileSuffixAlt + '.txt'
			set @ColumnCountExpected = 17

			set @ResultToSeqMapFileExtension    = @ResultFileSuffix    + '_ResultToSeqMap.txt'
			set @ResultToSeqMapFileExtensionAlt = @ResultFileSuffixAlt + '_ResultToSeqMap.txt'

			set @SeqInfoFileExtension    = @ResultFileSuffix    + '_SeqInfo.txt'
			set @SeqInfoFileExtensionAlt = @ResultFileSuffixAlt + '_SeqInfo.txt'

			set @SeqModDetailsFileExtension    = @ResultFileSuffix    + '_ModDetails.txt'
			set @SeqModDetailsFileExtensionAlt = @ResultFileSuffixAlt + '_ModDetails.txt'

			set @SeqToProteinMapFileExtension    = @ResultFileSuffix    + '_SeqToProteinMap.txt'
			set @SeqToProteinMapFileExtensionAlt = @ResultFileSuffixAlt + '_SeqToProteinMap.txt'

			set @PeptideProphetFileExtension = ''

			set @MSGFFileExtension    = @ResultFileSuffix    + '_MSGF.txt'
			set @MSGFFileExtensionAlt = @ResultFileSuffixAlt + '_MSGF.txt'

			set @ScanGroupInfoFileExtension    = '_msgfplus_ScanGroupInfo.txt'
			set @ScanGroupInfoFileExtensionAlt = '_msgfdb_ScanGroupInfo.txt'
			
			-- Changed from MSGFDB to MSGFPlus in November 2016
			set @AnalysisToolName = 'MSGFPlus'
		End
		
		If @ResultType = 'MSA_Peptide_Hit'
		Begin
			If LTRIM(RTRIM(@ResultFileSuffix)) = ''
			Begin
				Set @ResultFileSuffix = '_msalign_syn'							
				If @showDebugInfo > 0
					Print 'Auto-defined @ResultFileSuffix as ' + @ResultFileSuffix
			End
				
			set @SynFileExtension = @ResultFileSuffix + '.txt'
			set @ColumnCountExpected = 20

			set @ResultToSeqMapFileExtension = @ResultFileSuffix + '_ResultToSeqMap.txt'
			set @SeqInfoFileExtension = @ResultFileSuffix + '_SeqInfo.txt'
			set @SeqModDetailsFileExtension = @ResultFileSuffix + '_ModDetails.txt'
			set @SeqToProteinMapFileExtension = @ResultFileSuffix + '_SeqToProteinMap.txt'
			set @PeptideProphetFileExtension = ''
			set @MSGFFileExtension = @ResultFileSuffix + '_MSGF.txt'				-- This file likely does not exist
			
			set @AnalysisToolName = 'MSAlign'
		End
		
		If @ColumnCountExpected = 0
		Begin
			set @message = 'Invalid result type ' + @ResultType + ' for job ' + @jobStr + '; should be Peptide_Hit, XT_Peptide_Hit, IN_Peptide_Hit, MSG_Peptide_Hit, or MSA_Peptide_Hit'
			set @myError = 60005
			goto Done
		End

		If @infoOnly <> 0
		Begin
			SELECT  @Campaign AS Campaign,
					@Dataset AS Dataset,
					@job AS Job, 
					@FilterSetID AS Filter_Set_ID
		End
		
		-----------------------------------------------
		-- Set up input file names
		-- For now we'll just have filenames
		-- We'll prepend with @StoragePathResults once that is known
		-----------------------------------------------
		
		Set @CurrentLocation = 'Set up input file names'

		declare @RootFileName varchar(128)
 		declare @PeptideSynFilePath varchar(512)
		declare @PeptideResultToSeqMapFilePath varchar(512)
		declare @PeptideSeqInfoFilePath varchar(512)
		declare @PeptideSeqModDetailsFilePath varchar(512)
		declare @PeptideSeqToProteinMapFilePath varchar(512)
		declare @PeptideProphetResultsFilePath varchar(512)
		declare @MSGFResultsFilePath varchar(512)		
		declare @ScanGroupInfoFilePath varchar(512)			-- Only used by MSGF+

		set @RootFileName = @Dataset
		set @PeptideSynFilePath = @RootFileName + @SynFileExtension
		set @PeptideResultToSeqMapFilePath = @RootFileName + @ResultToSeqMapFileExtension
		set @PeptideSeqInfoFilePath = @RootFileName + @SeqInfoFileExtension
		set @PeptideSeqModDetailsFilePath = @RootFileName + @SeqModDetailsFileExtension
		set @PeptideSeqToProteinMapFilePath = @RootFileName + @SeqToProteinMapFileExtension
		set @PeptideProphetResultsFilePath = @RootFileName + @PeptideProphetFileExtension
		set @MSGFResultsFilePath = @RootFileName + @MSGFFileExtension
				
		If @ScanGroupInfoFileExtension <> ''
			set @ScanGroupInfoFilePath = @RootFileName + @ScanGroupInfoFileExtension
		Else
			Set @ScanGroupInfoFilePath = ''

		---------------------------------------------------
		-- Use LookupCurrentResultsFolderPathsByJob to get 
		-- the path to the analysis job results folder
		---------------------------------------------------
		--	
		CREATE TABLE #TmpResultsFolderPaths (
			Job INT NOT NULL,
			Results_Folder_Path varchar(512),
			Source_Share varchar(128),
			Required_File_List varchar(max)
		)
		
		INSERT INTO #TmpResultsFolderPaths (Job, Required_File_List)
		VALUES (@Job, @PeptideSynFilePath)
		
		Set @CurrentLocation = 'Call LookupCurrentResultsFolderPathsByJob'
		Exec LookupCurrentResultsFolderPathsByJob @clientStoragePerspective, @showDebugInfo=@showDebugInfo

		Set @CurrentLocation = 'Determine results folder path'

		SELECT	@StoragePathResults = Results_Folder_Path,
				@SourceServer = Source_Share
		FROM #TmpResultsFolderPaths
		WHERE Job = @Job
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error


		If Len(IsNull(@StoragePathResults, '')) = 0 And @ResultFileSuffixAlt <> ''
		Begin
			-- Expected file not found, but an alternate file suffix is defined
			-- Search for the altnerate file now
			
			declare @PeptideSynFilePathAlt varchar(512) = @RootFileName + @SynFileExtensionAlt
			
			TRUNCATE TABLE #TmpResultsFolderPaths
			
			INSERT INTO #TmpResultsFolderPaths (Job, Required_File_List)
			VALUES (@Job, @PeptideSynFilePathAlt)
			
			Set @CurrentLocation = 'Call LookupCurrentResultsFolderPathsByJob (using alternate)'
			Exec LookupCurrentResultsFolderPathsByJob @clientStoragePerspective, @showDebugInfo=@showDebugInfo

			Set @CurrentLocation = 'Determine results folder path (using altnerate)'

			SELECT	@StoragePathResults = Results_Folder_Path,
					@SourceServer = Source_Share
			FROM #TmpResultsFolderPaths
			WHERE Job = @Job
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			
			If Len(IsNull(@StoragePathResults, '')) > 0
			Begin
				set @PeptideSynFilePath = @RootFileName + @SynFileExtensionAlt
				set @PeptideResultToSeqMapFilePath = @RootFileName + @ResultToSeqMapFileExtensionAlt
				set @PeptideSeqInfoFilePath = @RootFileName + @SeqInfoFileExtensionAlt
				set @PeptideSeqModDetailsFilePath = @RootFileName + @SeqModDetailsFileExtensionAlt
				set @PeptideSeqToProteinMapFilePath = @RootFileName + @SeqToProteinMapFileExtensionAlt
				set @MSGFResultsFilePath = @RootFileName + @MSGFFileExtensionAlt
			End
						
		End

		If Len(IsNull(@StoragePathResults, '')) = 0
		Begin
			If @showDebugInfo > 0
			Begin
				Print '@StoragePathResults is empty, meaning the one or more key files could not be found in the results folder'
			End
			
			If @MyEMSLState > 0
			Begin
				-- Files reside in MyEMSL
				-- They should have been added to the download queue
				Set @CompletionCode = @CurrentJobState
				Set @message = 'Waiting for files to be retrieved from MyEMSL for job ' + @jobStr
				-- Note that this error code is used by LoadResultsForAvailableAnalyses
				Set @myError = 60030
				
				If @showDebugInfo <> 0
					Print '@StoragePathResults is empty, but @MyEMSLState is > 0: ' + @message


				-- Need to queue the additional required files to be downloaded from MyEMSL
				--
				Set @RequiredFileList = @PeptideResultToSeqMapFilePath + ',' + @PeptideSeqInfoFilePath + ',' + @PeptideSeqModDetailsFilePath + ',' + @PeptideSeqToProteinMapFilePath
				
				If @AnalysisToolName = 'Sequest'
					Set @RequiredFileList = @RequiredFileList + ',Optional:' + @PeptideProphetResultsFilePath
				
				Set @RequiredFileList = @RequiredFileList + ',' + @MSGFResultsFilePath
		
				if @ScanGroupInfoFilePath <> ''
					Set @RequiredFileList = @RequiredFileList + ',Optional:' + @ScanGroupInfoFilePath
				
				
				-- Add the tool version info files
				Set @RequiredFileList = @RequiredFileList + ',Optional:Tool_Version_Info_' + @AnalysisToolName + '.txt'
				
				If @AnalysisToolName = 'MSGFPlus'
				Begin
					-- Add this file for legacy job results
					Set @RequiredFileList = @RequiredFileList + ',Optional:Tool_Version_Info_MSGFDB.txt'
				End
				
				Set @RequiredFileList = @RequiredFileList + ',Optional:Tool_Version_Info_DataExtractor.txt'
				Set @RequiredFileList = @RequiredFileList + ',Optional:Tool_Version_Info_MSGF.txt'
				
				TRUNCATE TABLE #TmpResultsFolderPaths

				INSERT INTO #TmpResultsFolderPaths (Job, Required_File_List)
				VALUES (@Job, @RequiredFileList)
				
				Set @CurrentLocation = 'Call LookupCurrentResultsFolderPathsByJob for additional files'
				Exec LookupCurrentResultsFolderPathsByJob @clientStoragePerspective, @showDebugInfo=@showDebugInfo

			End
			Else
			Begin
				-- Results path is null; unable to continue
				Set @message = 'Unable to determine results folder path for job ' + @jobStr
				Set @myError = 60009
				
				If @showDebugInfo <> 0
					Print '@StoragePathResults is empty (and @MyEMSLState is 0): ' + @message

			End
			
			Goto Done
		End

		DROP TABLE #TmpResultsFolderPaths

		-----------------------------------------------
		-- Set up input file paths
		-----------------------------------------------
		
		Set @CurrentLocation = 'Set up input file paths'

		set @PeptideSynFilePath = dbo.udfCombinePaths(@StoragePathResults, @PeptideSynFilePath)

		set @PeptideResultToSeqMapFilePath = dbo.udfCombinePaths(@StoragePathResults, @PeptideResultToSeqMapFilePath)
		set @PeptideSeqInfoFilePath = dbo.udfCombinePaths(@StoragePathResults, @PeptideSeqInfoFilePath)
		set @PeptideSeqModDetailsFilePath = dbo.udfCombinePaths(@StoragePathResults, @PeptideSeqModDetailsFilePath)
		set @PeptideSeqToProteinMapFilePath = dbo.udfCombinePaths(@StoragePathResults, @PeptideSeqToProteinMapFilePath)
		set @PeptideProphetResultsFilePath = dbo.udfCombinePaths(@StoragePathResults, @PeptideProphetResultsFilePath)
		set @MSGFResultsFilePath = dbo.udfCombinePaths(@StoragePathResults, @MSGFResultsFilePath)
				
		If @ScanGroupInfoFilePath <> ''
			set @ScanGroupInfoFilePath = dbo.udfCombinePaths(@StoragePathResults, @ScanGroupInfoFilePath)

		-----------------------------------------------
		-- Verify that the input file exists, count the number of columns, 
		--  and determine whether or not a header row is present
		-- Output parameter @SynFileHeader will contain the header row (if present)
		-----------------------------------------------

		Declare @fileExists tinyint
		Declare @SynFileColumnCount int
		Declare @SynFileHeader varchar(2048) = ''
		
		Set @CurrentLocation = 'Call ValidateDelimitedFile'
		
		If @showDebugInfo <> 0
			Print 'Calling ValidateDelimitedFile for ' + @PeptideSynFilePath
			
		-- Set @LineCountToSkip to a negative value to instruct ValidateDelimitedFile to auto-determine whether or not a header row is present
		Set @LineCountToSkip = -1
		Exec @result = ValidateDelimitedFile @PeptideSynFilePath, @LineCountToSkip OUTPUT, @fileExists OUTPUT, @SynFileColumnCount OUTPUT, @message OUTPUT, @ColumnToUseForNumericCheck = 1, @HeaderLine=@SynFileHeader OUTPUT
		
		Set @myError = 0
		if @result <> 0
		Begin
			If Len(@message) = 0
				Set @message = 'Error calling ValidateDelimitedFile for ' + @PeptideSynFilePath + ' (Code ' + Convert(varchar(12), @result) + ')'

			if @result = 63
				-- OpenTextFile was unable to open the file
				-- Set the completion code to 9, meaning we want to retry the load
				set @completionCode = 9

			Set @myError = 60003		
		End
		else
		Begin
			if @SynFileColumnCount < @ColumnCountExpected
			begin
				If @SynFileColumnCount = 0
				Begin
					Set @message = '0 peptides were loaded for job ' + @jobStr + ' (synopsis file is empty)'
					set @myError = 60002	-- Note that this error code is used in SP LoadResultsForAvailableAnalyses; do not change
				End
				Else
				Begin
					Set @message = 'Synopsis file only contains ' + convert(varchar(12), @SynFileColumnCount) + ' columns for job ' + @jobStr + ' (Expecting at least ' + Convert(varchar(12), @ColumnCountExpected) + ' columns)'
					set @myError = 60003
				End
			end
		End
		
		-- don't do any more if errors at this point
		--
		if @myError <> 0 goto done


		-----------------------------------------------
		-- Load peptides from the synopsis file, XTandem results file, Inspect results file, MSGFPlus results file, or MSAlign results file
		-- Also calls LoadSeqInfoAndModsPart1 and LoadSeqInfoAndModsPart2
		--  to load the results to sequence mapping, sequence info, 
		-- modification information, and sequence to protein mapping
		--  (if file @PeptideSeqInfoFilePath exists)
		-----------------------------------------------
		
		Set @CurrentLocation = 'Load peptides'
		
		declare @loaded int,
				@peptideCountSkipped int,
				@SeqCandidateFilesFound tinyint,
				@PepProphetFileFound tinyint,
				@MSGFFileFound tinyint
				
		set @loaded = 0
		set @peptideCountSkipped = 0
		set @SeqCandidateFilesFound = 0
		set @PepProphetFileFound = 0
		set @MSGFFileFound = 0

		If @infoOnly <> 0
		Begin
			SELECT @LineCountToSkip AS LineCountToSkip,
			      @SynFileColumnCount AS SynFileColumnCount,
			       @SynFileHeader AS SynFileHeader,
			       @PeptideResultToSeqMapFilePath AS PeptideResultToSeqMapFilePath,
			       @PeptideSeqInfoFilePath AS PeptideSeqInfoFilePath,
			       @PeptideSeqModDetailsFilePath AS PeptideSeqModDetailsFilePath,
			       @PeptideSeqToProteinMapFilePath AS PeptideSeqToProteinMapFilePath,
			       @PeptideProphetResultsFilePath AS PeptideProphetResultsFilePath,
			       @MSGFResultsFilePath AS MSGFResultsFilePath
		End

		-- Set @result to an error code of 60005 (in case @ResultType is unknown)
		Set @result = 60005

		If @ResultType = 'Peptide_Hit'
		Begin
			Set @CurrentLocation = 'Call LoadSequestPeptidesBulk'
			If @infoOnly = 0
			Begin
				exec @result = LoadSequestPeptidesBulk
								@PeptideSynFilePath,
								@PeptideResultToSeqMapFilePath,
								@PeptideSeqInfoFilePath,
								@PeptideSeqModDetailsFilePath,
								@PeptideSeqToProteinMapFilePath,
								@PeptideProphetResultsFilePath,
								@MSGFResultsFilePath,
								@job, 
								@FilterSetID,
								@LineCountToSkip,
								@SynFileColumnCount,
								@SynFileHeader,
								@UpdateExistingData,
								@loaded output,
								@peptideCountSkipped output,
								@SeqCandidateFilesFound output,
								@PepProphetFileFound output,
								@MSGFFileFound output,
								@message output
			End
		End

		If @ResultType = 'XT_Peptide_Hit'
		Begin
			Set @CurrentLocation = 'Call LoadXTandemPeptidesBulk'
			If @infoOnly = 0
			Begin
				exec @result = LoadXTandemPeptidesBulk
								@PeptideSynFilePath,
								@PeptideResultToSeqMapFilePath,
								@PeptideSeqInfoFilePath,
								@PeptideSeqModDetailsFilePath,
								@PeptideSeqToProteinMapFilePath,
								@PeptideProphetResultsFilePath,
								@MSGFResultsFilePath,
								@job, 
								@FilterSetID,
								@LineCountToSkip,
								@SynFileColumnCount,
								@SynFileHeader,
								@UpdateExistingData,
								@loaded output,
								@peptideCountSkipped output,
								@SeqCandidateFilesFound output,
								@PepProphetFileFound output,
								@MSGFFileFound output,
								@message output
			End
		End


		If @ResultType = 'IN_Peptide_Hit'
		Begin
			Set @CurrentLocation = 'Call LoadInspectPeptidesBulk'
			If @infoOnly = 0
			Begin
				exec @result = LoadInspectPeptidesBulk
								@PeptideSynFilePath,
								@PeptideResultToSeqMapFilePath,
								@PeptideSeqInfoFilePath,
								@PeptideSeqModDetailsFilePath,
								@PeptideSeqToProteinMapFilePath,
								@MSGFResultsFilePath,
								@job, 
								@FilterSetID,
								@LineCountToSkip,
								@SynFileColumnCount,
								@SynFileHeader,
								@UpdateExistingData,
								@loaded output,
								@peptideCountSkipped output,
								@SeqCandidateFilesFound output,
								@MSGFFileFound output,
								@message output
			End
			
			Set @PepProphetFileFound = 0
		End

		If @ResultType = 'MSG_Peptide_Hit'
		Begin
			Set @CurrentLocation = 'Call LoadMSGFDBPeptidesBulk'
			If @infoOnly = 0
			Begin
				exec @result = LoadMSGFDBPeptidesBulk
								@PeptideSynFilePath,
								@PeptideResultToSeqMapFilePath,
								@PeptideSeqInfoFilePath,
								@PeptideSeqModDetailsFilePath,
								@PeptideSeqToProteinMapFilePath,
								@MSGFResultsFilePath,
								@ScanGroupInfoFilePath,
								@job, 
								@FilterSetID,
								@LineCountToSkip,
								@SynFileColumnCount,
								@SynFileHeader,
								@UpdateExistingData,
								@loaded output,
								@peptideCountSkipped output,
								@SeqCandidateFilesFound output,
								@MSGFFileFound output,
								@message output
			End
			
			Set @PepProphetFileFound = 0
		End

		If @ResultType = 'MSA_Peptide_Hit'
		Begin
			Set @CurrentLocation = 'Call LoadMSAlignPeptidesBulk'
			exec @result = LoadMSAlignPeptidesBulk
							@PeptideSynFilePath,
							@PeptideResultToSeqMapFilePath,
							@PeptideSeqInfoFilePath,
							@PeptideSeqModDetailsFilePath,
							@PeptideSeqToProteinMapFilePath,
							@MSGFResultsFilePath,
							@job, 
							@FilterSetID,
							@LineCountToSkip,
							@SynFileColumnCount,
							@SynFileHeader,
							@UpdateExistingData,
							@loaded output,
							@peptideCountSkipped output,
							@SeqCandidateFilesFound output,
							@MSGFFileFound output,
							@message output,
							@infoOnly = @infoOnly

			Set @PepProphetFileFound = 0
		End

		If @infoOnly = 0
		Begin -- <a>
			Set @CurrentLocation = 'Evaluate return code from Load...PeptidesBulk'
			
			If @result = 52099
				-- OpenTextFile was unable to open the file
				-- Set the completion code to 9, meaning we want to retry the load
				Set @completioncode = 9

			--
			Set @myError = @result
			If @result = 0
			Begin -- <b>
				-----------------------------------------------
				-- set up success message
				-----------------------------------------------
				--
				Declare @Action varchar(24)
				
				If @UpdateExistingData > 0
					set @Action = 'updated'
				Else
					set @Action = 'loaded'
				
				set @message = Convert(varchar(12), @loaded) + ' peptides were ' + @Action + ' for job ' + @jobStr + ' (Filtered out ' + Convert(varchar(12), @peptideCountSkipped) + ' peptides'
				
				If @FilterSetIDByCampaign <> 0 And @FilterSetID = @FilterSetIDByCampaign
					Set @message = @message + '; Filter_Set_ID = ' + Convert(varchar(12), @FilterSetID) + ', specific for campaign "' + @CampaignFilter + '")'
				Else
					Set @message = @message + '; Filter_Set_ID = ' + Convert(varchar(12), @FilterSetID) + ')'

				if @SeqCandidateFilesFound <> 0
					set @message = @message + '; using the T_Seq_Candidate tables'
				
				if @PepProphetFileFound <> 0
					set @message = @message + '; loaded Peptide Prophet data'
					
				if @MSGFFileFound <> 0
					set @message = @message + '; loaded MSGF data'

				-- Append the name of the server where the data was loaded from
				set @message = @message + '; Server: ' + IsNull(@SourceServer, '??')
					
				-- bump the load count
				--
				set @numLoaded = @loaded

				if @numLoaded > 1
					set @completionCode = @NextProcessState
				else
				begin
					if @numLoaded = 0
						-- All of the peptides were filtered out; load failed
						set @completionCode = 3
					else
						-- Only one peptide was loaded
						set @completionCode = 5
			
					set @myError = 60004			-- Note that this error code is used in SP LoadResultsForAvailableAnalyses; do not change
				end
				
				-----------------------------------------------
				-- Load and store the Tool Version Info
				-- If an error occurs, LoadToolVersionInfoOneJob will log the error
				-----------------------------------------------
				--
				exec @ReturnCode = LoadToolVersionInfoOneJob @Job, @AnalysisToolName, @StoragePathResults
				
				If @UpdateExistingData > 0
				Begin
					-----------------------------------------------
					-- Updated existing data; perform some additional tasks
					-----------------------------------------------
					--
					-- Delete this job from T_Analysis_Filter_Flags
					DELETE FROM T_Analysis_Filter_Flags
					WHERE (Job = @job)
					
					-- Make sure Max_Obs_Area_In_Job is up-to-date in T_Peptides
					exec @ReturnCode = ComputeMaxObsAreaByJob @message=@ErrMsg output, @JobFilterList=@JobStr, @infoOnly=0, @PostLogEntryOnSuccess=0
					
					if @ReturnCode <> 0
					Begin
						set @ErrMsg = 'Error calling ComputeMaxObsAreaByJob for job ' + @JobStr + ': ' + @ErrMsg
						exec PostLogEntry 'Error', @ErrMsg, 'LoadPeptidesForOneAnalysis'
					End
					
				End
				
			End  -- </b>
		End  -- </a>

	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'LoadPeptidesForOneAnalysis')
		Set @CurrentLocation = @CurrentLocation + '; job ' + @jobStr
		
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, @LogWarningErrorList = '',
								@ErrorNum = @myError output, @message = @message output

		Set @completionCode = 3
			
		If @myError = 0
			Set @myError = 60010
	End Catch	

	-----------------------------------------------
	-- Exit
	-----------------------------------------------
Done:

	If @infoOnly = 0 And @completionCode <> @CurrentJobState
	Begin
		-- Update the process state for this job
		--
		Exec SetProcessState @job, @completionCode
	End

	
	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[LoadPeptidesForOneAnalysis] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[LoadPeptidesForOneAnalysis] TO [MTS_DB_Lite] AS [dbo]
GO
