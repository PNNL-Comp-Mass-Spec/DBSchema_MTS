/****** Object:  StoredProcedure [dbo].[CheckFilterForAvailableAnalysesBulk] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.CheckFilterForAvailableAnalysesBulk
/****************************************************
**
**	Desc: 	Compare the peptides for each of the available analyses 
**			against the given filter set
**
**	Return values: 0:  success, otherwise, error code
**
**	Parameters:
**
**	Auth:	grk
**	Date:	11/2/2001
**			03/01/2004 mem - Switched from using a cursor to using temporary tables; this greatly improves efficiency of checking whether jobs need to be checked against the filter
**								 Additionally, implemented the @ReprocessAllJobs option and added the @numJobsToProcess parameter
**		    07/03/2004 mem - Changed to use of Process_State and ResultType fields for choosing next job
**			08/07/2004 mem - Added @ProcessStateMatch, @NextProcessState, and @numJobsProcessed parameters
**			09/06/2004 mem - Now processing multiple jobs simultaneously, but with a maximum number of peptides to process per bulk operation
**			09/12/2004 mem - Switched to using T_Peptide_to_Protein_Map
**		    11/08/2004 mem - Now looking for jobs in a state > @ProcessStateMatch that have not been checked against @filterSetID; resets state to @ProcessStateMatch for any found
**						   - Additionally, no longer advancing the state of processed jobs, since this SP could easily be called several times for different filters within the same update cycle
**			12/13/2004 mem - Updated to excluded MASIC jobs
**			12/28/2004 mem - Fixed bug that was reprocessing jobs that didn't need to be reprocessed
**			01/31/2005 mem - Updated to delete entries in T_Analysis_Filter_Flags for jobs in State @ProcessStateMatch with Filter ID @filterSetID
**			03/25/2005 mem - Fixed bug that used the peptide sequence in T_Peptides to determine peptide length, rather than T_Sequences.Clean_Sequence
**			03/26/2005 mem - Updated call to GetThresholdsForFilterSet to include @ProteinCount and @TerminusState criteria
**			11/24/2005 mem - Now updating Last_Affected when rolling job states back to state @ProcessStateMatch if needing to reprocess the filters
**			11/26/2005 mem - Now rolling back job states to @ProcessStateFilterEvaluationRequired rather than to state @ProcessStateMatch
**			12/12/2005 mem - Updated to support XTandem results
**			07/04/2006 mem - Added parameter @ProcessStateAllStepsComplete
**    
*****************************************************/
(
	@filterSetID int,
	@ReprocessAllJobs tinyint = 0,				-- If nonzero, then will reprocess all jobs against the given filter
	@ProcessStateMatch int = 60,
	@ProcessStateFilterEvaluationRequired int = 65,
	@ProcessStateAllStepsComplete int = 70,
	@numJobsToProcess int = 50000,
	@numJobsProcessed int = 0 OUTPUT,
	@infoOnly tinyint = 0
)
AS
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	declare @message varchar(255)
	declare @Job int
	declare @PeptideCountForJob int
	declare @SkipProcessedJobs tinyint		-- If nonzero, then will skip jobs already checked against filter @filterSetID
	
	Declare @LastJobPolled int
	declare @peptideMatchCount int
	declare	@peptideUnmatchedCount int
	
	declare @jobMatchCount int
	declare @intContinue int	

	declare @JobAvailableCount int 
	declare @AddnlJobAvailableCount int
	declare @TotalHitCount int

	declare @PeptidesInBatch int
	declare @JobsInBatch int
	declare @ResultTypeID int

	declare @MaxPeptidesPerBatch int
	Set @MaxPeptidesPerBatch = 250000

	declare @ResultType varchar(32)
	Set @ResultType = 'Unknown'
	
	declare @filterSetStr varchar(11)
	Set @filterSetStr = Convert(varchar(11), @filterSetID)

	declare @Sql varchar(1024)

	set @TotalHitCount = 0
	set @numJobsProcessed = 0


	-----------------------------------------------------------
	-- Create the temporary tables to hold the jobs to process
	-----------------------------------------------------------
	CREATE TABLE #JobsToProcess (
		Job int,
		ResultType varchar(32),
		PeptideCount int
	)

	CREATE TABLE #JobsInBatch (
		Job int,
		PeptideCount int,
		MatchCount int NULL,
		UnmatchedCount int NULL
	)

	-----------------------------------------------
	-- Populate a temporary table with the list of known Result Types
	-----------------------------------------------
	CREATE TABLE #T_ResultTypeList (
		UniqueID int IDENTITY(1,1),
		ResultType varchar(64)
	)
	
	INSERT INTO #T_ResultTypeList (ResultType) Values ('Peptide_Hit')
	INSERT INTO #T_ResultTypeList (ResultType) Values ('XT_Peptide_Hit')


	-----------------------------------------------------------
	-- Define the filter threshold values
	-----------------------------------------------------------
	
	Declare @CriteriaGroupStart int,
			@CriteriaGroupMatch int,
			@SpectrumCountComparison varchar(2),		-- Not used in this SP
			@SpectrumCountThreshold int,				-- Not used in this SP
			@ChargeStateComparison varchar(2),
			@ChargeStateThreshold tinyint,
			@HighNormalizedScoreComparison varchar(2),
			@HighNormalizedScoreThreshold float,
			@CleavageStateComparison varchar(2),
			@CleavageStateThreshold tinyint,
			@PeptideLengthComparison varchar(2),
			@PeptideLengthThreshold smallint,
			@MassComparison varchar(2),
			@MassThreshold float,
			@DeltaCnComparison varchar(2),				-- Only used for Sequest results
			@DeltaCnThreshold float,					-- Only used for Sequest results
			@DeltaCn2Comparison varchar(2),				-- Used for both Sequest and XTandem results
			@DeltaCn2Threshold float,					-- Used for both Sequest and XTandem results
			@DiscriminantScoreComparison varchar(2),
			@DiscriminantScoreThreshold float,
			@NETDifferenceAbsoluteComparison varchar(2),
			@NETDifferenceAbsoluteThreshold float,
			@DiscriminantInitialFilterComparison varchar(2),
			@DiscriminantInitialFilterThreshold float,
			@ProteinCountComparison varchar(2),			-- Not used in this SP
			@ProteinCountThreshold int,					-- Not used in this SP
			@TerminusStateComparison varchar(2),
			@TerminusStateThreshold tinyint,
			@XTandemHyperscoreComparison varchar(2),	-- Only used for XTandem results
			@XTandemHyperscoreThreshold real,			-- Only used for XTandem results
			@XTandemLogEValueComparison varchar(2),		-- Only used for XTandem results
			@XTandemLogEValueThreshold real				-- Only used for XTandem results

	-----------------------------------------------------------
	-- Validate that @FilterSetID is defined in V_Filter_Sets_Import
	-- Do this by calling GetThresholdsForFilterSet and examining @FilterGroupMatch
	-----------------------------------------------------------
	--
	Set @CriteriaGroupStart = 0
	Set @CriteriaGroupMatch = 0
	Exec @myError = GetThresholdsForFilterSet @FilterSetID, @CriteriaGroupStart, @CriteriaGroupMatch OUTPUT, @message OUTPUT
	
	if @myError <> 0
	begin
		if len(@message) = 0
			set @message = 'Could not validate filter set ID ' + @filterSetStr + ' using GetThresholdsForFilterSet'		
		goto Done
	end
	
	if @CriteriaGroupMatch = 0 
	begin
		set @message = 'Filter set ID ' + @filterSetStr + ' not found using GetThresholdsForFilterSet'
		set @myError = 51100
		goto Done
	end


	-----------------------------------------------------------
	-- Set up the Peptide stat tables
	-----------------------------------------------------------

	-- Create a temporary table to store the peptides for the jobs to process
	-- Necessary if @infoOnly = 1, and also useful to reduce the total additions to the database's transaction log
	CREATE TABLE #PeptideStats (
		[Analysis_ID] [int] NOT NULL ,
		[Peptide_ID] [int] NOT NULL ,
		[PeptideLength] [smallint] NOT NULL,
		[Charge_State] [smallint] NOT NULL,
		[XCorr] [float] NOT NULL,							-- Only used for Sequest data
		[Hyperscore] [real] NOT NULL,						-- Only used for XTandem data
		[Log_EValue] [real] NOT NULL,						-- Only used for XTandem data
		[Cleavage_State] [tinyint] NOT NULL,
		[Terminus_State] [tinyint] NOT NULL,
		[Mass] [float] NOT NULL,
		[DeltaCn] [float] NOT NULL,							-- Only used for Sequest data
		[DeltaCn2] [float] NOT NULL,
		[Discriminant_Score] [real] NOT NULL,
		[NET_Difference_Absolute] [float] NOT NULL,
		[PassFilt] [int] NOT NULL,							-- aka Discriminant_Initial_Filter; Always 1 for XTandem data
		[Pass_FilterSet_Group] [tinyint] NOT NULL			-- 0 or 1
	) ON [PRIMARY]
	
	CREATE UNIQUE INDEX #IX_PeptideStats ON #PeptideStats ([Peptide_ID])

	
	-----------------------------------------------------------
	-- Set @SkipProcessedJobs to 1 when the process state to match is
	-- the same as @ProcessStateFilterEvaluationRequired
	-----------------------------------------------------------
	If @ProcessStateMatch = @ProcessStateFilterEvaluationRequired
		Set @SkipProcessedJobs = 1


	-----------------------------------------------------------
	-- process list of analyses 
	-----------------------------------------------------------

	if @ReprocessAllJobs <> 0
	Begin
		-- Reprocessing all jobs, assure that @SkipProcessedJobs is 0
		Set @SkipProcessedJobs = 0
		
		-- Delete entries from T_Analysis_Filter_Flags for @filterSetID
		DELETE FROM T_Analysis_Filter_Flags
		WHERE Filter_ID = @filterSetID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0
		 begin
			set @message = 'Error deleting existing entries in T_Analysis_Filter_Flags matching filter set ' + @filterSetStr
			set @myError = 51101
			goto Done
		 end

		-- Delete entries from T_Peptide_Filter_Flags for @filterSetID
		DELETE FROM T_Peptide_Filter_Flags
		WHERE Filter_ID = @filterSetID
		--
		SELECT @myError = @@error, @peptideMatchCount = @@RowCount
		--
		if @myError <> 0
		 begin
			set @message = 'Error deleting existing entries in T_Peptide_Filter_Flags matching filter set ' + @filterSetStr
			set @myError = 51102
			goto Done
		 end
		else
		 begin
			-- Post an entry to T_Log_Entries
			Set @message = 'Re-checking all analyses against filter set ' + @filterSetStr + ' (Deleted ' + convert(varchar(11), @peptideMatchCount) + ' rows from T_Peptide_Filter_Flags)'
			Execute PostLogEntry 'Normal', @message, 'CheckFilterForAvailableAnalyses'
			Set @message = ''
		 end

	End


	-----------------------------------------------------------
	-- Update jobs in T_Analysis_Description that have a state
	-- between @ProcessStateFilterEvaluationRequired+1 and 
	-- @ProcessStateAllStepsComplete but have not yet been tested 
	-- against this filter
	-----------------------------------------------------------
	--
	UPDATE T_Analysis_Description
	SET Process_State = @ProcessStateFilterEvaluationRequired,
	    Last_Affected = GETDATE()
	FROM T_Analysis_Description AS TAD INNER JOIN
		 #T_ResultTypeList AS RTL ON TAD.ResultType = RTL.ResultType LEFT OUTER JOIN
		 T_Analysis_Filter_Flags AS AFF ON TAD.Job = AFF.Job AND AFF.Filter_ID = @filterSetID
	WHERE (TAD.Process_State BETWEEN @ProcessStateFilterEvaluationRequired+1 AND @ProcessStateAllStepsComplete) AND 
		  AFF.Job Is Null
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Error resetting Process_State for jobs'
		set @myError = 51103
		goto Done
	end

	if @myRowCount > 0
	Begin
		-- make log entry
		Declare @TextNum varchar(9)
		Set @TextNum = Convert(varchar(9), @ProcessStateFilterEvaluationRequired)
		
		Set @message = 'Jobs were found with state > ' + @TextNum + ' which have not been checked against Filter Set ID ' + Convert(varchar(9), @filterSetID) + '; their states have been reset to ' + @TextNum
		execute PostLogEntry 'Warning', @message, 'CheckFilterForAvailableAnalyses'
		Set @message = ''
	End


	if @ReprocessAllJobs = 0 and @SkipProcessedJobs = 0
	Begin
	
		-----------------------------------------------------------
		-- Make sure jobs in state @ProcessStateMatch do not have
		-- an entry in T_Analysis_Filter_Flags
		-----------------------------------------------------------
	
		DELETE T_Analysis_Filter_Flags
		FROM T_Analysis_Filter_Flags AS AFF INNER JOIN
			 T_Analysis_Description AS TAD ON 
			 AFF.Job = TAD.Job 
		WHERE (TAD.Process_State = @ProcessStateMatch) AND (AFF.Filter_ID = @filterSetID)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0
		 begin
			set @message = 'Error deleting entries in T_Analysis_Filter_Flags for jobs in state ' + convert(varchar(9), @ProcessStateMatch)
			set @myError = 51104
			goto Done
		 end
	End

	-----------------------------------------------------------
	-- Get list of analyses that need to be checked against @filterSetID
	-----------------------------------------------------------
	--
	INSERT INTO #JobsToProcess (Job, ResultType, PeptideCount)
	SELECT TAD.Job, TAD.ResultType, IsNull(COUNT(P.Peptide_ID), 0) AS PeptideCount
	FROM T_Analysis_Description AS TAD INNER JOIN
		 #T_ResultTypeList AS RTL ON TAD.ResultType = RTL.ResultType LEFT OUTER JOIN 
		 T_Peptides AS P ON TAD.Job = P.Analysis_ID
	WHERE TAD.Process_State = @ProcessStateMatch AND
		 TAD.Job NOT IN (	SELECT Job
							FROM T_Analysis_Filter_Flags
							WHERE Filter_ID = @filterSetID)
	GROUP BY TAD.ResultType, TAD.Job
	ORDER BY TAD.ResultType, TAD.Job
	--
	SELECT @myError = @@error, @JobAvailableCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Error populating #JobsToProcess with the jobs to process'
		set @myError = 51105
		goto Done
	end

	-----------------------------------------------------------
	-- Lookup the first ResultType
	-----------------------------------------------------------
	Set @ResultTypeID = 0
	--	
	SELECT TOP 1 @ResultType = ResultType, @ResultTypeID = UniqueID
	FROM #T_ResultTypeList
	WHERE UniqueID > @ResultTypeID
	ORDER BY UniqueID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	
	-- Loop through the available jobs, and process them in groups
	-- In addition, group the jobs by ResultType
	--
	While Len(IsNull(@ResultType, '')) > 0 And @myError = 0 And @numJobsProcessed < @numJobsToProcess
	Begin -- <a>
		-- See if at least one job is available with ResultType = @ResultType
		SELECT TOP 1 @job = Job, @PeptideCountForJob = PeptideCount
		FROM #JobsToProcess
		WHERE ResultType = @ResultType
		ORDER BY Job
		--
		SELECT @myError = @@error, @JobAvailableCount = @@rowcount
		--
		if @myError <> 0
		begin
			set @message = 'Could not get next entry from #JobsToProcess'
			set @myError = 51106
			goto Done
		end

		If @JobAvailableCount = 0
		 Begin
			-----------------------------------------------------------
			-- No more available jobs for ResultType @ResultType
			-- Lookup the next ResultType
			-----------------------------------------------------------
			--
			SELECT TOP 1 @ResultType = ResultType, @ResultTypeID = UniqueID
			FROM #T_ResultTypeList
			WHERE UniqueID > @ResultTypeID
			ORDER BY UniqueID
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			
			-- If no more ResultTypes, then set @ResultType to '' so that the While Loop exits
			If @myRowCount = 0
				Set @ResultType = ''
		 End
		Else 
		 Begin -- <b>
			-- Populate #JobsInBatch with jobs from #JobsToProcess,
			-- limiting the list to at most @MaxPeptidesPerBatch peptides
		
			-- Delete this job from #JobsToProcess
			DELETE FROM #JobsToProcess WHERE Job = @Job
		
			-- Reset #JobsInBatch
			DELETE FROM #JobsInBatch
			
			INSERT INTO #JobsInBatch (Job, PeptideCount, MatchCount, UnmatchedCount)
			VALUES (@job, @PeptideCountForJob, 0, 0)

			Set @PeptidesInBatch = @PeptideCountForJob
			Set @JobsInBatch = 1
			Set @AddnlJobAvailableCount = 1
			
			-- Add additional jobs to #JobsInBatch
			While @PeptidesInBatch < @MaxPeptidesPerBatch AND @AddnlJobAvailableCount > 0 AND @numJobsProcessed + @JobsInBatch < @numJobsToProcess
			Begin -- <c>
				SELECT TOP 1 @job = Job, @PeptideCountForJob = PeptideCount
				FROM #JobsToProcess
				WHERE ResultType = @ResultType
				ORDER BY Job
				--
				SELECT @myError = @@error, @AddnlJobAvailableCount = @@rowcount
			
				If @AddnlJobAvailableCount = 1
				Begin
					If @PeptidesInBatch + @PeptideCountForJob < @MaxPeptidesPerBatch
					Begin
						-- Delete this job from #JobsToProcess
						DELETE FROM #JobsToProcess WHERE Job = @Job
					
						INSERT INTO #JobsInBatch (Job, PeptideCount, MatchCount, UnmatchedCount)
						VALUES (@job, @PeptideCountForJob, 0, 0)

						Set @PeptidesInBatch = @PeptidesInBatch + @PeptideCountForJob
						Set @JobsInBatch = @JobsInBatch + 1
					End					
					Else
						Set @AddnlJobAvailableCount = 0
				End
			End -- </c>
		
			----------------------------------------
			-- Process the jobs in #JobsInBatch
			--
			-- If necessary, remove entries in T_Analysis_Filter_Flags
			-- for jobs in #JobsInBatch with entries for @FilterSetID
			-----------------------------------------------------------
			--
			Set @jobMatchCount = 0
			--
			SELECT @jobMatchCount = COUNT(*) 
			FROM T_Analysis_Filter_Flags INNER JOIN #JobsInBatch ON
				 T_Analysis_Filter_Flags.Job = #JobsInBatch.Job
			WHERE Filter_ID = @FilterSetID
			--
			SELECT @myError = @@error, @myRowCount = @@RowCount
			--
			If @myError <> 0
			Begin
				set @message = 'Could not get analysis job flag information for jobs in #JobsInBatch'
				goto Done
			End
			
			If @jobMatchCount > 0 
			Begin
				-- Delete entries for jobs and given filter from T_Analysis_Filter_Flags
				DELETE T_Analysis_Filter_Flags
				FROM T_Analysis_Filter_Flags INNER JOIN #JobsInBatch ON
					 T_Analysis_Filter_Flags.Job = #JobsInBatch.Job
				WHERE Filter_ID = @FilterSetID
				--
				SELECT @myError = @@error, @myRowCount = @@RowCount
			End

			-- Populate the PeptideStats temporary table
			-- Initially set @myError to a non-zero value in case @ResultType is invalid for this SP
			-- Note that this error code is used below so update in both places if changing
			--
			set @myError = 51200
			If @ResultType = 'Peptide_Hit'
			Begin
				INSERT INTO #PeptideStats (	Analysis_ID, Peptide_ID, PeptideLength, Charge_State,
											XCorr, Hyperscore, Log_EValue, Cleavage_State, Terminus_State, Mass,
											DeltaCn, DeltaCn2, Discriminant_Score,
											NET_Difference_Absolute, PassFilt, Pass_FilterSet_Group)
				SELECT  Analysis_ID, Peptide_ID, PeptideLength, Charge_State,
						XCorr, 0 AS Hyperscore, 0 AS Log_EValue, Max(Cleavage_State), Max(Terminus_State), MH, 
						DeltaCN, DeltaCN2, DiscriminantScoreNorm, NET_Difference_Absolute, PassFilt, 0 as Pass_FilterSet_Group
				FROM (	SELECT	P.Analysis_ID, 
								P.Peptide_ID, 
								Len(TS.Clean_Sequence) AS PeptideLength, 
								IsNull(P.Charge_State, 0) AS Charge_State,
								IsNull(S.XCorr, 0) AS XCorr, 
								IsNull(PP.Cleavage_State, 0) AS Cleavage_State, 
								IsNull(PP.Terminus_State, 0) AS Terminus_State, 
								IsNull(P.MH, 0) AS MH,
								IsNull(S.DeltaCn, 0) AS DeltaCn, 
								IsNull(S.DeltaCn2, 0) AS DeltaCn2, 
								IsNull(SD.DiscriminantScoreNorm, 0) AS DiscriminantScoreNorm,
								CASE WHEN IsNull(P.GANET_Obs, 0) = 0 AND IsNull(TS.GANET_Predicted, 0) = 0
								THEN 0
								ELSE Abs(IsNull(P.GANET_Obs - TS.GANET_Predicted, 0))
								END AS NET_Difference_Absolute,
								SD.PassFilt AS PassFilt
						FROM T_Peptides AS P INNER JOIN T_Score_Sequest AS S ON P.Peptide_ID = S.Peptide_ID
							INNER JOIN T_Score_Discriminant AS SD ON P.Peptide_ID = SD.Peptide_ID
							INNER JOIN T_Peptide_to_Protein_Map AS PP ON P.Peptide_ID = PP.Peptide_ID
							INNER JOIN T_Sequence AS TS ON P.Seq_ID = TS.Seq_ID
							INNER JOIN #JobsInBatch ON P.Analysis_ID = #JobsInBatch.Job
					) AS LookupQ
				GROUP BY Analysis_ID, Peptide_ID, PeptideLength, Charge_State,
						XCorr, MH, DeltaCN, DeltaCN2, DiscriminantScoreNorm,
						NET_Difference_Absolute, PassFilt
				ORDER BY Peptide_ID
				--
				SELECT @myError = @@error, @myRowCount = @@RowCount
			End

			If @ResultType = 'XT_Peptide_Hit'
			Begin
				-- Note that PassFilt is estimated for XTandem data
				-- It is always 1 and is actually not used in this SP for XTandem data
				
				INSERT INTO #PeptideStats (	Analysis_ID, Peptide_ID, PeptideLength, Charge_State,
											XCorr, Hyperscore, Log_EValue, Cleavage_State, Terminus_State, Mass,
											DeltaCn, DeltaCn2, Discriminant_Score,
											NET_Difference_Absolute, PassFilt, Pass_FilterSet_Group)
				SELECT  Analysis_ID, Peptide_ID, PeptideLength, Charge_State,
						0 AS XCorr, Hyperscore, Log_EValue, Max(Cleavage_State), Max(Terminus_State), MH, 
						0 AS DeltaCN, DeltaCN2, DiscriminantScoreNorm, NET_Difference_Absolute, PassFilt, 0 as Pass_FilterSet_Group
				FROM (	SELECT	P.Analysis_ID, 
								P.Peptide_ID, 
								Len(TS.Clean_Sequence) AS PeptideLength, 
								IsNull(P.Charge_State, 0) AS Charge_State,
								IsNull(X.Hyperscore, 0) AS Hyperscore,
								IsNull(X.Log_EValue, 0) AS Log_EValue,
								IsNull(PP.Cleavage_State, 0) AS Cleavage_State, 
								IsNull(PP.Terminus_State, 0) AS Terminus_State, 
								IsNull(P.MH, 0) AS MH,
								IsNull(X.DeltaCn2, 0) AS DeltaCn2, 
								IsNull(SD.DiscriminantScoreNorm, 0) AS DiscriminantScoreNorm,
								CASE WHEN IsNull(P.GANET_Obs, 0) = 0 AND IsNull(TS.GANET_Predicted, 0) = 0
								THEN 0
								ELSE Abs(IsNull(P.GANET_Obs - TS.GANET_Predicted, 0))
								END AS NET_Difference_Absolute,
								SD.PassFilt AS PassFilt
						FROM T_Peptides AS P INNER JOIN T_Score_XTandem AS X ON P.Peptide_ID = X.Peptide_ID
							INNER JOIN T_Score_Discriminant AS SD ON P.Peptide_ID = SD.Peptide_ID
							INNER JOIN T_Peptide_to_Protein_Map AS PP ON P.Peptide_ID = PP.Peptide_ID
							INNER JOIN T_Sequence AS TS ON P.Seq_ID = TS.Seq_ID
							INNER JOIN #JobsInBatch ON P.Analysis_ID = #JobsInBatch.Job
					) AS LookupQ
				GROUP BY Analysis_ID, Peptide_ID, PeptideLength, Charge_State,
						Hyperscore, Log_EValue, MH, DeltaCN2, DiscriminantScoreNorm,
						NET_Difference_Absolute, PassFilt
				ORDER BY Peptide_ID
				--
				SELECT @myError = @@error, @myRowCount = @@RowCount
			End
			
			--
			If @myError <> 0 
			Begin
				If @myError = 51200
					set @message = 'Error populating #PeptideStats in CheckFilterForAvailableAnalyses; Invalid ResultType ''' + @ResultType + ''''
				Else
					set @message = 'Error populating #PeptideStats in CheckFilterForAvailableAnalyses'
				Goto done
			End

			 
			-- Now call GetThresholdsForFilterSet to get the thresholds to filter against
			-- Set Pass_FilterSet_Group to 1 in #PeptideStats for the matching peptides

			Set @CriteriaGroupStart = 0
			Set @CriteriaGroupMatch = 0
			Exec @myError = GetThresholdsForFilterSet @FilterSetID, @CriteriaGroupStart, @CriteriaGroupMatch OUTPUT, @message OUTPUT, 
											@SpectrumCountComparison OUTPUT,@SpectrumCountThreshold OUTPUT,
											@ChargeStateComparison OUTPUT,@ChargeStateThreshold OUTPUT,
											@HighNormalizedScoreComparison OUTPUT,@HighNormalizedScoreThreshold OUTPUT,
											@CleavageStateComparison OUTPUT,@CleavageStateThreshold OUTPUT,
											@PeptideLengthComparison OUTPUT,@PeptideLengthThreshold OUTPUT,
											@MassComparison OUTPUT,@MassThreshold OUTPUT,
											@DeltaCnComparison OUTPUT,@DeltaCnThreshold OUTPUT,
											@DeltaCn2Comparison OUTPUT,@DeltaCn2Threshold OUTPUT,
											@DiscriminantScoreComparison OUTPUT, @DiscriminantScoreThreshold OUTPUT,
											@NETDifferenceAbsoluteComparison OUTPUT, @NETDifferenceAbsoluteThreshold OUTPUT,
											@DiscriminantInitialFilterComparison OUTPUT, @DiscriminantInitialFilterThreshold OUTPUT,
											@ProteinCountComparison OUTPUT, @ProteinCountThreshold OUTPUT,
											@TerminusStateComparison OUTPUT, @TerminusStateThreshold OUTPUT,
											@XTandemHyperscoreComparison OUTPUT, @XTandemHyperscoreThreshold OUTPUT,
											@XTandemLogEValueComparison OUTPUT, @XTandemLogEValueThreshold OUTPUT
											

			While @CriteriaGroupMatch > 0
			Begin -- <d>

				-- Construct the Sql Update Query
				--
				Set @Sql = ''
				Set @Sql = @Sql + ' UPDATE #PeptideStats'
				Set @Sql = @Sql + ' SET Pass_FilterSet_Group = 1'
				Set @Sql = @Sql + ' WHERE  Charge_State ' +  @ChargeStateComparison +          Convert(varchar(11), @ChargeStateThreshold) + ' AND '

				If @ResultType = 'Peptide_Hit'
					Set @Sql = @Sql +        ' XCorr ' +         @HighNormalizedScoreComparison +  Convert(varchar(11), @HighNormalizedScoreThreshold) + ' AND '
				If @ResultType = 'XT_Peptide_Hit'
				Begin
					Set @Sql = @Sql +        ' Hyperscore ' +         @XTandemHyperscoreComparison +  Convert(varchar(11), @XTandemHyperscoreThreshold) + ' AND '
					Set @Sql = @Sql +        ' Log_EValue ' +         @XTandemLogEValueComparison +  Convert(varchar(11), @XTandemLogEValueThreshold) + ' AND '
				End
				
				Set @Sql = @Sql +        ' Cleavage_State ' + @CleavageStateComparison + Convert(varchar(11), @CleavageStateThreshold) + ' AND '
				Set @Sql = @Sql +        ' Terminus_State ' + @TerminusStateComparison + Convert(varchar(11), @TerminusStateThreshold) + ' AND '
				Set @Sql = @Sql +		 ' PeptideLength ' + @PeptideLengthComparison + Convert(varchar(11), @PeptideLengthThreshold) + ' AND '
				Set @Sql = @Sql +		 ' Mass ' + @MassComparison + Convert(varchar(11), @MassThreshold) + ' AND '

				If @ResultType = 'Peptide_Hit'
				Begin
					Set @Sql = @Sql +		 ' DeltaCn ' + @DeltaCnComparison + Convert(varchar(11), @DeltaCnThreshold) + ' AND '
					Set @Sql = @sql +        ' PassFilt ' + @DiscriminantInitialFilterComparison + Convert(varchar(11), @DiscriminantInitialFilterThreshold) + ' AND '
				End
				
				Set @Sql = @Sql +		 ' DeltaCn2' + @DeltaCn2Comparison + Convert(varchar(11), @DeltaCn2Threshold) + ' AND '
				Set @Sql = @sql +        ' Discriminant_Score ' + @DiscriminantScoreComparison + Convert(varchar(11), @DiscriminantScoreThreshold) + ' AND '
				Set @Sql = @sql +        ' NET_Difference_Absolute ' + @NETDifferenceAbsoluteComparison + Convert(varchar(11), @NETDifferenceAbsoluteThreshold)


				-- Execute the Sql to update the Pass_FilterSet_Group column
				Exec (@Sql)
				--
				SELECT @myError = @@error, @myRowCount = @@RowCount
				

				-- Lookup the next set of filters
				--
				Set @CriteriaGroupStart = @CriteriaGroupMatch + 1
				Set @CriteriaGroupMatch = 0
				
				Exec @myError = GetThresholdsForFilterSet @FilterSetID, @CriteriaGroupStart, @CriteriaGroupMatch OUTPUT, @message OUTPUT, 
												@SpectrumCountComparison OUTPUT,@SpectrumCountThreshold OUTPUT,
												@ChargeStateComparison OUTPUT,@ChargeStateThreshold OUTPUT,
												@HighNormalizedScoreComparison OUTPUT,@HighNormalizedScoreThreshold OUTPUT,
												@CleavageStateComparison OUTPUT,@CleavageStateThreshold OUTPUT,
												@PeptideLengthComparison OUTPUT,@PeptideLengthThreshold OUTPUT,
												@MassComparison OUTPUT,@MassThreshold OUTPUT,
												@DeltaCnComparison OUTPUT,@DeltaCnThreshold OUTPUT,
												@DeltaCn2Comparison OUTPUT,@DeltaCn2Threshold OUTPUT,
												@DiscriminantScoreComparison OUTPUT, @DiscriminantScoreThreshold OUTPUT,
												@NETDifferenceAbsoluteComparison OUTPUT, @NETDifferenceAbsoluteThreshold OUTPUT,
												@DiscriminantInitialFilterComparison OUTPUT, @DiscriminantInitialFilterThreshold OUTPUT,
												@ProteinCountComparison OUTPUT, @ProteinCountThreshold OUTPUT,
												@TerminusStateComparison OUTPUT, @TerminusStateThreshold OUTPUT,
												@XTandemHyperscoreComparison OUTPUT, @XTandemHyperscoreThreshold OUTPUT,
												@XTandemLogEValueComparison OUTPUT, @XTandemLogEValueThreshold OUTPUT
				If @myError <> 0
				Begin
					Set @Message = 'Error retrieving next entry from GetThresholdsForFilterSet in CheckFilterForAvailableAnalyses'
					Goto Done
				End


			End -- </d>
		

			-----------------------------------------------------------
			-- Calculate stats and update T_Peptide_Filter_Flags
			-----------------------------------------------------------
			--

			UPDATE #JobsInBatch
			SET MatchCount = (	SELECT COUNT(*)
								FROM #PeptideStats
								WHERE #PeptideStats.Pass_FilterSet_Group = 1 AND
									  #PeptideStats.Analysis_ID = #JobsInBatch.Job
							  )
			FROM #JobsInBatch, #PeptideStats
			--
			SELECT @myError = @@error, @myRowCount = @@RowCount


			UPDATE #JobsInBatch
			SET UnmatchedCount = (	SELECT COUNT(*)
									FROM #PeptideStats
									WHERE #PeptideStats.Pass_FilterSet_Group = 0 AND
										  #PeptideStats.Analysis_ID = #JobsInBatch.Job
								  )
			FROM #JobsInBatch, #PeptideStats
			--
			SELECT @myError = @@error, @myRowCount = @@RowCount



			If @infoOnly = 0
			Begin -- <e>
				DELETE T_Peptide_Filter_Flags
				FROM T_Peptide_Filter_Flags INNER JOIN #PeptideStats ON 
					 T_Peptide_Filter_Flags.Peptide_ID = #PeptideStats.Peptide_ID
				WHERE #PeptideStats.Pass_FilterSet_Group = 0 AND 
					T_Peptide_Filter_Flags.Filter_ID = @FilterSetID
				--
				SELECT @myError = @@error, @myRowCount = @@RowCount
				--
				If @myError <> 0
				Begin
					Set @Message = 'Error deleting extra peptides from T_Peptide_Filter_Flags'
					Set @myError = 51108
					Goto Done
				End

				INSERT INTO T_Peptide_Filter_Flags (Filter_ID, Peptide_ID)
				SELECT @FilterSetID AS Filter_ID, Peptide_ID
				FROM #PeptideStats
				WHERE #PeptideStats.Pass_FilterSet_Group = 1 AND Peptide_ID NOT IN
						(	SELECT Peptide_ID
							FROM T_Peptide_Filter_Flags
							WHERE Filter_ID = @FilterSetID
						)
				--
				SELECT @myError = @@error, @myRowCount = @@RowCount
				--
				If @myError <> 0
				Begin
					Set @Message = 'Error adding new peptides to T_Peptide_Filter_Flags'
					Set @myError = 51109
					Goto Done
				End

				-----------------------------------------------------------
				-- Update state of analysis job filter flag
				-----------------------------------------------------------
				--
				INSERT INTO T_Analysis_Filter_Flags (Filter_ID, Job) 
				SELECT @filterSetID, Job
				FROM #JobsInBatch
				--
				SELECT @myError = @@error, @myRowCount = @@RowCount

				-- Update the Last_Affected value (but not Process_State since 
				--  CheckAllFiltersForAvailableAnalyses will update it once all
				--  possible filters have been checked)
				UPDATE T_Analysis_Description 
				SET Last_Affected = GETDATE()
				FROM T_Analysis_Description INNER JOIN #JobsInBatch ON
					 T_Analysis_Description.Job = #JobsInBatch.Job
				--
				SELECT @myError = @@error, @myRowCount = @@RowCount
				
			End -- </e>

			
			-- Post entries to T_Log_Entries for all jobs processed in this batch
			--			
			Set @intContinue = 1
			Set @LastJobPolled = 0
			
			While @intContinue = 1
			Begin -- <f>
				SELECT	TOP 1
						@LastJobPolled = Job,
						@peptideMatchCount = IsNull(MatchCount, 0), 
						@peptideUnmatchedCount = IsNull(UnmatchedCount, 0)
				FROM #JobsInBatch
				WHERE Job > @LastJobPolled
				--
				SELECT @myError = @@error, @intContinue = @@RowCount
				
				If @intContinue = 1
				Begin
					set @message = convert(varchar(11), @peptideMatchCount) + ' peptides were matched for filter set ' + @filterSetStr + ' for job ' + convert(varchar(11), @LastJobPolled)
					Set @message = @message + '; ' + convert(varchar(11), @peptideUnmatchedCount) + ' peptides did not pass filter'

					-- bump running count of peptides that matched the filter
					--
					set @TotalHitCount = @TotalHitCount + @peptideMatchCount
					
					-- make log entry
					--
					execute PostLogEntry 'Normal', @message, 'CheckFilterForAvailableAnalyses'
				End
			End -- </f>

			-- Increment jobs processed count
			Set @numJobsProcessed = @numJobsProcessed + @JobsInBatch
			
		 End -- </b>
	End -- </a>


	-----------------------------------------------
	-- exit the stored procedure
	-----------------------------------------------
	-- 
Done:

	-- Post a log entry if an error exists
	if @myError <> 0
		execute PostLogEntry 'Error', @message, 'CheckFilterForAvailableAnalyses'

	Return @myError


GO
