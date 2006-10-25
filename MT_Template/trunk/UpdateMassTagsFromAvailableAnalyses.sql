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
**			09/19/2006 mem - Added support for peptide DBs being located on a separate MTS server, utilizing MT_Main.dbo.PopulatePeptideDBLocationTable to determine DB location given Peptide DB ID
**			10/10/2006 mem - Decreased the number of calls made to AddPeptideLoadStatEntry
**    
*****************************************************/
(
	@numJobsToProcess int = 50000,
	@numJobsProcessed int=0 OUTPUT
)
As
	Set nocount on
	
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
	Declare @ValidRowCount int
	Declare @result int
	Declare @job int
	Declare @PDB_ID int
	Declare @UpdateEnabled tinyint
	
	Declare @NumAddedPeptides int
	Set @NumAddedPeptides = 0
	
	Declare @PeptideDBPath varchar(256)		-- Switched from @peptideDBName to @PeptideDBPath on 9/19/2006
	
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
		Job int NOT NULL,
		PDB_ID int NOT NULL
	)
	
	-----------------------------------------------------------
	-- Populate #Tmp_Available_Jobs
	-----------------------------------------------------------
	
	INSERT INTO #Tmp_Available_Jobs (Job, PDB_ID)
	SELECT Job, IsNull(PDB_ID, 0)
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
		Goto Done

	---------------------------------------------------
	-- Create a temporary table to track the path to each peptide DB
	---------------------------------------------------
	--
	CREATE TABLE #T_Peptide_Database_List (
		PeptideDBName varchar(128) NULL,
		PeptideDBID int NULL,
		PeptideDBServer varchar(128) NULL,
		PeptideDBPath varchar(256) NULL
	)

	---------------------------------------------------
	-- Populate #T_Peptide_Database_List with the PDB_ID values
	-- defined in T_Analysis_Description
	---------------------------------------------------
	--
	INSERT INTO #T_Peptide_Database_List (PeptideDBID)
	SELECT DISTINCT PDB_ID
	FROM #Tmp_Available_Jobs
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	---------------------------------------------------
	-- Determine the name and server for each Peptide DB in #T_Peptide_Database_List
	---------------------------------------------------
	--
	exec @myError = MT_Main.dbo.PopulatePeptideDBLocationTable @PreferDBName = 0, @message = @message output

	If @myError <> 0
	Begin
		If Len(IsNull(@message, '')) = 0
			Set @message = 'Error calling MT_Main.dbo.PopulatePeptideDBLocationTable'
		
		Set @message = @message + '; Error Code ' + Convert(varchar(12), @myError)
		Goto Done
	End
	
	-----------------------------------------------------------
	-- Loop through all available analyses and process their peptides
	-----------------------------------------------------------
	--
	Set @Job = 0
	Set @PeptideDBPath = ''

	While @jobAvailable > 0 And @myError = 0 And @numJobsProcessed < @numJobsToProcess
	Begin -- <a>
		
		-----------------------------------------------------------
		-- Get next available analysis from #Tmp_Available_Jobs
		-- Link into T_Analysis_Description to make sure the job
		--  is still in state @AvailableState
		-----------------------------------------------------------
		--
		Set @PDB_ID = 0
		Set @PeptideDBPath = ''
		--
		SELECT TOP 1 @job = TAD.Job, 
					 @PDB_ID = AJ.PDB_ID,
					 @PeptideDBPath = PDL.PeptideDBPath,
					 @UniqueID = AJ.UniqueID
		FROM #Tmp_Available_Jobs AJ INNER JOIN 
			 #T_Peptide_Database_List PDL ON AJ.PDB_ID = PDL.PeptideDBID INNER JOIN
			 T_Analysis_Description TAD ON AJ.Job = TAD.Job
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
				-----------------------------------------------------------
				-- Job has a value of 0 or Null for PDB_ID
				-- This is the case in speciality DBs
				-- Post a warning message to the log then update the job's state to @MassTagUpdatedState
				-----------------------------------------------------------
				
				Set @message = 'Warning: Job ' + convert(varchar(11), @Job) + ' has a value of 0 or Null for PDB_ID in T_Analysis_Description; advancing job state to ' + Convert(varchar(9), @MassTagUpdatedState)
				execute PostLogEntry 'Error', @message, 'UpdateMassTagsFromAvailableAnalyses'
				Set @message = ''
				
				UPDATE T_Analysis_Description
				Set State = @MassTagUpdatedState
				WHERE Job = @job
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				--
			End
			Else
			Begin -- <c>
				-----------------------------------------------------------
				--Call UpdateMassTagsFromOneAnalysis to import the peptides for the job
				-----------------------------------------------------------
				--
				Set @count = 0
				Set @message = 'Calling UpdateMassTagsFromOneAnalysis for Job ' + Convert(varchar(12), @job)
				Set @result = -1
				
				exec @result = UpdateMassTagsFromOneAnalysis @job, @PeptideDBPath, @count output, @message output

				Set @NumAddedPeptides = @NumAddedPeptides + @count
				
				-- make log entry
				--
				If @result = 0
					execute PostLogEntry 'Normal', @message, 'UpdateMassTagsFromAvailableAnalyses'
				Else
					execute PostLogEntry 'Error', @message, 'UpdateMassTagsFromAvailableAnalyses'
				
			End -- <c>
			
			-- Only call AddPeptideLoadStatEntry with Discriminant Score thresholds for the first job
			--  processed and for each 25th job after that
			-- Always call AddPeptideLoadStatEntry with Peptide Prophet thresholds
			
			If @numJobsProcessed % 25 = 0
			Begin
				exec AddPeptideLoadStatEntry @DiscriminantScoreMinimum=0.5, @PeptideProphetMinimum=0,   @AnalysisStateMatch=@MassTagUpdatedState
				exec AddPeptideLoadStatEntry @DiscriminantScoreMinimum=0.9, @PeptideProphetMinimum=0,   @AnalysisStateMatch=@MassTagUpdatedState
				exec AddPeptideLoadStatEntry @DiscriminantScoreMinimum=0.95,@PeptideProphetMinimum=0,   @AnalysisStateMatch=@MassTagUpdatedState
			End

			exec AddPeptideLoadStatEntry @DiscriminantScoreMinimum=0,   @PeptideProphetMinimum=0.5, @AnalysisStateMatch=@MassTagUpdatedState
			exec AddPeptideLoadStatEntry @DiscriminantScoreMinimum=0,   @PeptideProphetMinimum=0.9, @AnalysisStateMatch=@MassTagUpdatedState
			exec AddPeptideLoadStatEntry @DiscriminantScoreMinimum=0,   @PeptideProphetMinimum=0.99,@AnalysisStateMatch=@MassTagUpdatedState

			-- Increment number of jobs processed
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
