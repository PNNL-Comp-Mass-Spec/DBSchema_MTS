/****** Object:  StoredProcedure [dbo].[UpdateMassTagsFromAvailableAnalyses] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.UpdateMassTagsFromAvailableAnalyses
/****************************************************
** 
**	Desc: 
**		Imports the peptides from the LC-MS/MS analyses
**		in T_Analysis_Description with State 1=New
**
**	Return values: 0: success, otherwise, error code
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
**			11/22/2006 mem - Now calling AddPeptideLoadStatEntry just once for each job, except for the first job loaded and for every 25th job loaded
**			09/06/2007 mem - Now looking up the value for 'Peptide_Load_Stats_Detail_Update_Interval' in T_Process_Config
**			09/07/2007 mem - Now calling AddPeptideLoadStatEntries to add the detailed stat values to T_Peptide_Load_Stats
**			02/26/2008 mem - Updated to call UpdateMassTagsFromMultipleAnalyses rather than importing data for one job at a time
**			05/19/2009 mem - Now calling CreateAMTCollection if 'SaveAMTDetailsDuringJobLoad' is enabled
**
*****************************************************/
(
	@numJobsToProcess int = 50000,
	@MaxJobsPerBatch int = 0,			-- If 0, then looks up the value in T_Process_Config (default is 25)
	@MaxPeptidesPerBatch int = 0,		-- If 0, then looks up the value in T_Process_Config (default is 250000)
	@numJobsProcessed int=0 OUTPUT,
	@infoOnly tinyint = 0,
	@UpdatePeptideLoadStats tinyint = 1,
	@UpdateMassTagsAnalysisCounts tinyint = 1
)
As
	Set nocount on
	
	Declare @myError int
	Declare @myRowCount int	
	Set @myError = 0
	Set @myRowCount = 0

	Declare @jobAvailable int
	Declare @UniqueID int

	Declare @message varchar(255)
	Set @message = ''
	
	Declare @ValidRowCount int
	Declare @result int
	Declare @job int
	Declare @PDB_ID_Start int
	Declare @PDB_ID int
	Declare @UpdateEnabled tinyint
	Declare @MaxJobsCurrentBatch int
	
	Declare @DetailedStatsInterval int
	Declare @numProcessedLastDetailedStatsUpdate int
	set @numProcessedLastDetailedStatsUpdate = 0
	
	Declare @JobCountCurrentBatch int
	Declare @PeptideCountCurrentBatch int
	
	Declare @PeptideCountTotal int
	Set @PeptideCountTotal = 0
	
	Declare @ResultType varchar(64)
	Declare @PeptideDBPath varchar(256)		-- Switched from @peptideDBName to @PeptideDBPath on 9/19/2006
	
	Declare @AvailableState int
	Set @AvailableState = 1 -- 'New' 

	Declare @MassTagUpdatedState int
	Set @MassTagUpdatedState = 7
	
	Declare @SaveAMTDetails tinyint
	Set @SaveAMTDetails = 0
	
	Declare @SaveAMTDetailsUsePMTQS tinyint
	Set @SaveAMTDetailsUsePMTQS = 0

	Declare @AMTDetailsUpdatePMTQS tinyint
	Declare @AMTDetailsDiscriminantMinimum real
	Declare @AMTDetailsPepProphetMinimum real
	Declare @AMTDetailsPMTQSMinimum real
								
	-----------------------------------------------------------
	-- Validate the inputs
	-----------------------------------------------------------
	
	Set @numJobsToProcess = IsNull(@numJobsToProcess, 50000)
	Set @MaxJobsPerBatch = IsNull(@MaxJobsPerBatch, 0)
	Set @MaxPeptidesPerBatch = IsNull(@MaxPeptidesPerBatch, 0)
	Set @numJobsProcessed = 0
	Set @infoOnly = IsNull(@infoOnly, 0)
	Set @UpdatePeptideLoadStats = IsNull(@UpdatePeptideLoadStats, 1)
	Set @UpdateMassTagsAnalysisCounts = IsNull(@UpdateMassTagsAnalysisCounts, 1)


	-----------------------------------------------------------
	-- Possibly lookup the default values for @MaxJobsPerBatch and @MaxPeptidesPerBatch
	--  in T_Process_Config
	-----------------------------------------------------------
	
	If @MaxJobsPerBatch <= 0
		exec GetProcessConfigValueInt 'Peptide_Import_MaxJobsPerBatch', 25, @MaxJobsPerBatch output
	
	If @MaxPeptidesPerBatch <= 0
		exec GetProcessConfigValueInt 'Peptide_Import_MaxPeptidesPerBatch', 250000, @MaxPeptidesPerBatch output
	
	If @MaxJobsPerBatch < 1
		Set @MaxJobsPerBatch = 1

	If @MaxPeptidesPerBatch < 100
		Set @MaxPeptidesPerBatch = 100
	
	-----------------------------------------------------------
	-- Check whether or not AMT details should be saved after each batch of jobs is loaded
	-----------------------------------------------------------
	
	SELECT @SaveAMTDetails = enabled
	FROM T_Process_Step_Control
	WHERE (Processing_Step_Name = 'SaveAMTDetailsDuringJobLoad')
	
	Set @SaveAMTDetails = IsNull(@SaveAMTDetails, 0)
	

	SELECT @SaveAMTDetailsUsePMTQS = enabled
	FROM T_Process_Step_Control
	WHERE (Processing_Step_Name = 'SaveAMTDetailsUsePMTQS')
	
	Set @SaveAMTDetailsUsePMTQS = IsNull(@SaveAMTDetailsUsePMTQS, 0)
		
	
	-----------------------------------------------------------
	-- Create a temporary table to track the available jobs,
	--  ordered by Import_Priority and then by Job
	-----------------------------------------------------------
	
	CREATE TABLE #Tmp_Available_Jobs (
		UniqueID int Identity(1,1) NOT NULL,
		Job int NOT NULL,
		PDB_ID int NOT NULL,
		Processed tinyint NOT NULL default 0
	)
	
	-----------------------------------------------------------
	-- Determine the PDB_ID of the job with the lowest (most important) 
	--  import priority in T_Analysis_Description
	-----------------------------------------------------------

	Set @PDB_ID_Start = 0
	
	SELECT TOP 1 @PDB_ID_Start = TAD.PDB_ID
	FROM T_Analysis_Description TAD
	     INNER JOIN ( SELECT MIN(Import_Priority) AS Import_Priority_Min
	                  FROM T_Analysis_Description
	                  WHERE State = 1
	                ) LookupQ
	       ON TAD.Import_Priority = LookupQ.Import_Priority_Min
	WHERE TAD.State = 1
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	Set @PDB_ID_Start = IsNull(@PDB_ID_Start, 0)
	
	If @PDB_ID_Start = 0
	Begin
		SELECT @PDB_ID_Start = MIN(PDB_ID)
		FROM T_Analysis_Description
		
		Set @PDB_ID_Start = IsNull(@PDB_ID_Start, 0)
	End
	
	
	-----------------------------------------------------------
	-- Populate #Tmp_Available_Jobs
	-- Sort by Peptide DB ID, then Import_Priority, then Job
	-----------------------------------------------------------
	
	INSERT INTO #Tmp_Available_Jobs (Job, PDB_ID)
	SELECT Job, IsNull(PDB_ID, 0)
	FROM T_Analysis_Description
	WHERE State = @AvailableState
	ORDER BY CASE WHEN PDB_ID = @PDB_ID_Start THEN 0 ELSE 1 END,
		  Import_Priority, Job
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	If @myError <> 0
	Begin
		Set @message = 'Error populating #Tmp_Available_Jobs'
		Goto Done
	End

	If @myRowCount <= 0
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
	-- Process any jobs in #Tmp_Available_Jobs that have PDB_ID = 0
	-----------------------------------------------------------

	Set @jobAvailable = 1
	Set @UniqueID = 0
	
	While @jobAvailable > 0 And @myError = 0
	Begin -- <a1>
		
		-----------------------------------------------------------
		-- Get next available analysis from #Tmp_Available_Jobs
		-----------------------------------------------------------
		--
		SELECT TOP 1 @job = AJ.Job,
					 @UniqueID = AJ.UniqueID
		FROM #Tmp_Available_Jobs AJ
		WHERE Processed = 0 AND 
			  AJ.UniqueID > @UniqueID AND 
			  IsNull(AJ.PDB_ID, 0) = 0
		ORDER BY AJ.UniqueID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		If @myError <> 0 
		Begin
			Set @message = 'Error while reading next job from #Tmp_Available_Jobs'
			Goto done
		end

		If @myRowCount <> 1
			Set @jobAvailable = 0
		Else
		Begin -- <b1>
			-----------------------------------------------------------
			-- Job has a value of 0 or Null for PDB_ID
			-- This is the case in speciality DBs
			-- Post a warning message to the log then update the job's state to @MassTagUpdatedState
			-----------------------------------------------------------
			
			Set @message = 'Warning: Job ' + convert(varchar(19), @Job) + ' has a value of 0 or Null for PDB_ID in T_Analysis_Description; advancing job state to ' + Convert(varchar(9), @MassTagUpdatedState)
			
			if @infoOnly = 0
				execute PostLogEntry 'Error', @message, 'UpdateMassTagsFromAvailableAnalyses'
			else
				Print @Message
				
			Set @message = ''
			
			If @infoOnly = 0
			Begin
				UPDATE T_Analysis_Description
				Set State = @MassTagUpdatedState
				WHERE Job = @job
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
			End
						
			UPDATE #Tmp_Available_Jobs
			SET Processed = 1
			WHERE Job = @job
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			
		End -- </b1>
	End -- </a1>
	
	
	-----------------------------------------------------------
	-- Loop through all remaining available analyses and process their peptides
	-----------------------------------------------------------
	--

	Set @jobAvailable = 1
	Set @UniqueID = 0
	
	While @jobAvailable > 0 And @myError = 0 And @numJobsProcessed < @numJobsToProcess
	Begin -- <a2>
		
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
					 @ResultType = IsNull(TAD.ResultType, ''),
					 @PDB_ID = IsNull(AJ.PDB_ID, 0),
					 @PeptideDBPath = PDL.PeptideDBPath,
					 @UniqueID = AJ.UniqueID
		FROM #Tmp_Available_Jobs AJ INNER JOIN 
			 #T_Peptide_Database_List PDL ON AJ.PDB_ID = PDL.PeptideDBID INNER JOIN
			 T_Analysis_Description TAD ON AJ.Job = TAD.Job
		WHERE Processed = 0 AND 
			  AJ.UniqueID > @UniqueID AND 
			  TAD.State = @availableState
		ORDER BY AJ.UniqueID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		If @myError <> 0 
		Begin
			Set @message = 'Error while reading next job from #Tmp_Available_Jobs'
			Goto done
		end

		If @myRowCount <> 1
			Set @jobAvailable = 0
		Else
		Begin -- <b2>

			-----------------------------------------------------------
			-- Call UpdateMassTagsFromMultipleAnalyses to import the peptides for this job and
			--  other similar jobs from this Peptide DB
			-- Note that this procedure will update#Tmp_Available_Jobs for any jobs it processes
			-- It will also post the log entries for each job processed
			-----------------------------------------------------------
			--
			Set @JobCountCurrentBatch = 0
			Set @PeptideCountCurrentBatch = 0
			
			Set @message = 'Calling UpdateMassTagsFromMultipleAnalyses starting with Job ' + Convert(varchar(19), @job)
			Set @result = -1
			
			-- Define the maximum jobs allowed in the current batch
			Set @MaxJobsCurrentBatch = @MaxJobsPerBatch
			If @MaxJobsCurrentBatch > @numJobsToProcess - @numJobsProcessed
				Set @MaxJobsCurrentBatch = @numJobsToProcess - @numJobsProcessed
			
			exec @result = UpdateMassTagsFromMultipleAnalyses @job, @ResultType, @availableState, @PDB_ID, @PeptideDBPath, @MaxJobsCurrentBatch, @MaxPeptidesPerBatch, @MassTagUpdatedState, @JobCountCurrentBatch = @JobCountCurrentBatch output, @PeptideCountCurrentBatch = @PeptideCountCurrentBatch output, @message = @message output, @infoOnly = @infoOnly

			Set @PeptideCountTotal = @PeptideCountTotal + @PeptideCountCurrentBatch
			Set @numJobsProcessed = @numJobsProcessed + @JobCountCurrentBatch
			
			If Len(@message) > 0
			Begin
				-- make log entry
				--
				If @infoOnly = 0
				Begin
					If @result = 0
						execute PostLogEntry 'Normal', @message, 'UpdateMassTagsFromAvailableAnalyses'
					Else
						execute PostLogEntry 'Error', @message, 'UpdateMassTagsFromAvailableAnalyses'
				End
				Else
					Print @message
			End

			-- Lookup the current value for 'Peptide_Load_Stats_Detail_Update_Interval' in T_Process_Config
			-- Use a default of 25 if not found
			exec GetProcessConfigValueInt 'Peptide_Load_Stats_Detail_Update_Interval', 25, @DetailedStatsInterval output
			If @DetailedStatsInterval < 1
				Set @DetailedStatsInterval = 25
				
			-- Only call AddPeptideLoadStatEntry with detailed Discriminant Score and
			--  Peptide Prophet thresholds for the first job processed and for each @DetailedStatsInterval'th job after that
			-- Otherwise, only call AddPeptideLoadStatEntry once, using a Peptide Prophet threshold of 0.99

			If @UpdatePeptideLoadStats <> 0
			Begin -- <c1>

				-- After each batch of jobs is loaded, we compute the peptide load stats and save them in T_Peptide_Load_Stats
				-- We always save stats for Discriminant Score >= 0 and Peptide Prophet >= 0.99
				-- If the number of jobs processed is >= @DetailedStatsInterval, then detailed stats are also saved
					
				If @JobCountCurrentBatch - @numProcessedLastDetailedStatsUpdate >= @DetailedStatsInterval
				Begin
					-- Need to save detailed stats information
					
					-- Call AddPeptideLoadStatEntries; it looks for 'Peptide_Load_Stats_Detail_Thresholds' entries
					--  in T_Process_Config and calls AddPeptideLoadStatEntry for each entry
					If @infoOnly = 0
						exec AddPeptideLoadStatEntries @AnalysisStateMatch=@MassTagUpdatedState
					Else
						Print 'Call AddPeptideLoadStatEntries to add detailed stats to T_Peptide_Load_Stats'
						
					Set @numProcessedLastDetailedStatsUpdate = @JobCountCurrentBatch
				End

				If @infoOnly = 0
					exec AddPeptideLoadStatEntry @DiscriminantScoreMinimum=0, 
												 @PeptideProphetMinimum=0.99, 
												 @AnalysisStateMatch=@MassTagUpdatedState
				Else
					Print 'Call AddPeptideLoadStatEntry to add new stats to T_Peptide_Load_Stats using PeptideProphet >= 0.99'
			End -- </c1>
			
			
			If @SaveAMTDetails <> 0
			Begin -- <c2>
				-----------------------------------------------------
				-- Save the AMT details in T_MT_Collection 
				-- and the associated tables
				-----------------------------------------------------

				If @InfoOnly = 0
				Begin -- <d>
					If @SaveAMTDetailsUsePMTQS = 0
					Begin
						Set @AMTDetailsDiscriminantMinimum = 0
						Set @AMTDetailsPepProphetMinimum = 0.5
						Set @AMTDetailsPMTQSMinimum = 0
						Set @AMTDetailsUpdatePMTQS = 0
					End
					Else
					Begin
						Set @AMTDetailsDiscriminantMinimum = 0
						Set @AMTDetailsPepProphetMinimum = 0
						Set @AMTDetailsPMTQSMinimum = 1
						Set @AMTDetailsUpdatePMTQS = 1
					End
					
					exec @myError = CreateAMTCollection 
										@DiscriminantScoreMinimum = @AMTDetailsDiscriminantMinimum, 
										@PeptideProphetMinimum =    @AMTDetailsPepProphetMinimum,
										@PMTQualityScoreMinimum =   @AMTDetailsPMTQSMinimum,
										@RecomputeNET = 1,
										@UpdateMTStats = 1,
										@UpdatePMTQS = @AMTDetailsUpdatePMTQS,
										@InfoOnly = @infoOnly
				End -- </d>
				Else
					Print 'Call CreateAMTCollection'

			End -- </c2>
			
			If @JobCountCurrentBatch = 0
				Set @jobAvailable = 0
				
		End -- </b2>

		-- Validate that updating is enabled, abort if not enabled
		exec VerifyUpdateEnabled @CallingFunctionDescription = 'UpdateMassTagsFromAvailableAnalyses', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
		If @UpdateEnabled = 0
			Goto Done
		
	End -- </a2>

	-----------------------------------------------------------
	-- Update the Analysis counts and High_Normalized_Score values in T_Mass_Tags
	-----------------------------------------------------------
	If @PeptideCountTotal > 0 And @UpdateMassTagsAnalysisCounts <> 0
	Begin
		If @infoOnly = 0
		Begin
			Exec UpdateCachedHistograms @InvalidateButDoNotProcess=1
			Exec ComputeMassTagsAnalysisCounts
		End
		Else
			Print 'Call UpdateCachedHistograms and ComputeMassTagsAnalysisCounts'
	End

Done:
	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[UpdateMassTagsFromAvailableAnalyses] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[UpdateMassTagsFromAvailableAnalyses] TO [MTS_DB_Lite] AS [dbo]
GO
