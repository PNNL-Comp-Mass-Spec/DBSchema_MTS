/****** Object:  StoredProcedure [dbo].[LoadMASICResultsForOneAnalysis] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.LoadMASICResultsForOneAnalysis
/****************************************************
**
**	Desc: 
**		Loads the MASIC results for the given MASIC job
**
**	Parameters:
**
**	Auth:	mem
**	Date:	12/13/2004
**			12/29/2004 mem - Now setting Process_State to 3 if an error occurs in LoadMASICScanStatsBulk or LoadMASICSICStatsBulk
**			01/25/2005 mem - Now checking for datasets associated with @job that already have a SIC_Job defined
**			10/31/2005 mem - Now passing @SICStatsColumnCount to LoadMASICSICStatsBulk
**			11/06/2005 mem - Switched alternate SICStats column count from 22 to 25 columns
**			11/10/2005 mem - Now looking for PeptideHit jobs with state > 25 for the dataset associated with this SIC Job; if any are found, then they are reset to state 25 or state 35
**			12/13/2005 mem - Updated to support XTandem results
**			06/04/2006 mem - Now passing @ScanStatsLineCountToSkip as an output parameter to let ValidateDelimitedFile determine whether or not a header row is present
**			07/18/2006 mem - Updated to use dbo.udfCombinePaths
**    
*****************************************************/
(
	@NextProcessState int = 75,
	@job int,
	@message varchar(255)='' OUTPUT,
	@numLoaded int=0 OUTPUT,
	@clientStoragePerspective tinyint = 1
)
AS
	set nocount on

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
		
	declare @completionCode int
	set @completionCode = 3				-- Set to state 'Load Failed' for now

	set @message = ''
	set @numLoaded = 0

	declare @messageAddnl varchar(255)
	set @messageAddnl = ''
	
	declare @jobStr varchar(12)
	set @jobStr = cast(@job as varchar(12))
	
	declare @result int
	

	-----------------------------------------------
	-- Get file information from analysis
	-----------------------------------------------
	declare @Dataset  varchar(128)
	declare @DatasetID int
	declare @Path varchar(255)
	declare @DatasetFolder varchar(255)
	declare @ResultsFolder varchar(255)
	declare @VolClient varchar(255)
	declare @VolServer varchar(255)
	declare @StoragePath varchar(255)
	
	set @Dataset = ''

	SELECT 
		@Dataset = Dataset, 
		@DatasetID = Dataset_ID,
		@VolClient = Vol_Client, 
		@VolServer = Vol_Server,
		@Path = Storage_Path,
		@DatasetFolder = Dataset_Folder,  
		@ResultsFolder = Results_Folder
	FROM T_Analysis_Description
	WHERE (Job = @job)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @Dataset = ''
	begin
		set @message = 'Could not get file information for job ' + @jobStr
		set @myError = 60001
		goto Done
	end
	
	If @clientStoragePerspective <> 0
		set @StoragePath = @VolClient + @Path + @DatasetFolder
	Else
		set @StoragePath = @VolServer + @Path + @DatasetFolder

	-----------------------------------------------
	-- Set up input file names and paths
	-----------------------------------------------

	DECLARE @RootFileName varchar(128)
	DECLARE @ResultsPath varchar(512)
 	DECLARE @ScanStatsFile varchar(255)
 	DECLARE @ScanStatsFilePath varchar(512)
 	DECLARE @SICStatsFile varchar(255)
 	DECLARE @SICStatsFilePath varchar(512)
	
	set @RootFileName = @Dataset
	set @ResultsPath = dbo.udfCombinePaths(@StoragePath, @ResultsFolder)
    set @ScanStatsFile = @RootFileName + '_ScanStats.txt'
	set @ScanStatsFilePath = dbo.udfCombinePaths(@ResultsPath, @ScanStatsFile)

    set @SICStatsFile = @RootFileName + '_SICStats.txt'
	set @SICStatsFilePath = dbo.udfCombinePaths(@ResultsPath, @SICStatsFile)


	Declare @ScanStatsFileExists tinyint
	Declare @SICStatsFileExists tinyint
	Declare @ScanStatsColumnCount int
	Declare @SICStatsColumnCount int
	
	Declare @ScanStatsLineCountToSkip int
	Declare @SICStatsLineCountToSkip int
	
	-----------------------------------------------
	-- Verify that the ScanStats file exists and count the number of columns
	-----------------------------------------------
	-- Set @ScanStatsLineCountToSkip to a negative value to instruct ValidateDelimitedFile to auto-determine whether or not a header row is present
	Set @ScanStatsLineCountToSkip = -1
	Exec @result = ValidateDelimitedFile @ScanStatsFilePath, @ScanStatsLineCountToSkip OUTPUT, @ScanStatsFileExists OUTPUT, @ScanStatsColumnCount OUTPUT, @message OUTPUT, @ColumnToUseForNumericCheck = 2
	
	if @result <> 0
	Begin
		If Len(@message) = 0
			Set @message = 'Error calling ValidateDelimitedFile for ' + @ScanStatsFilePath + ' (Code ' + Convert(varchar(11), @result) + ')'
		
		Set @myError = 60003		
	End
	else
	Begin
		if @ScanStatsColumnCount < 8
		begin
			If @ScanStatsColumnCount = 0
			Begin
				Set @message = 'ScanStats file is empty for job ' + @jobStr
				set @myError = 60002	-- Note that this error code is used in SP LoadResultsForAvailableAnalyses; do not change
			End
			Else
			Begin
				Set @message = 'ScanStats file only contains ' + convert(varchar(11), @ScanStatsColumnCount) + ' columns for job ' + @jobStr + ' (Expecting 8 columns)'
				set @myError = 60003
			End
		end
	End
	
	-- don't do any more if errors at this point
	--
	if @myError <> 0 goto done


	-----------------------------------------------
	-- See if the SICStats file exists and count the number of columns
	-- The SICStats file is not required to exist to continue; but, if it does exist, it must have the required number of columns
	-----------------------------------------------
	-- Set @SICStatsLineCountToSkip to a negative value to instruct ValidateDelimitedFile to auto-determine whether or not a header row is present
	Set @SICStatsLineCountToSkip = -1
	Exec @result = ValidateDelimitedFile @SICStatsFilePath, @SICStatsLineCountToSkip OUTPUT, @SICStatsFileExists OUTPUT, @SICStatsColumnCount OUTPUT, @message OUTPUT, @ColumnToUseForNumericCheck = 2
	
	if @result <> 0
	Begin
		If Len(@message) = 0
			Set @message = 'Error calling ValidateDelimitedFile for ' + @SICStatsFilePath + ' (Code ' + Convert(varchar(11), @result) + ')'
		
		Set @myError = 60003		
	End
	else
	Begin
		if @SICStatsColumnCount < 15
		begin
			If @SICStatsColumnCount = 0
			Begin
				Set @message = 'SICStats file is empty for job ' + @jobStr
				Set @SICStatsFileExists = 0
			End
			Else
			Begin
				Set @message = 'SICStats file only contains ' + convert(varchar(11), @SICStatsColumnCount) + ' columns for job ' + @jobStr + ' (Expecting 15 or 25 columns)'
				set @myError = 60003
			End
		end
	End
	
	-- don't do any more if errors at this point
	--
	if @myError <> 0 goto done


	-----------------------------------------------
	-- Load results from ScanStats file
	-----------------------------------------------
	
	declare @ScanStatsLoaded int
	set @ScanStatsLoaded = 0
	
	exec @result = LoadMASICScanStatsBulk
						@ScanStatsFilePath,
						@job,
						@ScanStatsLineCountToSkip,
						@ScanStatsLoaded output,
						@message output
	--
	set @myError = @result
	IF @result = 0
	BEGIN
		-- set up success message
		--
		set @message = cast(@ScanStatsLoaded as varchar(12)) + ' scans were loaded for job ' + @jobStr

		-- bump the load count
		--
		set @numLoaded = @ScanStatsLoaded

		if @numLoaded > 0
			set @completionCode = @NextProcessState
		else
		begin
			-- No results were loaded; load failed
			set @completionCode = 3
			set @myError = 60004			-- Note that this error code is used in SP LoadResultsForAvailableAnalyses; do not change
			Goto Done
		end
	END
	Else
	Begin
		-- Error inserting results; load failed
		set @completionCode = 3
		set @myError = 60005
		Goto Done
	End

	-----------------------------------------------
	-- Load results from SICStats file
	-----------------------------------------------
	
	declare @SICStatsLoaded int
	set @SICStatsLoaded = 0
	
	If @SICStatsFileExists = 1
	Begin
		exec @result = LoadMASICSICStatsBulk
							@SICStatsFilePath,
							@job,
							@SICStatsColumnCount,
							@SICStatsLineCountToSkip,
							@SICStatsLoaded output,
							@messageAddnl output
		--
		set @myError = @result
		IF @result = 0
		BEGIN
			-- set up success message
			--
			set @messageAddnl = cast(@SICStatsLoaded as varchar(12)) + ' SIC entries were loaded for job ' + @jobStr
			set @message = @message + '; ' + @messageAddnl

			-- bump the load count
			--
			set @numLoaded = @numLoaded + @SICStatsLoaded

			if @numLoaded > 0
				set @completionCode = @NextProcessState
		END
		Else
		Begin
			-- Error inserting results; load failed
			set @completionCode = 3
			set @myError = 60006
			Goto Done
		End
	End
	Else
		Set @message = @message + '; SIC Stats file was empty for job ' + @jobStr


	-----------------------------------------------
	-- If @completionCode = @NextProcessState then need to see if this job's dataset
	-- in T_Datasets has a SIC_Job defined that isn't this job; if found, then update
	-- T_Datasets to point to the largest SIC_Job in T_Analysis_Description (possibly this job, possibly not)
	-----------------------------------------------
	
	set @result = 0
	SELECT @result = enabled FROM T_Process_Step_Control WHERE (Processing_Step_Name = 'UpdateDatasetToSICMapping')
	If @result = 1 AND @completionCode = @NextProcessState
	begin

		Declare @DefinedSICJob int
		Set @DefinedSICJob = 0
		
		SELECT @DefinedSICJob = SIC_Job
		FROM T_Datasets
		WHERE Dataset_ID = @DatasetID AND
			NOT SIC_Job Is Null
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		If @myRowcount = 1 And @DefinedSICJob <> @Job
		Begin
			-- Need to assure T_Datasets points to the largest SIC_Job in T_Analysis_Description
			-- This won't occur in MasterUpdateDatasets since T_Datasets already has 
			-- a SIC_Job a job defined for the dataset

			UPDATE T_Datasets
			SET SIC_Job = LookupQ.SIC_Job
			FROM T_Datasets INNER JOIN
				(	SELECT Dataset_ID, Max(Job) As SIC_Job
					FROM T_Analysis_Description
					WHERE (	ResultType = 'SIC' AND 
							Dataset_ID = @DatasetID AND
							Process_State = @NextProcessState
						  )	OR Job = @Job
					GROUP BY Dataset_ID
				) As LookupQ ON
				T_Datasets.Dataset_ID = LookupQ.Dataset_ID
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error

			Declare @DSMappingMessage varchar(256)
			set @DSMappingMessage = 'Updated mapping between dataset and SIC Job for dataset ' + convert(varchar(11), @DatasetID)
			
			If @myRowCount > 0
				execute PostLogEntry 'Normal', @DSMappingMessage, 'LoadMASICResultsForOneAnalysis'
			
		End
	end

	-----------------------------------------------
	-- If @completionCode = @NextProcessState then need to see if this job's dataset
	-- has any Peptide_Hit jobs with state > 25.  If there are, then need to reset
	-- the state for those jobs back to 25 or 35
	-----------------------------------------------
	
	If @completionCode = @NextProcessState
	begin
		UPDATE T_Analysis_Description
		SET Process_State = CASE WHEN TAD.Process_State > 35 THEN 35 ELSE 25 END,
			Last_Affected = GetDate()
		FROM T_Analysis_Description AS TAD INNER JOIN
				(	SELECT Dataset_ID
					FROM T_Analysis_Description
					WHERE Job = @Job) AS SIC_Job_Q ON 
			TAD.Dataset_ID = SIC_Job_Q.Dataset_ID
		WHERE TAD.ResultType LIKE '%Peptide_Hit' AND 
			  TAD.Process_State > 25
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		Declare @PeptideHitResetMessage varchar(256)

		If @myRowCount = 1
			set @PeptideHitResetMessage = 'Reset 1 analysis job due to updated SIC stats for job ' + @jobStr
		Else
			set @PeptideHitResetMessage = 'Reset ' + convert(varchar(11), @myRowCount) + ' analysis jobs due to updated SIC stats for job ' + @jobStr
		
		If @myRowCount > 0
			execute PostLogEntry 'Normal', @PeptideHitResetMessage, 'LoadMASICResultsForOneAnalysis'
    		
	end


	-----------------------------------------------
	-- Exit
	-----------------------------------------------
Done:

	-- set load complete for this analysis
	--
	Exec SetProcessState @job, @completionCode
	
	return @myError


GO
