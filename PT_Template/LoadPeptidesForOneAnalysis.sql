/****** Object:  StoredProcedure [dbo].[LoadPeptidesForOneAnalysis] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.LoadPeptidesForOneAnalysis
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
**
*****************************************************/
(
	@NextProcessState int = 20,
	@job int,
	@message varchar(255)='' OUTPUT,
	@numLoaded int=0 out,
	@clientStoragePerspective tinyint = 1,
	@infoOnly tinyint = 0
)
AS
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
		
	declare @completionCode int
	set @completionCode = 3				-- Set to state 'Load Failed' for now

	set @message = ''
	set @numLoaded = 0
	Set @infoOnly = IsNull(@infoOnly, 0)
	
	declare @jobStr varchar(12)
	set @jobStr = cast(@job as varchar(12))
	
	declare @result int
	declare @SynFileExtension varchar(32)
	
	declare @ResultToSeqMapFileExtension varchar(48)
	declare @SeqInfoFileExtension varchar(48)
	declare @SeqModDetailsFileExtension varchar(48)
	declare @SeqToProteinMapFileExtension varchar(48)
	declare @PeptideProphetFileExtension varchar(48)
        
	declare @ColumnCountExpected int
	declare @LineCountToSkip int

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
	Declare @Dataset  varchar(128)
	Declare @Campaign varchar(128)

	declare @StoragePathResults varchar(512)
	declare @SourceServer varchar(255)
		
	Set @Dataset = ''
	Set @Campaign = ''

	SELECT	@ResultType = ResultType,
			@Dataset = Dataset,
			@Campaign = Campaign
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
	    set @SynFileExtension = '_syn.txt'
	    set @ColumnCountExpected = 19

		set @ResultToSeqMapFileExtension = '_syn_ResultToSeqMap.txt'
		set @SeqInfoFileExtension = '_syn_SeqInfo.txt'
		set @SeqModDetailsFileExtension = '_syn_ModDetails.txt'
		set @SeqToProteinMapFileExtension = '_syn_SeqToProteinMap.txt'
		set @PeptideProphetFileExtension = '_syn_PepProphet.txt'
	End
	
	If @ResultType = 'XT_Peptide_Hit'
	Begin
	    set @SynFileExtension = '_xt.txt'
	    set @ColumnCountExpected = 16

		set @ResultToSeqMapFileExtension = '_xt_ResultToSeqMap.txt'
		set @SeqInfoFileExtension = '_xt_SeqInfo.txt'
		set @SeqModDetailsFileExtension = '_xt_ModDetails.txt'
		set @SeqToProteinMapFileExtension = '_xt_SeqToProteinMap.txt'
		set @PeptideProphetFileExtension = '_xt_PepProphet.txt'
	End

	If @ResultType = 'IN_Peptide_Hit'
	Begin
	    set @SynFileExtension = '_inspect_syn.txt'
	    set @ColumnCountExpected = 16

		set @ResultToSeqMapFileExtension = '_inspect_syn_ResultToSeqMap.txt'
		set @SeqInfoFileExtension = '_inspect_syn_SeqInfo.txt'
		set @SeqModDetailsFileExtension = '_inspect_syn_ModDetails.txt'
		set @SeqToProteinMapFileExtension = '_inspect_syn_SeqToProteinMap.txt'
		set @PeptideProphetFileExtension = ''
	End
	
	If @ColumnCountExpected = 0
	Begin
		set @message = 'Invalid result type ' + @ResultType + ' for job ' + @jobStr + '; should be Peptide_Hit, XT_Peptide_Hit, or IN_Peptide_Hit'
		set @myError = 60005
		goto Done
	End

	If @infoOnly <> 0
		SELECT  @Campaign AS Campaign,
				@Dataset AS Dataset,
				@job AS Job, 
				@FilterSetID AS Filter_Set_ID


	---------------------------------------------------
	-- Use LookupCurrentResultsFolderPathsByJob to get 
	-- the path to the analysis job results folder
	---------------------------------------------------
	--	
	CREATE TABLE #TmpResultsFolderPaths (
		Job INT NOT NULL,
		Results_Folder_Path varchar(512),
		Source_Share varchar(128)
	)

	INSERT INTO #TmpResultsFolderPaths (Job)
	VALUES (@Job)
	
	Exec LookupCurrentResultsFolderPathsByJob @clientStoragePerspective

	SELECT	@StoragePathResults = Results_Folder_Path,
			@SourceServer = Source_Share
	FROM #TmpResultsFolderPaths
	WHERE Job = @Job
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error

	If Len(IsNull(@StoragePathResults, '')) = 0
	Begin
		-- Results path is null; unable to continue
		Set @message = 'Unable to determine results folder path for job ' + @jobStr
		Set @myError = 60009
		Goto Done
	End

	DROP TABLE #TmpResultsFolderPaths

	-----------------------------------------------
	-- Set up input file names and paths
	-----------------------------------------------

	declare @RootFileName varchar(128)
 	declare @PeptideSynFilePath varchar(512)

	declare @PeptideResultToSeqMapFilePath varchar(512)
	declare @PeptideSeqInfoFilePath varchar(512)
	declare @PeptideSeqModDetailsFilePath varchar(512)
	declare @PeptideSeqToProteinMapFilePath varchar(512)
	declare @PeptideProphetResultsFilePath varchar(512)

	set @RootFileName = @Dataset
	set @PeptideSynFilePath = dbo.udfCombinePaths(@StoragePathResults, @RootFileName + @SynFileExtension)

	set @PeptideResultToSeqMapFilePath = dbo.udfCombinePaths(@StoragePathResults, @RootFileName + @ResultToSeqMapFileExtension)
	set @PeptideSeqInfoFilePath = dbo.udfCombinePaths(@StoragePathResults, @RootFileName + @SeqInfoFileExtension)
	set @PeptideSeqModDetailsFilePath = dbo.udfCombinePaths(@StoragePathResults, @RootFileName + @SeqModDetailsFileExtension)
	set @PeptideSeqToProteinMapFilePath = dbo.udfCombinePaths(@StoragePathResults, @RootFileName + @SeqToProteinMapFileExtension)
	set @PeptideProphetResultsFilePath = dbo.udfCombinePaths(@StoragePathResults, @RootFileName + @PeptideProphetFileExtension)

	Declare @fileExists tinyint
	Declare @columnCount int
	
	-----------------------------------------------
	-- Verify that the input file exists, count the number of columns, 
	-- and determine whether or not a header row is present
	-----------------------------------------------
	
	-- Set @LineCountToSkip to a negative value to instruct ValidateDelimitedFile to auto-determine whether or not a header row is present
	Set @LineCountToSkip = -1
	Exec @result = ValidateDelimitedFile @PeptideSynFilePath, @LineCountToSkip OUTPUT, @fileExists OUTPUT, @columnCount OUTPUT, @message OUTPUT, @ColumnToUseForNumericCheck = 1
	
	if @result <> 0
	Begin
		If Len(@message) = 0
			Set @message = 'Error calling ValidateDelimitedFile for ' + @PeptideSynFilePath + ' (Code ' + Convert(varchar(12), @result) + ')'
		
		Set @myError = 60003		
	End
	else
	Begin
		if @columnCount < @ColumnCountExpected
		begin
			If @columnCount = 0
			Begin
				Set @message = '0 peptides were loaded for job ' + @jobStr + ' (synopsis file is empty)'
				set @myError = 60002	-- Note that this error code is used in SP LoadResultsForAvailableAnalyses; do not change
			End
			Else
			Begin
				Set @message = 'Synopsis file only contains ' + convert(varchar(12), @columnCount) + ' columns for job ' + @jobStr + ' (Expecting ' + Convert(varchar(12), @ColumnCountExpected) + ' columns)'
				set @myError = 60003
			End
		end
	End
	
	-- don't do any more if errors at this point
	--
	if @myError <> 0 goto done


	-----------------------------------------------
	-- Load peptides from the synopsis or XTandem results file
	-- Also calls LoadSeqInfoAndModsPart1 and LoadSeqInfoAndModsPart2
	--  to load the results to sequence mapping, sequence info, 
	-- modification information, and sequence to protein mapping
	--  (if file @PeptideSeqInfoFilePath exists)
	-----------------------------------------------
	
	declare @loaded int,
			@peptideCountSkipped int,
			@SeqCandidateFilesFound tinyint,
			@PepProphetFileFound tinyint
			
	set @loaded = 0
	set @peptideCountSkipped = 0
	set @SeqCandidateFilesFound = 0
	set @PepProphetFileFound = 0

	If @infoOnly <> 0
	Begin
		SELECT  @LineCountToSkip AS LineCountToSkip,
				@PeptideResultToSeqMapFilePath AS PeptideResultToSeqMapFilePath,
				@PeptideSeqInfoFilePath AS PeptideSeqInfoFilePath,
				@PeptideSeqModDetailsFilePath AS PeptideSeqModDetailsFilePath,
				@PeptideSeqToProteinMapFilePath AS PeptideSeqToProteinMapFilePath,
				@PeptideProphetResultsFilePath AS PeptideProphetResultsFilePath

				
		Goto Done
	End
	Else
	Begin

		-- Set @result to an error code of 60005 (in case @ResultType is unknown)
		Set @result = 60005

		If @ResultType = 'Peptide_Hit'
		Begin
			exec @result = LoadSequestPeptidesBulk
							@PeptideSynFilePath,
							@PeptideResultToSeqMapFilePath,
							@PeptideSeqInfoFilePath,
							@PeptideSeqModDetailsFilePath,
							@PeptideSeqToProteinMapFilePath,
							@PeptideProphetResultsFilePath,
							@job, 
							@FilterSetID,
							@LineCountToSkip,
							@loaded output,
							@peptideCountSkipped output,
							@SeqCandidateFilesFound output,
							@PepProphetFileFound output,
							@message output
		End

		If @ResultType = 'XT_Peptide_Hit'
		Begin
			exec @result = LoadXTandemPeptidesBulk
							@PeptideSynFilePath,
							@PeptideResultToSeqMapFilePath,
							@PeptideSeqInfoFilePath,
							@PeptideSeqModDetailsFilePath,
							@PeptideSeqToProteinMapFilePath,
							@PeptideProphetResultsFilePath,
							@job, 
							@FilterSetID,
							@LineCountToSkip,
							@loaded output,
							@peptideCountSkipped output,
							@SeqCandidateFilesFound output,
							@PepProphetFileFound output,
							@message output
		End


		If @ResultType = 'IN_Peptide_Hit'
		Begin
			exec @result = LoadInspectPeptidesBulk
							@PeptideSynFilePath,
							@PeptideResultToSeqMapFilePath,
							@PeptideSeqInfoFilePath,
							@PeptideSeqModDetailsFilePath,
							@PeptideSeqToProteinMapFilePath,
							@job, 
							@FilterSetID,
							@LineCountToSkip,
							@loaded output,
							@peptideCountSkipped output,
							@SeqCandidateFilesFound output,
							@message output

			Set @PepProphetFileFound = 0
		End

	End
	
	--
	set @myError = @result
	IF @result = 0
	BEGIN
		-- set up success message
		--
		set @message = Convert(varchar(12), @loaded) + ' peptides were loaded for job ' + @jobStr + ' (Filtered out ' + Convert(varchar(12), @peptideCountSkipped) + ' peptides'
		
		If @FilterSetIDByCampaign <> 0 And @FilterSetID = @FilterSetIDByCampaign
			Set @message = @message + '; Filter_Set_ID = ' + Convert(varchar(12), @FilterSetID) + ', specific for campaign "' + @CampaignFilter + '")'
		Else
			Set @message = @message + '; Filter_Set_ID = ' + Convert(varchar(12), @FilterSetID) + ')'

		if @SeqCandidateFilesFound <> 0
			set @message = @message + '; using the T_Seq_Candidate tables'
		
		if @PepProphetFileFound <> 0
			set @message = @message + '; loaded Peptide Prophet data'

		-- Append the name of the server where the data was loaded from
		set @message = @message + '; Server: ' + IsNull(@SourceServer, '??')
			
		-- bump the load count
		--
		set @numLoaded = @loaded

		if @numLoaded > 0
			set @completionCode = @NextProcessState
		else
		begin
			-- All of the peptides were filtered out; load failed
			set @completionCode = 3
			set @myError = 60004			-- Note that this error code is used in SP LoadResultsForAvailableAnalyses; do not change
		end
	END

	-----------------------------------------------
	-- Exit
	-----------------------------------------------
Done:

	-- set load complete for this analysis
	--
	Exec SetProcessState @job, @completionCode
	
	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[LoadPeptidesForOneAnalysis] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[LoadPeptidesForOneAnalysis] TO [MTS_DB_Lite]
GO
