SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[LoadSequestPeptidesForOneAnalysis]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[LoadSequestPeptidesForOneAnalysis]
GO


CREATE Procedure dbo.LoadSequestPeptidesForOneAnalysis
/****************************************************
**
**	Desc: 
**		Loads all the peptides for the given analysis job
**		that have scores above the minimum thresholds
**
**		Uses bulk insert function
**
**	Parameters:
**
**		Auth: grk
**		Date: 11/11/2001
**     06/02/2004 mem - Updated to not change @myError from a non-zero value back to 0 after call to SetPeptideLoadComplete
**     07/03/2004 mem - Customized for loading Sequest results
**     07/14/2004 grk - Use new sequest peptide file extractor (discriminant scoring)
**                    - Eliminated code that created new synopsis file
**	   07/21/2004 mem - Switched from using SetPeptideLoadComplete to SetProcessState
**	   08/07/2004 mem - Added check for no peptides loaded for job
**	   08/21/2004 mem - Removed @dt parameter from call to GetScoreThresholds
**	   08/24/2004 mem - Switched to using the Peptide Import Filter Set ID from T_Process_Config
**	   09/09/2004 mem - Added validation of the number of columns in the synopsis file
**	   10/15/2004 mem - Moved file validation code to ValidateDelimitedFile
**	   03/07/2005 mem - Updated to reflect changes to T_Process_Config that now use just one column to identify a configuration setting type
**	   06/25/2005 mem - Reworded the error message posted when a synopsis file is empty
**    
*****************************************************/
	@NextProcessState int = 20,
	@job int,
	@message varchar(255)='' OUTPUT,
	@numLoaded int=0 out,
	@clientStoragePerspective tinyint = 1
AS
	set nocount on
	declare @myError int,
			@myRowCount int
	set @myError = 0
	set @myRowCount = 0
		
	declare @completionCode int
	set @completionCode = 3				-- Set to state 'Load Failed' for now

	set @message = ''
	set @numLoaded = 0
	
	declare @jobStr varchar(12)
	set @jobStr = cast(@job as varchar(12))
	
	declare @result int
	
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
	-- Get file information from analysis
	-----------------------------------------------
	declare @Dataset  varchar(128)
	declare @Path varchar(255)
	declare @DatasetFolder varchar(255)
	declare @ResultsFolder varchar(255)
	declare @VolClient varchar(255)
	declare @VolServer varchar(255)
	declare @StoragePath varchar(255)
	
	set @Dataset = ''

	SELECT 
		@Dataset = Dataset, 
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
 	DECLARE @PeptideSynFile varchar(255)
 	DECLARE @PeptideSynFilePath varchar(512)

	set @RootFileName = @Dataset
	set @ResultsPath = @StoragePath + '\' + @ResultsFolder
    set @PeptideSynFile = @RootFileName + '_syn.txt'
	set @PeptideSynFilePath = @ResultsPath + '\' + @PeptideSynFile

	Declare @fileExists tinyint
	Declare @columnCount int
	
	-----------------------------------------------
	-- Verify that input file exists and count the number of columns
	-----------------------------------------------
	Exec @result = ValidateDelimitedFile @PeptideSynFilePath, 0, @fileExists OUTPUT, @columnCount OUTPUT, @message OUTPUT
	
	if @result <> 0
	Begin
		If Len(@message) = 0
			Set @message = 'Error calling ValidateDelimitedFile for ' + @PeptideSynFilePath + ' (Code ' + Convert(varchar(11), @result) + ')'
		
		Set @myError = 60003		
	End
	else
	Begin
		if @columnCount < 19
		begin
			If @columnCount = 0
			Begin
				Set @message = '0 peptides were loaded for job ' + @jobStr + ' (synopsis file is empty)'
				set @myError = 60002	-- Note that this error code is used in SP LoadResultsForAvailableAnalyses; do not change
			End
			Else
			Begin
				Set @message = 'Synopsis file only contains ' + convert(varchar(11), @columnCount) + ' columns for job ' + @jobStr + ' (Expecting 19 columns)'
				set @myError = 60003
			End
		end
	End
	
	-- don't do any more if errors at this point
	--
	if @myError <> 0 goto done


	-----------------------------------------------
	-- Load peptides from synopsis file
	-----------------------------------------------
	
	--(future choose loader sproc based on tool type)
		
	declare @loaded int,
			@peptideCountSkipped int
			
	set @loaded = 0
	set @peptideCountSkipped = 0
	
	exec @result = LoadSequestPeptidesBulk
						@PeptideSynFilePath,
						@job, 
						@FilterSetID,
						@loaded output,
						@peptideCountSkipped output,
						@message output
	--
	set @myError = @result
	IF @result = 0
	BEGIN
		-- set up success message
		--
		set @message = cast(@loaded as varchar(12)) + ' peptides were loaded for job ' + @jobStr + ' (Filtered out ' + cast(@peptideCountSkipped as varchar(12)) + ' peptides)'

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
	
	return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

