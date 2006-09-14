/****** Object:  StoredProcedure [dbo].[UpdateMassTagsFromAvailableAnalyses] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.UpdateMassTagsFromAvailableAnalyses
/****************************************************
** 
**	Desc: 
**		Gets list of LCQ analyses that are available
**		 to have their peptides processed for mass tags,
**		 and processes them.
**
**		Caller must assure that peptides satisfy
**		 a minimum score threshold 
**
**	Return values: 0: success, otherwise, error code
** 
**
**	Auth:	grk
**	Date:	10/09/2001
**			09/21/2004 mem - Updated to utilize the PDB_ID field in T_Analysis_Description
**			09/23/2005 mem - Updated to handle PDB_ID values of 0 or Null
**			03/11/2006 mem - Now calling VerifyUpdateEnabled
**			03/13/2006 mem - Now calling UpdateCachedHistograms if any data is loaded
**			09/12/2006 mem - Added support for Import_Priority column in T_Analysis_Description
**						   - Added calls to AddPeptideLoadStatEntry after loading peptides from each job
**    
*****************************************************/
(
	@numJobsToProcess int = 50000,
	@numJobsProcessed int=0 OUTPUT
)
As
	set nocount on
	
	Declare @myRowCount int	
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

	Set @numJobsProcessed = 0
	
	Declare @jobAvailable int
	Set @jobAvailable = 0

	Declare @UniqueID int
	Set @UniqueID = 0
	
	Declare @message varchar(255)
	Set @message = ''
	
	Declare @count int
	Declare @result int
	Declare @job int
	Declare @PDB_ID int
	Declare @UpdateEnabled tinyint
	
	Declare @NumAddedPeptides int
	Set @NumAddedPeptides = 0
	
	Declare @PeptideDBName varchar(128)
	Declare @PeptideDBIDCached int
	
	Declare @AvailableState int
	Set @AvailableState = 1 -- 'New' 

	Declare @MassTagUpdatedState int
	Set @MassTagUpdatedState = 7
	
	-----------------------------------------------------------
	-- Create a temporary table to track the available jobs,
	--  ordered by Import_Priority and then by Job
	-----------------------------------------------------------
	
	CREATE TABLE #Tmp_Available_Jobs (
		UniqueID int Identity(1,1) NOT NULL,
		Job int NOT NULL
	)
	
	-----------------------------------------------------------
	-- Populate #Tmp_Available_Jobs
	-----------------------------------------------------------
	
	INSERT INTO #Tmp_Available_Jobs (Job)
	SELECT Job
	FROM T_Analysis_Description
	WHERE State = @AvailableState
	ORDER BY Import_Priority, Job
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	If @myError <> 0
	Begin
		Set @message = 'Error populating #Tmp_Available_Jobs'
		Goto Done
	End

	If @myRowCount > 0
		Set @jobAvailable = 1
	Else
		Set @jobAvailable = 0
		
	-----------------------------------------------------------
	-- Loop through all available analyses and process their peptides
	-----------------------------------------------------------
	--

	Set @Job = 0
	Set @PeptideDBName = ''
	Set @PeptideDBIDCached = -1
	
	While @jobAvailable > 0 And @myError = 0 And @numJobsProcessed < @numJobsToProcess
	Begin -- <a>
		
		-----------------------------------------------------------
		-- Get next available analysis from #Tmp_Available_Jobs
		-- Link into T_Analysis_Description to make sure the job
		--  is still in state @AvailableState and to determine PDB_ID
		-- If PDB_ID is Null then @PDB_ID will = 0
		-----------------------------------------------------------
		--
		Set @PDB_ID = 0
		--
		SELECT TOP 1 @job = TAD.Job, 
					 @PDB_ID = IsNull(TAD.PDB_ID, 0),
					 @UniqueID = AJ.UniqueID
		FROM #Tmp_Available_Jobs AJ INNER JOIN 
			 T_Analysis_Description TAD on AJ.Job = TAD.Job
		WHERE TAD.State = @availableState AND AJ.UniqueID > @UniqueID
		ORDER BY AJ.UniqueID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		If @myError <> 0 
		Begin
			Set @message = 'Error while reading next job from T_Analysis_Description'
			Goto done
		end

		If @myRowCount <> 1
			Set @jobAvailable = 0
		Else
		Begin -- <b>
			
			If @PDB_ID = 0
			Begin
				-- Job has a value of 0 or Null for PDB_ID
				-- This is the case in speciality DBs
				-- Post a warning message to the log then update the job's state to @MassTagUpdatedState
				
				Set @message = 'Warning: Job ' + convert(varchar(11), @Job) + ' has a value of 0 or Null for PDB_ID in T_Analysis_Description; advancing job state to ' + Convert(varchar(9), @MassTagUpdatedState)
				execute PostLogEntry 'Error', @message, 'UpdateMassTagsFromAvailableAnalyses'
				Set @message = ''
				
				UPDATE T_Analysis_Description
				SET State = @MassTagUpdatedState
				WHERE Job = @job
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				--
			End
			Else
			Begin -- <c>
				If @PeptideDBIDCached = -1 OR @PeptideDBIDCached <> @PDB_ID
				Begin -- <d1>
					-----------------------------------------------------------
					-- Lookup the peptide DB Name corresponding to PDB_ID
					-----------------------------------------------------------
					--
					SELECT @PeptideDBIDCached = PDB_ID, @PeptideDBName = PDB_Name
					FROM MT_Main.dbo.T_Peptide_Database_List
					WHERE PDB_ID = @PDB_ID
					--
					SELECT @myError = @@error, @myRowCount = @@rowcount
					--
					If @myError <> 0 
					Begin
						Set @message = 'Error while reading next job from T_Analysis_Description'
						Goto done
					end
					--
					If @myRowCount <> 1
					Begin
						Set @message = 'Peptide database not found in MT_Main for job ' + convert(varchar(11), @Job) + '; PDB_ID ' + convert(varchar(11), @PDB_ID)
						execute PostLogEntry 'Error', @message, 'UpdateMassTagsFromAvailableAnalyses'
						Set @message = ''
						Set @PeptideDBIDCached = -1
					end
				End -- </d1>
				
				If @PeptideDBIDCached <> -1 And @PeptideDBIDCached = @PDB_ID
				Begin -- <d2>
					-----------------------------------------------------------
					-- import peptides for the job
					-----------------------------------------------------------
					--
					exec @result = UpdateMassTagsFromOneAnalysis @job, @PeptideDBName, @count output, @message output

					Set @NumAddedPeptides = @NumAddedPeptides + @count
					
					-- make log entry
					--
					If @result = 0
						execute PostLogEntry 'Normal', @message, 'UpdateMassTagsFromAvailableAnalyses'
					Else
						execute PostLogEntry 'Error', @message, 'UpdateMassTagsFromAvailableAnalyses'
					
				End -- <d2>
			End -- <c>
			
			exec AddPeptideLoadStatEntry @DiscriminantScoreMinimum=0.5, @PeptideProphetMinimum=0,   @AnalysisStateMatch=@MassTagUpdatedState
			exec AddPeptideLoadStatEntry @DiscriminantScoreMinimum=0,   @PeptideProphetMinimum=0.5, @AnalysisStateMatch=@MassTagUpdatedState
			exec AddPeptideLoadStatEntry @DiscriminantScoreMinimum=0.9, @PeptideProphetMinimum=0,   @AnalysisStateMatch=@MassTagUpdatedState
			exec AddPeptideLoadStatEntry @DiscriminantScoreMinimum=0,   @PeptideProphetMinimum=0.9, @AnalysisStateMatch=@MassTagUpdatedState
			exec AddPeptideLoadStatEntry @DiscriminantScoreMinimum=0.95,@PeptideProphetMinimum=0,   @AnalysisStateMatch=@MassTagUpdatedState
			exec AddPeptideLoadStatEntry @DiscriminantScoreMinimum=0,   @PeptideProphetMinimum=0.99,@AnalysisStateMatch=@MassTagUpdatedState

			-- increment number of jobs processed
			--
			Set @numJobsProcessed = @numJobsProcessed + 1

		End -- </b>

		-- Validate that updating is enabled, abort if not enabled
		exec VerifyUpdateEnabled @CallingFunctionDescription = 'UpdateMassTagsFromAvailableAnalyses', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
		If @UpdateEnabled = 0
			Goto Done
		
	End -- </a>

	-----------------------------------------------------------
	-- Update the Analysis counts and High_Normalized_Score values in T_Mass_Tags
	-----------------------------------------------------------
	If @NumAddedPeptides > 0
	Begin
		Exec UpdateCachedHistograms @InvalidateButDoNotProcess=1
		Exec ComputeMassTagsAnalysisCounts
	End

Done:
	return @myError


GO
