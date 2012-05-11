/****** Object:  StoredProcedure [dbo].[UpdateMassTagsFromMultipleAnalyses] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.UpdateMassTagsFromMultipleAnalyses
/****************************************************
** 
**	Desc: 	Retrieves all peptides from the associated peptide database 
**			for @JobFirst plus any other jobs in #Tmp_Available_Jobs that are of type @ResultType.  
**			Will process, at most @MaxJobsPerBatch jobs and @MaxPeptidsPerBatch peptides
**
**			For each job, reconciles the new peptides with appropriate entries in T_Mass_Tags
**			and populates T_Mass_Tags_to_Protein_Map, T_Protein_Reference, 
**			T_Peptides, and the T_Score tables
**
**			This procedure requires that that the calling procedure 
**           create temporary table #Tmp_Available_Job with integer columns:
**		     UniqueID, Job, and Processed
**
**			Each job processed by this procedure will have the Processed column
**			Updated in #Tmp_Available_Job
**
**		Return values: 0: success, otherwise, error code
** 
**
**	Auth:	mem
**	Date:	02/26/2008
**			04/04/2008 mem - Now updating Cleavage_State_Max in T_Mass_Tags
**			11/07/2008 mem - Added support for Inspect results (type IN_Peptide_Hit)
**			07/16/2009 mem - Now populating PeptideEx in T_Mass_Tags
**			11/11/2009 mem - Now examining state of ValidateSICStatsForImportedMSMSJobs
**			08/16/2010 mem - Now populating MSGF_SpecProb in T_Score_Discriminant
**			10/03/2011 mem - Added support for MSGFDB results (type MSG_Peptide_Hit)
**			10/27/2011 mem - Added option to apply an MSGF SpecProb filter to the imported peptides
**			01/06/2012 mem - Updated to use T_Peptides.Job
**			02/09/2012 mem - Now populating T_Peptides.DelM_PPM
**
*****************************************************/
(
	@JobFirst int,
	@ResultType varchar(64), 
	@availableState int,
	@PDB_ID int, 
	@PeptideDBPath varchar(256),				-- Should be of the form ServerName.[DatabaseName] or simply [DatabaseName]
	@MaxJobsPerBatch int = 25,
	@MaxPeptidsPerBatch int = 250000,
	@MassTagUpdatedState int = 7,
	@JobCountCurrentBatch int = 0 output,
	@PeptideCountCurrentBatch int = 0 output,
	@message varchar(512) = '' output,
	@infoOnly tinyint = 0
)
As
	set nocount on
	
	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	Declare @AddJobsToBatch int
	Declare @UniqueID int
	
	declare @result int
	declare @numAddedPeptideHitScores int
	declare @numAddedDiscScores int
	declare @errorReturn int
	declare @matchCount int
	
	set @errorReturn = 0

	declare @S nvarchar(3000)
	declare @ParamDef nvarchar(512)

	declare @transName varchar(32)
	Declare @messageType varchar(20)
	
	Declare @JobCurrent int
	Declare @JobStrCurrent varchar(24)
	Declare @JobList varchar(128)
	Set @JobList = ''
	
	Declare @JobListMsgStr varchar(140)
	Set @JobListMsgStr = ''
	
	Declare @JobUpdateFailed int
	Set @JobUpdateFailed = 4

	Declare @MaxScanNumberPeptideHit int,
			@MaxScanNumberSICs int,
			@MaxScanNumberAllScans int
	
	Declare @UseMSGFSpecProbFilter tinyint = 0
	
	Declare @Continue int
	Declare @StateCurrentJob int
	
	Declare @ImportStartTime datetime
	Declare @PauseLengthSeconds int

	Declare @ValidateSICStatsForImportedMSMSJobs tinyint	
	Declare @UpdateEnabledCheckTime datetime
	Declare @UpdateEnabled tinyint
	
	---------------------------------------------------
	-- Validate the inputs
	---------------------------------------------------
	
	Set @ResultType = IsNull(@ResultType, '')
	If Len(@ResultType) = 0
	Begin
		Set @message = '@ResultType is empty; unable to continue'
		Goto Done
	End
	
	Set @MaxJobsPerBatch = IsNull(@MaxJobsPerBatch, 25)
	If @MaxJobsPerBatch < 1
		Set @MaxJobsPerBatch = 1
		
	Set @MaxPeptidsPerBatch = IsNull(@MaxPeptidsPerBatch, 250000)
	Set @MassTagUpdatedState = IsNull(@MassTagUpdatedState, 7)
	Set @MaxJobsPerBatch = IsNull(@MaxJobsPerBatch, 25)
	Set @JobCountCurrentBatch = 0
	Set @PeptideCountCurrentBatch = 0
	Set @message = ''
	Set @infoOnly = IsNull(@infoOnly, 0)

	Set @ImportStartTime = GetDate()

	-----------------------------------------------------------
	-- Check whether MSGF SpecProb filtering is enabled
	-----------------------------------------------------------
	
	Declare @MSGFSpecProbText varchar(128) = ''
	
	SELECT TOP 1 @MSGFSpecProbText = Value
	FROM T_Process_Config
	WHERE [Name] = 'Peptide_Import_MSGF_SpecProb_Filter'
	ORDER BY Process_Config_ID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	If @myRowCount = 1
	Begin
		If Isnumeric(@MSGFSpecProbText) = 0
		Begin
			Set @message = 'Entry for "Peptide_Import_MSGF_SpecProb_Filter" in T_Process_Config is not a number: ' + @MSGFSpecProbText + '; unable to continue'
			execute PostLogEntry 'Error', @message, 'UpdateMassTagsFromMultipleAnalysis'
			set @myError = 50002
			goto done
		End
		
		Set @UseMSGFSpecProbFilter = 1
	End
	
	---------------------------------------------------
	-- Count number of import filters defined
	---------------------------------------------------
	declare @ImportFilterCount int
	set @ImportFilterCount = 0
	--
	SELECT @ImportFilterCount = Count(*)
	FROM T_Process_Config
	WHERE [Name] = 'Peptide_Import_Filter_ID' AND Len(Value) > 0
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 
	begin
		set @message = 'Could not count number of import filters defined'
		set @myError = 50000
		goto Done
	end
	
	-----------------------------------------------------------
	-- Create temporary table for jobs to process
	-----------------------------------------------------------
	--
	CREATE TABLE #TmpJobsInBatch (
		Job int NOT NULL, 
		PeptideCountExpected int NOT NULL
	)
	
	CREATE UNIQUE CLUSTERED INDEX #IX_TmpJobsInBatch ON #TmpJobsInBatch (Job)

	---------------------------------------------------
	-- Assure that @JobFirst is of type @ResultType and is available for processing
	---------------------------------------------------

	Set @JobCurrent = 0
	
	SELECT TOP 1 @JobCurrent = TAD.Job
	FROM #Tmp_Available_Jobs AJ INNER JOIN 
		 T_Analysis_Description TAD ON AJ.Job = TAD.Job
	WHERE TAD.Job = @JobFirst AND
		  Processed = 0 AND 
		  TAD.ResultType = @ResultType AND 
		  AJ.PDB_ID = @PDB_ID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	If @myRowCount = 0 OR @myError <> 0
		Set @JobFirst = Null
	

	Set @AddJobsToBatch = 1
	Set @JobCountCurrentBatch = 0
	Set @UniqueID = 0
	
	While @AddJobsToBatch = 1 And @JobCountCurrentBatch < @MaxJobsPerBatch
	Begin -- <a1>
		If @JobCountCurrentBatch = 0 AND Not @JobFirst Is Null
			Set @JobCurrent = @JobFirst
		Else
		Begin
			SELECT TOP 1 @JobCurrent = TAD.Job,
						 @UniqueID = AJ.UniqueID
			FROM #Tmp_Available_Jobs AJ INNER JOIN 
				 T_Analysis_Description TAD ON AJ.Job = TAD.Job
			WHERE Processed = 0 AND 
				  AJ.UniqueID > @UniqueID AND 
				  TAD.State = @availableState AND 
			      TAD.ResultType = @ResultType AND 
			      AJ.PDB_ID = @PDB_ID AND
			      (NOT TAD.Job IN (SELECT Job FROM #TmpJobsInBatch))
			ORDER BY AJ.UniqueID
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			
			If @myRowCount = 0
				Set @AddJobsToBatch = 0
		End
		
		If @AddJobsToBatch = 1
		Begin -- <b1>
			
			Set @JobStrCurrent = Convert(varchar(19), @JobCurrent)
			
			If @ImportFilterCount > 0
			Begin -- <c1>
				---------------------------------------------------
				-- Validate that the given Peptide DB has tested this job against one of the 
				-- filters in T_Process_Config; if it has not, then raise an error
				---------------------------------------------------

				set @matchCount = 0
				
				set @S = ''
				set @S = @S + ' SELECT @matchCount = Count(Job) '
				set @S = @S + ' FROM '
				set @S = @S +    ' ' + @PeptideDBPath + '.dbo.T_Analysis_Filter_Flags'
				set @S = @S + ' WHERE (Job = ' + @JobStrCurrent + ') '
				set @S = @S + ' AND ('
				set @S = @S + '    Filter_ID IN '
				set @S = @S + '    (SELECT Value FROM T_Process_Config WHERE [Name] = ''Peptide_Import_Filter_ID'' AND Len(Value) > 0)'
				set @S = @S + ') '

				set @ParamDef = '@matchCount int output'
				
				exec @result = sp_executesql @S, @ParamDef, @matchCount = @matchCount output
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount

				If IsNull(@matchCount, 0) = 0
				Begin -- <d1>
					set @message = 'Job ' + @JobStrCurrent + ' has not yet been tested in peptide DB ' + @PeptideDBPath + ' against any of the import filters defined in T_Process_Config; thus, no peptides can be imported'
					
					If @infoOnly = 0
					Begin
						execute PostLogEntry 'Error', @message, 'UpdateMassTagsFromMultipleAnalysis'
						
						UPDATE T_Analysis_Description
						SET State = @JobUpdateFailed
						WHERE Job = @JobCurrent
					End
					Else
						Print @message					

					UPDATE #Tmp_Available_Jobs
					SET Processed = 1
					WHERE Job = @JobCurrent
					
					Set @message = ''
					Set @AddJobsToBatch = 0
				End -- </d1>
			End -- </c1>

			If @AddJobsToBatch = 1
			Begin -- <c2>
				-- Count the number of peptides that would be imported for this job
				
				Set @matchCount = 0
				
				Set @S = ''
				set @S = @S + ' SELECT @matchCount = COUNT(*)'
				set @S = @S + ' FROM '
				set @S = @S +   ' ' + @PeptideDBPath + '.dbo.V_Peptide_Export '
				set @S = @S + ' WHERE (Job = ' + @JobStrCurrent + ') '

				if @ImportFilterCount > 0
				begin
					set @S = @S + ' AND ('
					set @S = @S + '    Filter_ID IN '
					set @S = @S + '    (SELECT Value FROM T_Process_Config WHERE [Name] = ''Peptide_Import_Filter_ID'' AND Len(Value) > 0)'
					set @S = @S + ') '
				end

				set @ParamDef = '@matchCount int output'
				
				exec @result = sp_executesql @S, @ParamDef, @matchCount = @matchCount output
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount

				If @myError = 0 AND (@JobCountCurrentBatch = 0 OR @matchCount + @PeptideCountCurrentBatch <= @MaxPeptidsPerBatch)
				Begin
					-- Add this job to #TmpJobsInBatch
					
					INSERT INTO #TmpJobsInBatch (Job, PeptideCountExpected)
					VALUES (@JobCurrent, @matchCount)
					--
					SELECT @myError = @@error, @myRowCount = @@rowcount
					
					Set @JobCountCurrentBatch = @JobCountCurrentBatch + 1
					Set @PeptideCountCurrentBatch = @PeptideCountCurrentBatch + @matchCount
					
					If Len(@JobList) = 0
						Set @JobList = @JobStrCurrent
					Else
					Begin
						If Len(@JobList) < 115
							Set @JobList = @JobList + ',' + @JobStrCurrent
						Else
						Begin
							If Right(@JobList, 1) <> '.'
								Set @JobList = @JobList + ' ...'
						End 
					End
				End
				Else
					Set @AddJobsToBatch = 0
				
			End -- </c2>

		End -- </b1>
	End -- </a1>


	If @infoOnly <> 0
	Begin
		SELECT *
		FROM #TmpJobsInBatch
		ORDER BY Job
	End

	If @JobCountCurrentBatch = 1
		Set @JobListMsgStr = 'job ' + @JobList
	Else
		Set @JobListMsgStr = 'jobs ' + @JobList

	-----------------------------------------------------------
	-- Create a temporary table to hold the imported peptides
	-----------------------------------------------------------
	--
	CREATE TABLE #Imported_Peptides (
		Job int,
		Scan_Number int,
		Number_Of_Scans smallint,
		Charge_State smallint,
		MH float,
		Monoisotopic_Mass float, 
		GANET_Obs real,
		GANET_Predicted real,
		Scan_Time_Peak_Apex real,
		Multiple_ORF int, 
		Peptide varchar (850), 
		Clean_Sequence varchar (850), 
		Mod_Count int, 
		Mod_Description varchar (2048), 
		Seq_ID int, 
		Peptide_ID_Original int NOT NULL,
		Peak_Area float,
		Peak_SN_Ratio real,
		DelM_PPM real,
		Unique_Row_ID int IDENTITY (1, 1) NOT NULL,
		Peptide_ID_New int NULL
	)   
	--
	SELECT @myError = @@error
	--
	if @myError <> 0 
	begin
		set @message = 'Could not create #Imported_Peptides temporary table'
		set @myError = 50004
		goto Done
	end

	-----------------------------------------------
	-- Add an index to #Imported_Peptides to speed joins
	-- on column Peptide_ID_Original
	-----------------------------------------------
	--
	CREATE UNIQUE CLUSTERED INDEX #IX_TempTable_Imported_Peptides_ID_Original ON #Imported_Peptides (Job, Peptide_ID_Original)
	CREATE INDEX #IX_TempTable_Imported_Peptides_ID_New ON #Imported_Peptides (Peptide_ID_New)


	-----------------------------------------------------------
	-- Create a temporary table to hold peptide to protein mappings
	-----------------------------------------------------------
	--
	CREATE TABLE #PeptideToProteinMapImported (
		Seq_ID int, 
		Cleavage_State tinyint,
		Terminus_State tinyint,
		Reference varchar(255),
		Ref_ID_New int NULL
	)
	--
	SELECT @myError = @@error
	--
	if @myError <> 0 
	begin
		set @message = 'Could not create #PeptideToProteinMapImported temporary table'
		set @myError = 50005
		goto Done
	end

	-----------------------------------------------
	-- Add an index to #Imported_Peptides to speed joins
	-- on column Reference
	-----------------------------------------------
	--
	CREATE INDEX #IX_TempTable_PeptideToProteinMapImported ON #PeptideToProteinMapImported (Reference)

	-----------------------------------------------------------
	-- Create a temporary table to hold unique Mass Tag ID stats
	-----------------------------------------------------------
	--
	CREATE TABLE #ImportedMassTags (
		Mass_Tag_ID int NOT NULL,
		Clean_Sequence varchar (850), 
		Monoisotopic_Mass float, 
		Multiple_ORF int,
		Mod_Count int, 
		Mod_Description varchar (2048), 
		GANET_Predicted real,
		PeptideEx varchar(512)
	)   
	--
	SELECT @myError = @@error
	--
	if @myError <> 0 
	begin
		set @message = 'Could not create #ImportedMassTags temporary table'
		set @myError = 50006
		goto Done
	end

	-----------------------------------------------
	-- Add an index to #ImportedMassTags to assure no 
	-- duplicate Mass_Tag_ID rows are present
	-----------------------------------------------
	--
	CREATE UNIQUE CLUSTERED INDEX #IX_TempTable_ImportedMassTags ON #ImportedMassTags (Mass_Tag_ID)

	-----------------------------------------------------------
	-- Create a temporary table to hold peptide hit stats
	-----------------------------------------------------------
	--
	CREATE TABLE #PeptideHitStats (
		Mass_Tag_ID int NOT NULL,
		Observation_Count int NOT NULL, 
		Normalized_Score_Max real NULL
	)   
	--
	SELECT @myError = @@error
	--
	if @myError <> 0 
	begin
		set @message = 'Could not create #PeptideHitStats temporary table'
		set @myError = 50006
		goto Done
	end

	-----------------------------------------------
	-- Add an index to #PeptideHitStats to assure no 
	-- duplicate Mass_Tag_ID rows are present
	-----------------------------------------------
	--
	CREATE UNIQUE CLUSTERED INDEX #IX_TempTable_PeptideHitStats ON #PeptideHitStats (Mass_Tag_ID)
	
	-----------------------------------------------------------
	-- Lookup setting for ValidateSICStatsForImportedMSMSJobs
	-----------------------------------------------------------
	
	Set @ValidateSICStatsForImportedMSMSJobs = 1
	
	SELECT @ValidateSICStatsForImportedMSMSJobs = IsNull(Enabled, 1)
	FROM T_Process_Step_Control
	Where Processing_Step_Name = 'ValidateSICStatsForImportedMSMSJobs'
	
	
	-----------------------------------------------------------
	-- Build dynamic SQL to populate #Imported_Peptides
	-----------------------------------------------------------
	--
	If @infoOnly = 0	
	Begin
		-- Reset @PeptideCountCurrentBatch to 0; we'll update it after the import
		set @PeptideCountCurrentBatch = 0
	End

	set @S = ''
	set @S = @S + ' INSERT INTO #Imported_Peptides '
	set @S = @S + ' ( '
	set @S = @S +   ' Job, Scan_Number, Number_Of_Scans, Charge_State, MH,'
	set @S = @S +   ' Monoisotopic_Mass, GANET_Obs, GANET_Predicted, Scan_Time_Peak_Apex, Multiple_ORF,'
	set @S = @S +   ' Peptide, Clean_Sequence, Mod_Count, Mod_Description,'
	set @S = @S +   ' Seq_ID, Peptide_ID_Original, Peak_Area, Peak_SN_Ratio, DelM_PPM'
	set @S = @S + ') '
	--
	set @S = @S + ' SELECT '
	set @S = @S +   ' Src.Job, Src.Scan_Number, Src.Number_Of_Scans, Src.Charge_State, Src.MH,'
	set @S = @S +   ' Src.Monoisotopic_Mass, Src.GANET_Obs, Src.GANET_Predicted, Src.Scan_Time_Peak_Apex, Src.Multiple_ORF,'
	set @S = @S +   ' Src.Peptide, Src.Clean_Sequence, Src.Mod_Count, Src.Mod_Description,'
	set @S = @S +   ' Src.Seq_ID, Src.Peptide_ID, Src.Peak_Area, Src.Peak_SN_Ratio, Src.DelM_PPM'
	set @S = @S + ' FROM '
	set @S = @S +     @PeptideDBPath + '.dbo.V_Peptide_Export Src INNER JOIN'
	set @S = @S +   ' #TmpJobsInBatch JobList ON Src.Job = JobList.Job'

	if @ImportFilterCount > 0
	begin
		set @S = @S + ' WHERE ('
		set @S = @S + '    Src.Filter_ID IN '
		set @S = @S + '    (SELECT Value FROM T_Process_Config WHERE [Name] = ''Peptide_Import_Filter_ID'' AND Len(Value) > 0)'
		set @S = @S + ') '
	end
	set @S = @S + ' ORDER BY Src.Job, Src.Peptide_ID'

	If @infoOnly = 0	  
	Begin
		exec @result = sp_executesql @S
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		set @PeptideCountCurrentBatch = @myRowCount
	End
	Else
	Begin
		Print @S
		
		UPDATE #Tmp_Available_Jobs
		SET Processed = 1
		FROM #Tmp_Available_Jobs AJ INNER JOIN 
		     #TmpJobsInBatch JIB ON AJ.Job = JIB.Job
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		Goto Done
	End

	if @result <> 0 
	begin
		set @message = 'Error executing dynamic SQL for peptide import for ' + @JobListMsgStr
		set @myError = 50007
		goto Done
	end

	-----------------------------------------------------------
	-- We are done if we didn't get any peptides
	-----------------------------------------------------------
	--
	if @PeptideCountCurrentBatch <= 0
	begin
		set @message = 'No peptides imported for ' + @JobListMsgStr
		set @myError = 60000
		goto Done
	end
	
	-- Validate that updating is enabled, abort if not enabled
	Set @UpdateEnabledCheckTime = GetDate()
	exec VerifyUpdateEnabled @CallingFunctionDescription = 'UpdateMassTagsFromMultipleAnalyses', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
	If @UpdateEnabled = 0
	Begin
		Set @message = ''
		Goto Done
	End
	
	Set @PauseLengthSeconds = DateDiff(second, @UpdateEnabledCheckTime, GetDate())
	If @PauseLengthSeconds > 1
	Begin
		-- Adjust @ImportStartTime to account for @PauseLengthSeconds
		Set @ImportStartTime = DateAdd(second, @PauseLengthSeconds, @ImportStartTime)
	End


	-----------------------------------------------------------
	-- Perform some scan number checks to validate that the 
	-- SIC job associated each imported job is valid
	--
	-- In addition, delete any existing results in T_Peptides, T_Score_Sequest
	-- T_Score_Discriminant, etc. for each analysis job
	-----------------------------------------------------------

	SELECT @JobCurrent = MIN(Job)-1
	FROM #TmpJobsInBatch
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	If @myRowCount = 0
		Set @Continue = 0
	Else
		Set @Continue = 1
	
	While @Continue = 1
	Begin -- <a2>
		SELECT TOP 1 @JobCurrent = Job
		FROM #TmpJobsInBatch
		Where Job > @JobCurrent
		ORDER BY Job
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myRowCount = 0
			Set @Continue = 0
		Else
		Begin -- <b2>
			Set @JobStrCurrent = Convert(varchar(19), @JobCurrent)
			
			If IsNull(@ValidateSICStatsForImportedMSMSJobs, 0) = 0
			Begin
				Set @message = ''
			End
			Else
			Begin
				Set @MaxScanNumberPeptideHit = 0
				Set @MaxScanNumberSICs = 0
				Set @MaxScanNumberAllScans = 0
				Set @message = ''
				
				set @S = ''
				set @S = @S + ' SELECT @MaxA = MaxScanNumberPeptideHit, '
				set @S = @S +        ' @MaxB = MaxScanNumberSICs,'
				set @S = @S +        ' @MaxC = MaxScanNumberAllScans'
				set @S = @S + ' FROM ' + @PeptideDBPath + '.dbo.V_PeptideHit_Job_Scan_Max '
				set @S = @S + ' WHERE (Job = ' + @JobStrCurrent + ') '

				set @ParamDef = '@MaxA int output, @MaxB int output, @MaxC int output'
				
				exec @result = sp_executesql @S, @ParamDef, @MaxA = @MaxScanNumberPeptideHit output, @MaxB = @MaxScanNumberSICs output, @MaxC = @MaxScanNumberAllScans output
				
				Set @MaxScanNumberPeptideHit = IsNull(@MaxScanNumberPeptideHit, 0)
				
				If @MaxScanNumberPeptideHit > IsNull(@MaxScanNumberSICs, 0)
				Begin
					-- Invalid SIC data
					set @message = 'Missing or invalid SIC data found for job ' + @JobStrCurrent + '; max Peptide_Hit scan number is greater than maximum SIC scan number'
				End

				If @MaxScanNumberPeptideHit > IsNull(@MaxScanNumberAllScans, 0) And Len(@message) = 0
				Begin
					-- Invalid SIC data
					set @message = 'Missing or invalid SIC data found for job ' + @JobStrCurrent + '; max Peptide_Hit scan number is greater than maximum scan stats scan number'
				End
			End
						
			If Len(@message) > 0
			Begin -- <c3>
			
				execute PostLogEntry 'Error', @message, 'UpdateMassTagsFromMultipleAnalysis'

				DELETE FROM #TmpJobsInBatch
				WHERE Job = @JobCurrent
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount

				DELETE FROM #Imported_Peptides
				WHERE Job = @JobCurrent
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				
				UPDATE T_Analysis_Description
				SET State = @JobUpdateFailed
				WHERE Job = @JobCurrent
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount

				UPDATE #Tmp_Available_Jobs
				SET Processed = 1
				WHERE Job = @JobCurrent
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount

			End -- </c3>
			Else
			Begin
				Exec @result = DeletePeptidesForJobAndResetToNew @JobCurrent, 0
			End
		End -- </b2>
	End -- </a2>


	If @UseMSGFSpecProbFilter > 0
	Begin
		-----------------------------------------------------------
		-- Delete entries from #Imported_Peptides if their MSGF_SpecProb value is > @MSGFSpecProbThreshold
		-----------------------------------------------------------
		--
		set @S = ''
		set @S = @S + ' DELETE #Imported_Peptides'
		set @S = @S + ' FROM #Imported_Peptides AS IP INNER JOIN'
		set @S = @S +   ' ' + @PeptideDBPath + '.dbo.T_Score_Discriminant AS SD ON IP.Peptide_ID_Original = SD.Peptide_ID'
		set @S = @S + ' WHERE IsNull(SD.MSGF_SpecProb, 1) > ' + @MSGFSpecProbText
		--
		exec @result = sp_executesql @S
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	
		If @myRowCount > 0
		Begin
			Set @message = 'Removed ' + Convert(varchar(12), @myRowCount) + ' / ' + Convert(varchar(12), @PeptideCountCurrentBatch) + ' imported peptides for ' + @JobListMsgStr + ' since MSGF_SpecProb > ' + @MSGFSpecProbText
			execute PostLogEntry 'Normal', @message, 'UpdateMassTagsFromMultipleAnalysis'
			Set @message = ''
		End
	End
	
	
	-----------------------------------------------------------
	-- Populate #ImportedMassTags
	-----------------------------------------------------------
	--
	INSERT INTO #ImportedMassTags (
		Mass_Tag_ID, Clean_Sequence, Monoisotopic_Mass,
		Multiple_ORF, Mod_Count, Mod_Description, 
		GANET_Predicted, PeptideEx
		)
	SELECT Seq_ID, Clean_Sequence, Monoisotopic_Mass,
		   Max(Multiple_ORF), Mod_Count, Mod_Description, 
		   Avg(GANET_Predicted), Min(Peptide)
	FROM #Imported_Peptides
	GROUP BY Seq_ID, Clean_Sequence, Monoisotopic_Mass, Mod_Count, Mod_Description
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Error populating #ImportedMassTags temporary table for ' + @JobListMsgStr
		set @myError = 50008
		goto Done
	end	

	-- Validate that updating is enabled, abort if not enabled
	If DateDiff(second, @UpdateEnabledCheckTime, GetDate()) >= 120
	Begin
		Set @UpdateEnabledCheckTime = GetDate()
		exec VerifyUpdateEnabled @CallingFunctionDescription = 'UpdateMassTagsFromMultipleAnalyses', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
		If @UpdateEnabled = 0
		Begin
			Set @message = ''
			Goto Done
		End
		
		Set @PauseLengthSeconds = DateDiff(second, @UpdateEnabledCheckTime, GetDate())
		If @PauseLengthSeconds > 1
		Begin
			-- Adjust @ImportStartTime to account for @PauseLengthSeconds
			Set @ImportStartTime = DateAdd(second, @PauseLengthSeconds, @ImportStartTime)
		End
	End
	
	-----------------------------------------------------------
	-- Populate #PeptideToProteinMapImported
	-----------------------------------------------------------
	--
	set @S = ''
	set @S = @S + ' INSERT INTO #PeptideToProteinMapImported '
	set @S = @S + ' ('
	set @S = @S +  ' Seq_ID, Cleavage_State, Terminus_State, Reference'
	set @S = @S + ' )'
	--
	set @S = @S + ' SELECT VPE.Seq_ID, VPE.Cleavage_State, VPE.Terminus_State, VPE.Reference '
	set @S = @S + ' FROM ' + @PeptideDBPath + '.dbo.V_Protein_Export AS VPE INNER JOIN'
	set @S = @S +          ' #Imported_Peptides AS IP ON '
	set @S = @S +          ' IP.Peptide_ID_Original = VPE.Peptide_ID '
	set @S = @S + ' GROUP BY VPE.Seq_ID, VPE.Cleavage_State, VPE.Terminus_State, VPE.Reference'
	  
	exec @result = sp_executesql @S
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @result <> 0 
	begin
		set @message = 'Error executing dynamic SQL for peptide to protein map import for ' + @JobListMsgStr
		set @myError = 50009
		goto Done
	end
    
    -- Validate that updating is enabled, abort if not enabled
	If DateDiff(second, @UpdateEnabledCheckTime, GetDate()) >= 120
	Begin
		Set @UpdateEnabledCheckTime = GetDate()
		exec VerifyUpdateEnabled @CallingFunctionDescription = 'UpdateMassTagsFromMultipleAnalyses', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
		If @UpdateEnabled = 0
		Begin
			Set @message = ''
			Goto Done
		End
		
		Set @PauseLengthSeconds = DateDiff(second, @UpdateEnabledCheckTime, GetDate())
		If @PauseLengthSeconds > 1
		Begin
			-- Adjust @ImportStartTime to account for @PauseLengthSeconds
			Set @ImportStartTime = DateAdd(second, @PauseLengthSeconds, @ImportStartTime)
		End
	End
	
	-----------------------------------------------
	-- Lookup the maximum Peptide_ID value in T_Peptides
	--  and use it to populate Peptide_ID_New
	-- Start a transaction to assure that the @base value
	--  stays valid
	-----------------------------------------------
	--
	set @transName = 'UpdateMassTagsFromMultipleAnalyses'
	begin transaction @transName

	-----------------------------------------------
	-- Get base value for peptide ID calculation
	-- Note that @base will get added to #Imported_Peptides.Unique_Row_ID, 
	--  which will always start at 1
	-----------------------------------------------
	--
	declare @base int
	set @base = 0
	--
	SELECT @base = IsNull(MAX(Peptide_ID), 1000)
	FROM T_Peptides
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0 or @base = 0
	begin
		rollback transaction @transName
		set @message = 'Problem getting base for peptide ID for ' + @JobListMsgStr
		If @myError = 0
			Set @myError = 50010
		goto Done
	end

	-----------------------------------------------
	-- Update peptide ID column
	-----------------------------------------------
	--
	UPDATE #Imported_Peptides
	SET Peptide_ID_New = Unique_Row_ID + @base
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		rollback transaction @transName
		set @message = 'Problem populating Peptide_ID_New column in temporary table for ' + @JobListMsgStr
		Set @myError = 50011
		goto Done
	end

	-----------------------------------------------------------
	-- Update existing entries in T_Mass_Tags with Multiple_Proteins
	-- values smaller than those in #ImportedMassTags
	-----------------------------------------------------------
	--
	UPDATE T_Mass_Tags
	SET Multiple_Proteins = IMT.Multiple_ORF
	FROM #ImportedMassTags AS IMT INNER JOIN
	     T_Mass_Tags MT ON IMT.Mass_Tag_ID = MT.Mass_Tag_ID
	WHERE MT.Multiple_Proteins < IMT.Multiple_ORF
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		rollback transaction @transName
		set @message = 'Problem updating Multiple_Proteins values in T_Mass_Tags for ' + @JobListMsgStr
		Set @myError = 50012
		goto Done
	end


	-----------------------------------------------------------
	-- Set Internal_Standard_Only to 0 for matching mass tags
	-----------------------------------------------------------
	--
	UPDATE T_Mass_Tags
	SET Internal_Standard_Only = 0
	FROM #ImportedMassTags AS IMT INNER JOIN
	     T_Mass_Tags MT ON IMT.Mass_Tag_ID = MT.Mass_Tag_ID
	WHERE MT.Internal_Standard_Only <> 0
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error


	-----------------------------------------------------------
	-- Populate PeptideEx for matching mass tags 
	-- that currently have blank/null PeptideEx values
	-----------------------------------------------------------
	--
	UPDATE T_Mass_Tags
	SET PeptideEx = IMT.PeptideEx
	FROM #ImportedMassTags AS IMT INNER JOIN
	     T_Mass_Tags MT ON IMT.Mass_Tag_ID = MT.Mass_Tag_ID
	WHERE IsNull(MT.PeptideEx, '') = ''
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error


	-----------------------------------------------------------
	-- Add new mass tags to T_Mass_Tags
	-----------------------------------------------------------
	--
	INSERT INTO T_Mass_Tags (
		Mass_Tag_ID, Peptide, Monoisotopic_Mass,
		Is_Confirmed, Multiple_Proteins, Created, Last_Affected,
		Number_Of_Peptides, High_Normalized_Score,
		Mod_Count, Mod_Description, Internal_Standard_Only,
		PeptideEx
		)
	SELECT IMT.Mass_Tag_ID, IMT.Clean_Sequence, IMT.Monoisotopic_Mass,
		0 AS Is_Confirmed, IMT.Multiple_ORF, GetDate() AS Created, GetDate() AS Last_Affected,
		0 AS Number_Of_Peptides, 0 AS High_Normalized_Score,
		IMT.Mod_Count, IMT.Mod_Description, 0 AS Internal_Standard_Only,
		IMT.PeptideEx
	FROM #ImportedMassTags AS IMT LEFT OUTER JOIN
	  T_Mass_Tags ON IMT.Mass_Tag_ID = T_Mass_Tags.Mass_Tag_ID
	WHERE (T_Mass_Tags.Mass_Tag_ID IS NULL)
	ORDER BY IMT.Mass_Tag_ID
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		rollback transaction @transName
		set @message = 'Problem appending new entries to T_Mass_Tags for ' + @JobListMsgStr
		Set @myError = 50013
		goto Done
	end

	-----------------------------------------------------------
	-- Add new entries to T_Peptides
	-----------------------------------------------------------
	--
	INSERT INTO T_Peptides (
		Peptide_ID, Job, Scan_Number, Number_Of_Scans, Charge_State, MH,
		Multiple_Proteins, Peptide, Mass_Tag_ID, GANET_Obs, State_ID, Scan_Time_Peak_Apex,
		Peak_Area, Peak_SN_Ratio, DelM_PPM
		)
	SELECT Peptide_ID_New, Job, Scan_Number, Number_Of_Scans, Charge_State, MH,
		Multiple_ORF, Peptide, Seq_ID, GANET_Obs, 2 As StateCandidate, Scan_Time_Peak_Apex,
		Peak_Area, Peak_SN_Ratio, DelM_PPM
	FROM #Imported_Peptides
	ORDER BY Job, Peptide_ID_New
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		rollback transaction @transName
		set @message = 'Problem appending new entries to T_Peptides for ' + @JobListMsgStr
		Set @myError = 50020
		goto Done
	end
	
	-- Update @PeptideCountCurrentBatch one more time; it may have changed if we deleted
	--  data from #Imported_Peptides while performing the SIC job validation checks
	Set @PeptideCountCurrentBatch = @myRowCount


	Declare @ResultTypeValid tinyint
	Set @ResultTypeValid = 0
	
	If @ResultType = 'Peptide_Hit'
	Begin
		-----------------------------------------------------------
		-- Add new entries to T_Score_Sequest
		-----------------------------------------------------------
		--
		set @S = ''
		set @S = @S + ' INSERT INTO T_Score_Sequest ('
		set @S = @S +   ' Peptide_ID, XCorr, DeltaCn, DeltaCn2, SP, RankSp, RankXc, DelM, XcRatio'
		set @S = @S + ' )'
		set @S = @S + ' SELECT IP.Peptide_ID_New, SS.XCorr, SS.DeltaCn, SS.DeltaCn2, SS.SP, SS.RankSp, SS.RankXc, SS.DelM, SS.XcRatio'
		set @S = @S + ' FROM #Imported_Peptides AS IP INNER JOIN'
		set @S = @S +   ' ' + @PeptideDBPath + '.dbo.T_Score_Sequest AS SS ON IP.Peptide_ID_Original = SS.Peptide_ID'
		set @S = @S + ' ORDER BY IP.Peptide_ID_New'
		--
		exec @result = sp_executesql @S
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @result <> 0 
		begin
			rollback transaction @transName
			set @message = 'Error executing dynamic SQL for T_Score_Sequest for ' + @JobListMsgStr
			set @myError = 50021
			goto Done
		end
		--
		Set @numAddedPeptideHitScores = @myRowCount

		-- Populate #PeptideHitStats (used below to update stats in T_Mass_Tags)
		--
		INSERT INTO #PeptideHitStats (Mass_Tag_ID, Observation_Count, Normalized_Score_Max)
		SELECT	Mass_Tag_ID, 
				COUNT(*) AS Observation_Count, 
				MAX(XCorr_Max) AS Normalized_Score_Max
		FROM (	SELECT	IP.Seq_ID AS Mass_Tag_ID, 
						IP.Scan_Number, 
						MAX(ISNULL(SS.XCorr, 0)) AS XCorr_Max
				FROM #Imported_Peptides AS IP LEFT OUTER JOIN
					 T_Score_Sequest AS SS ON IP.Peptide_ID_New = SS.Peptide_ID
				GROUP BY IP.Seq_ID, IP.Scan_Number
				) AS SubQ
		GROUP BY SubQ.Mass_Tag_ID	
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		Set @ResultTypeValid = 1
	End

	If @ResultType = 'XT_Peptide_Hit'
	Begin
		-----------------------------------------------------------
		-- Add new entries to T_Score_XTandem
		-----------------------------------------------------------
		--
		set @S = ''
		set @S = @S + 'INSERT INTO T_Score_XTandem ('
		set @S = @S +  ' Peptide_ID, Hyperscore, Log_EValue, DeltaCn2,'
		set @S = @S +  ' Y_Score, Y_Ions, B_Score, B_Ions, DelM, Intensity, Normalized_Score'
		set @S = @S + ' )'
		set @S = @S + ' SELECT IP.Peptide_ID_New, X.Hyperscore, X.Log_EValue, X.DeltaCn2,'
		set @S = @S +      ' X.Y_Score, X.Y_Ions, X.B_Score, X.B_Ions, X.DelM, X.Intensity, X.Normalized_Score'
		set @S = @S + ' FROM #Imported_Peptides AS IP INNER JOIN'
		set @S = @S +   ' ' + @PeptideDBPath + '.dbo.T_Score_XTandem AS X ON IP.Peptide_ID_Original = X.Peptide_ID'
		set @S = @S + ' ORDER BY IP.Peptide_ID_New'
		--
		exec @result = sp_executesql @S
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @result <> 0 
		begin
			rollback transaction @transName
			set @message = 'Error executing dynamic SQL for T_Score_XTandem for ' + @JobListMsgStr
			set @myError = 50022
			goto Done
		end
		--
		Set @numAddedPeptideHitScores = @myRowCount
		
		-- Populate #PeptideHitStats (used below to update stats in T_Mass_Tags)
		--
		INSERT INTO #PeptideHitStats (Mass_Tag_ID, Observation_Count, Normalized_Score_Max)
		SELECT	Mass_Tag_ID, 
				COUNT(*) AS Observation_Count, 
				MAX(Normalized_Score_Max) AS Normalized_Score_Max
		FROM (	SELECT	IP.Seq_ID AS Mass_Tag_ID, 
						IP.Scan_Number, 
						MAX(ISNULL(X.Normalized_Score, 0)) AS Normalized_Score_Max
				FROM #Imported_Peptides AS IP LEFT OUTER JOIN
					 T_Score_XTandem AS X ON IP.Peptide_ID_New = X.Peptide_ID
				GROUP BY IP.Seq_ID, IP.Scan_Number
				) AS SubQ
		GROUP BY SubQ.Mass_Tag_ID	
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		Set @ResultTypeValid = 1
	End

	If @ResultType = 'IN_Peptide_Hit'
	Begin
		-----------------------------------------------------------
		-- Add new entries to T_Score_Inspect
		-----------------------------------------------------------
		--
		set @S = ''
		set @S = @S + 'INSERT INTO T_Score_Inspect ('
		set @S = @S +  ' Peptide_ID, MQScore, TotalPRMScore, MedianPRMScore,' 
		set @S = @S +  ' FractionY, FractionB, Intensity, PValue, FScore,'
		set @S = @S +  ' DeltaScore, DeltaScoreOther, DeltaNormMQScore, DeltaNormTotalPRMScore,'
		set @S = @S +  ' RankTotalPRMScore, RankFScore, DelM, Normalized_Score'
		set @S = @S + ' )'
		set @S = @S + ' SELECT IP.Peptide_ID_New, I.MQScore, I.TotalPRMScore, I.MedianPRMScore, '
		set @S = @S +  ' I.FractionY, I.FractionB, I.Intensity, I.PValue, I.FScore, '
		set @S = @S +  ' I.DeltaScore, I.DeltaScoreOther, I.DeltaNormMQScore, I.DeltaNormTotalPRMScore, '
		set @S = @S +  ' I.RankTotalPRMScore, I.RankFScore, I.DelM, I.Normalized_Score'
		set @S = @S + ' FROM #Imported_Peptides AS IP INNER JOIN'
		set @S = @S +   ' ' + @PeptideDBPath + '.dbo.T_Score_Inspect AS I ON IP.Peptide_ID_Original = I.Peptide_ID'
		set @S = @S + ' ORDER BY IP.Peptide_ID_New'
		--
		exec @result = sp_executesql @S
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @result <> 0 
		begin
			rollback transaction @transName
			set @message = 'Error executing dynamic SQL for T_Score_Inspect for ' + @JobListMsgStr
			set @myError = 50022
			goto Done
		end
		--
		Set @numAddedPeptideHitScores = @myRowCount
		
		-- Populate #PeptideHitStats (used below to update stats in T_Mass_Tags)
		--
		INSERT INTO #PeptideHitStats (Mass_Tag_ID, Observation_Count, Normalized_Score_Max)
		SELECT	Mass_Tag_ID, 
				COUNT(*) AS Observation_Count, 
				MAX(Normalized_Score_Max) AS Normalized_Score_Max
		FROM (	SELECT	IP.Seq_ID AS Mass_Tag_ID, 
						IP.Scan_Number, 
						MAX(ISNULL(I.Normalized_Score, 0)) AS Normalized_Score_Max
				FROM #Imported_Peptides AS IP LEFT OUTER JOIN
					 T_Score_Inspect AS I ON IP.Peptide_ID_New = I.Peptide_ID
				GROUP BY IP.Seq_ID, IP.Scan_Number
				) AS SubQ
		GROUP BY SubQ.Mass_Tag_ID	
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		Set @ResultTypeValid = 1
	End

	If @ResultType = 'MSG_Peptide_Hit'
	Begin
		-----------------------------------------------------------
		-- Add new entries to T_Score_MSGFDB
		-----------------------------------------------------------
		--
		set @S = ''
		set @S = @S + 'INSERT INTO T_Score_MSGFDB ('
		set @S = @S +  ' Peptide_ID, FragMethod, PrecursorMZ, DelM, '
		set @S = @S +  ' DeNovoScore, MSGFScore, SpecProb, RankSpecProb, '
		set @S = @S +  ' PValue, Normalized_Score, FDR, PepFDR'
		set @S = @S + ' )'
		set @S = @S + ' SELECT IP.Peptide_ID_New, M.FragMethod, M.PrecursorMZ, M.DelM, '
		set @S = @S +  ' M.DeNovoScore, M.MSGFScore, M.SpecProb, M.RankSpecProb, '
		set @S = @S +  ' M.PValue, M.Normalized_Score, M.FDR, M.PepFDR'
		set @S = @S + ' FROM #Imported_Peptides AS IP INNER JOIN'
		set @S = @S +   ' ' + @PeptideDBPath + '.dbo.T_Score_MSGFDB AS M ON IP.Peptide_ID_Original = M.Peptide_ID'
		set @S = @S + ' ORDER BY IP.Peptide_ID_New'
		--
		exec @result = sp_executesql @S
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @result <> 0 
		begin
			rollback transaction @transName
			set @message = 'Error executing dynamic SQL for T_Score_MSGFDB for ' + @JobListMsgStr
			set @myError = 50022
			goto Done
		end
		--
		Set @numAddedPeptideHitScores = @myRowCount
		
		-- Populate #PeptideHitStats (used below to update stats in T_Mass_Tags)
		--
		INSERT INTO #PeptideHitStats (Mass_Tag_ID, Observation_Count, Normalized_Score_Max)
		SELECT	Mass_Tag_ID, 
				COUNT(*) AS Observation_Count, 
				MAX(Normalized_Score_Max) AS Normalized_Score_Max
		FROM (	SELECT	IP.Seq_ID AS Mass_Tag_ID, 
						IP.Scan_Number, 
						MAX(ISNULL(M.Normalized_Score, 0)) AS Normalized_Score_Max
				FROM #Imported_Peptides AS IP LEFT OUTER JOIN
					 T_Score_MSGFDB AS M ON IP.Peptide_ID_New = M.Peptide_ID
				GROUP BY IP.Seq_ID, IP.Scan_Number
				) AS SubQ
		GROUP BY SubQ.Mass_Tag_ID	
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		Set @ResultTypeValid = 1
	End

	If @ResultTypeValid = 0
	Begin
		rollback transaction @transName
		set @message = 'Invalid ResultType for ' + @JobListMsgStr + ' (' + @ResultType + ')'
		set @myError = 50023
		goto Done	
	End

	-----------------------------------------------------------
	-- Add new entries to T_Score_Discriminant
	-- Note that PassFilt and MScore are estimated for XTandem, Inspect, and MSGFDB data
	--  PassFilt was set to 1
	--  MScore was set to 10.75
	-----------------------------------------------------------
	--
	set @S = ''
	set @S = @S + ' INSERT INTO T_Score_Discriminant ('
	set @S = @S +  ' Peptide_ID, MScore, DiscriminantScore, DiscriminantScoreNorm,'
	set @S = @S +  ' PassFilt, Peptide_Prophet_FScore, Peptide_Prophet_Probability, MSGF_SpecProb'
	set @S = @S + ' )'
	set @S = @S + ' SELECT IP.Peptide_ID_New, MScore, DiscriminantScore, DiscriminantScoreNorm,'
	set @S = @S +        ' PassFilt, Peptide_Prophet_FScore, Peptide_Prophet_Probability, MSGF_SpecProb'
	set @S = @S + ' FROM #Imported_Peptides AS IP INNER JOIN'
	set @S = @S +   ' ' + @PeptideDBPath + '.dbo.T_Score_Discriminant AS SD ON IP.Peptide_ID_Original = SD.Peptide_ID'
	set @S = @S + ' ORDER BY IP.Peptide_ID_New'
	--
	exec @result = sp_executesql @S
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @result <> 0 
	begin
		rollback transaction @transName
		set @message = 'Error executing dynamic SQL for T_Score_Discriminant for ' + @JobListMsgStr
		set @myError = 50024
		goto Done
	end
	--
	Set @numAddedDiscScores = @myRowCount

	If @numAddedPeptideHitScores <> @PeptideCountCurrentBatch OR @numAddedDiscScores <> @PeptideCountCurrentBatch
	Begin
		rollback transaction @transName
		set @message = 'Analysis counts not identical for ' + @JobListMsgStr + '; ' + convert(varchar(11), @PeptideCountCurrentBatch) + ' vs. ' + convert(varchar(11), @numAddedPeptideHitScores) + ' vs. ' + convert(varchar(11), @numAddedDiscScores)
		set @myError = 50025
		goto Done
	End

	-----------------------------------------------------------
	-- Commit changes to T_Peptides, T_Score_Sequest, etc. if we made it this far
	-----------------------------------------------------------
	-- 
	commit transaction @transName
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Error committing transaction for ' + @JobListMsgStr
		Set @myError = 50027
		goto Done
	end

	-----------------------------------------------------------
	-- Update existing entries in T_Mass_Tags_NET that have 
	-- PNET Values different than those in #ImportedMassTags
	-----------------------------------------------------------
	--
	UPDATE T_Mass_Tags_NET
	SET PNET = IMT.GANET_Predicted, PNET_Variance = 0
	FROM #ImportedMassTags AS IMT INNER JOIN
	     T_Mass_Tags_NET AS MTN ON IMT.Mass_Tag_ID = MTN.Mass_Tag_ID
	WHERE MTN.PNET <> IMT.GANET_Predicted
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem updating PNET entries in T_Mass_Tags_NET for ' + @JobListMsgStr
		Set @myError = 50014
		goto Done
	end

	-----------------------------------------------------------
	-- Add new entries to T_Mass_Tags_NET
	-----------------------------------------------------------
	--
	INSERT INTO T_Mass_Tags_NET (
		Mass_Tag_ID, PNET, PNET_Variance
		)
	SELECT IMT.Mass_Tag_ID, IMT.GANET_Predicted, 0 AS PNET_Variance
	FROM #ImportedMassTags AS IMT LEFT OUTER JOIN
	     T_Mass_Tags_NET AS MTN ON IMT.Mass_Tag_ID = MTN.Mass_Tag_ID
	WHERE MTN.Mass_Tag_ID IS NULL
	ORDER BY IMT.Mass_Tag_ID
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem appending new entries to T_Mass_Tags_NET for ' + @JobListMsgStr
		Set @myError = 50015
		goto Done
	end

	-----------------------------------------------------------
	-- Add new proteins T_Proteins
	-----------------------------------------------------------
	--
	INSERT INTO T_Proteins (Reference)
	SELECT DISTINCT PPI.Reference
	FROM #PeptideToProteinMapImported AS PPI LEFT OUTER JOIN
		 T_Proteins ON PPI.Reference = T_Proteins.Reference
	WHERE T_Proteins.Reference Is Null
	ORDER BY PPI.Reference
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem appending new entries to T_Proteins for ' + @JobListMsgStr
		Set @myError = 50016
		goto Done
	end


	-----------------------------------------------------------
	-- Populate Ref_ID_New in #PeptideToProteinMapImported
	-----------------------------------------------------------
	--
	UPDATE #PeptideToProteinMapImported
	SET Ref_ID_New = T_Proteins.Ref_ID
	FROM #PeptideToProteinMapImported AS PPI INNER JOIN
		 T_Proteins ON PPI.Reference = T_Proteins.Reference
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem populating Ref_ID_New column in #PeptideToProteinMapImported for ' + @JobListMsgStr
		Set @myError = 50017
		goto Done
	end


	-----------------------------------------------
    -- Check for entries in #PeptideToProteinMapImported with conflicting
    --  Cleavage_State or Terminus_State values
    -- If any conflicts are found, update Cleavage_State and Terminus_State to Null,
    --  and allow NamePeptides to populate those fields
    -----------------------------------------------
 
    UPDATE PPI
	SET Cleavage_State = NULL, Terminus_State = NULL
	FROM #PeptideToProteinMapImported AS PPI INNER JOIN
			(	SELECT DISTINCT PPI.Seq_ID, PPI.Ref_ID_New
				FROM #PeptideToProteinMapImported PPI INNER JOIN
					 #PeptideToProteinMapImported PPI_Compare ON 
						PPI.Seq_ID = PPI_Compare.Seq_ID AND 
						PPI.Ref_ID_New = PPI_Compare.Ref_ID_New
				WHERE ISNULL(PPI.Cleavage_State, 0) <> ISNULL(PPI_Compare.Cleavage_State, 0) OR
					  ISNULL(PPI.Terminus_State, 0) <> ISNULL(PPI_Compare.Terminus_State, 0)
			) AS DiffQ ON 
				PPI.Ref_ID_New = DiffQ.Ref_ID_New AND 
				PPI.Seq_ID = DiffQ.Seq_ID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Error looking for conflicting entries in #PeptideToProteinMapImported for ' + @JobListMsgStr
		set @myError = 50018
		goto Done
	end	
    

	-----------------------------------------------------------
	-- Add new entries to T_Mass_Tag_to_Protein_Map
	-----------------------------------------------------------
	--
	INSERT INTO T_Mass_Tag_to_Protein_Map (
		Mass_Tag_ID, Ref_ID, Cleavage_State, Terminus_State
		)
	SELECT DISTINCT PPI.Seq_ID, PPI.Ref_ID_New, PPI.Cleavage_State, PPI.Terminus_State
	FROM #PeptideToProteinMapImported As PPI LEFT OUTER JOIN 
		 T_Mass_Tag_to_Protein_Map As MTPM ON 
			PPI.Seq_ID = MTPM.Mass_Tag_ID AND
			PPI.Ref_ID_New = MTPM.Ref_ID
	WHERE MTPM.Mass_Tag_ID Is Null
	ORDER BY PPI.Seq_ID, PPI.Ref_ID_New
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem appending new entries to T_Mass_Tag_to_Protein_Map for ' + @JobListMsgStr
		Set @myError = 50019
		goto Done
	end

	-----------------------------------------------------------
	-- Update the stats in T_Mass_Tags
	-- Note that these are approximations and will get computed properly
	--  using ComputeMassTagsAnalysisCounts, which is called at the
	--  completion of UpdateMassTagsFromAvailableAnalyses
	-- This operation uses #PeptideHitStats, which was populated above
	-----------------------------------------------------------
	--
	UPDATE T_Mass_Tags
	SET Last_Affected = GetDate(), 
		Number_Of_Peptides = Number_Of_Peptides + StatsQ.Observation_Count, 
		High_Normalized_Score = CASE WHEN StatsQ.Normalized_Score_Max > High_Normalized_Score
								THEN StatsQ.Normalized_Score_Max
								ELSE High_Normalized_Score
								END
	FROM T_Mass_Tags INNER JOIN 
		 #PeptideHitStats AS StatsQ ON T_Mass_Tags.Mass_Tag_ID = StatsQ.Mass_Tag_ID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Problem updating stats in T_Mass_Tags for ' + @JobListMsgStr
		Set @myError = 50026
		goto Done
	end

	-----------------------------------------------------------
	-- Update Cleavage_State_Max in T_Mass_Tags
	-----------------------------------------------------------
	--
	UPDATE T_Mass_Tags
	SET Cleavage_State_Max = LookupQ.Cleavage_State_Max
	FROM T_Mass_Tags MT
	     INNER JOIN ( SELECT Seq_ID AS Mass_Tag_ID,
	                  Max(IsNull(Cleavage_State, 0)) AS Cleavage_State_Max
	                  FROM #PeptideToProteinMapImported
	                  GROUP BY Seq_ID) LookupQ
	       ON MT.Mass_Tag_ID = LookupQ.Mass_Tag_ID
	WHERE LookupQ.Cleavage_State_Max > IsNull(MT.Cleavage_State_Max, 0)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem updating Cleavage_State_Max in T_Mass_Tags for ' + @JobListMsgStr
		Set @myError = 50028
		goto Done
	end


	-----------------------------------------------------------
	-- Call ComputeMaxObsAreaByJob to populate the Max_Obs_Area_In_Job column
	--  for each Job in #TmpJobsInBatch
	--
	-- In addition, update analysis job state and column RowCount_Loaded
	-- Lastly, also check each job for "no peptides added"
	-----------------------------------------------------------
	-- 
	SELECT @JobCurrent = MIN(Job)-1
	FROM #TmpJobsInBatch
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	If @myRowCount = 0
		Set @Continue = 0
	Else
		Set @Continue = 1
	
	While @Continue = 1
	Begin -- <a3>
		SELECT TOP 1 @JobCurrent = Job
		FROM #TmpJobsInBatch
		Where Job > @JobCurrent
		ORDER BY Job
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		If @myRowCount = 0
			Set @Continue = 0
		Else
		Begin -- <b3>
			Set @JobStrCurrent = Convert(varchar(19), @JobCurrent)
			
			Set @MatchCount = 0
			
			SELECT @MatchCount = COUNT(*)
			FROM #Imported_Peptides
			WHERE Job = @JobCurrent
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			if (@MatchCount = 0) Or @myError <> 0
			Begin
				-- No peptides were added for this job
				-- Raise an error
				set @message = 'No peptides imported for job ' + @JobStrCurrent
				set @messageType = 'Error'
				set @StateCurrentJob = @JobUpdateFailed -- 'Load Failed'
			End
			Else
			Begin
				set @message = Convert(varchar(12), @MatchCount) + ' peptides updated into mass tags for job ' + @JobStrCurrent
				set @messageType = 'Normal'
				set @StateCurrentJob = @MassTagUpdatedState -- 'Mass Tag Updated'
			End
			
			UPDATE T_Analysis_Description
			SET State = @StateCurrentJob, 
				RowCount_Loaded = @MatchCount,
				PMTs_Last_Affected = GetDate()
			WHERE Job = @JobCurrent
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			
			execute PostLogEntry @messageType, @message, 'UpdateMassTagsFromMultipleAnalysis'
			
			Set @message = ''
						
			If @StateCurrentJob = @MassTagUpdatedState
				Exec @result = ComputeMaxObsAreaByJob @JobFilterList = @JobStrCurrent

			UPDATE #Tmp_Available_Jobs
			SET Processed = 1
			WHERE Job = @JobCurrent
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

		End -- </b3>
	End -- </a3>


	-----------------------------------------------------------
	-- Add a log entry for the number of peptides imported and the time elapsed
	-----------------------------------------------------------

	Declare @TimeElapsedSeconds int
	Set @TimeElapsedSeconds = DateDiff(second, @ImportStartTime, GetDate())
	
	set @message = 'Batch loaded ' + Convert(varchar(12), @PeptideCountCurrentBatch) + ' peptides in ' + Convert(varchar(12), @TimeElapsedSeconds) + ' seconds for ' + Convert(varchar(12), @JobCountCurrentBatch) + ' job'
	If @JobCountCurrentBatch <> 1
		set @message = @message + 's'

	Declare @PeptidesPerSecond decimal(9,1)
	If @TimeElapsedSeconds > 1
		Set @PeptidesPerSecond = Convert(decimal(9,1), Round(@PeptideCountCurrentBatch / Convert(real, @TimeElapsedSeconds), 1))
	Else
		Set @PeptidesPerSecond = @PeptideCountCurrentBatch
		
	set @message = @message + '; ' + Convert(varchar(12), @PeptidesPerSecond) + ' peptides/second'
	
	execute PostLogEntry 'Normal', @message, 'UpdateMassTagsFromMultipleAnalysis'
	Set @message = ''

Done:

	-- Populate @errorReturn	
	set @errorReturn = @myError

	return @errorReturn


GO
GRANT VIEW DEFINITION ON [dbo].[UpdateMassTagsFromMultipleAnalyses] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[UpdateMassTagsFromMultipleAnalyses] TO [MTS_DB_Lite] AS [dbo]
GO
