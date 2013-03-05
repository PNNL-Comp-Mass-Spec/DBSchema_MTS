/****** Object:  StoredProcedure [dbo].[ComputeMassTagsAnalysisCounts] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE Procedure ComputeMassTagsAnalysisCounts
/****************************************************
**
**	Desc: 
**		Recomputes the values for Number_Of_Peptides,
**		 High_Normalized_Score, and High_Discriminant_Score in T_Mass_Tags
**		Only counts peptides from the same dataset once,
**		 even if the dataset has several analysis jobs
**		Does count a peptide multiple times if it was seen
**		 in different scans in the same analysis for the same dataset
**
**	Return values: 0 if no error; otherwise error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	09/19/2004
**			05/20/2005 mem - Now verifying the value of Internal_Standard_Only
**			09/28/2005 mem - Now updating column Peptide_Obs_Count_Passing_Filter
**			12/11/2005 mem - Updated to support XTandem results
**			07/10/2006 mem - Updated to support Peptide Prophet values
**			09/06/2006 mem - Now posting a log entry on success
**			02/07/2007 mem - Switched to using sp_executesql
**			09/07/2007 mem - Now posting log entries if the stored procedure runs for more than 2 minutes
**			11/13/2007 mem - Now updating PMTs_Last_Affected in T_Analysis_Description
**			02/26/2008 mem - Added call to VerifyUpdateEnabled
**			04/30/2008 mem - Added parameter @previewSql
**			11/05/2008 mem - Added support for Inspect results (type IN_Peptide_Hit)
**			02/11/2009 mem - Updated to assume a value of 0.5 for Null peptide prophet probability values from XTandem jobs
**			07/21/2009 mem - Added support for Inspect_PValue filtering
**			12/14/2010 mem - Now updating Min_MSGF_SpecProb in T_Mass_Tags
**						   - Added support for MSGF_SpecProb filtering
**			02/18/2011 mem - Changed message reporting Null peptide prophet values for XTandem jobs to be an Error message instead of a Warning message
**			10/03/2011 mem - Added support for MSGFDB results (type MSG_Peptide_Hit)
**			01/06/2012 mem - Updated to use T_Peptides.Job
**			12/05/2012 mem - Added support for MSAlign (type MSA_Peptide_Hit)
**    
*****************************************************/
(
	@message varchar(512)='' OUTPUT,
	@UpdateFilteredObsStatsOnly tinyint = 0,
	@previewSql tinyint = 0
)
AS

	set nocount on

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Declare @Continue tinyint
	Declare @TestThresholds tinyint

	Declare @S nvarchar(max)

	declare @ResultTypeID int
	declare @ResultType varchar(32)
	Set @ResultType = 'Unknown'

	declare @lastProgressUpdate datetime
	Set @lastProgressUpdate = GetDate()

	declare @ProgressUpdateIntervalThresholdSeconds int
	Set @ProgressUpdateIntervalThresholdSeconds = 120
	
	declare @TableRowCount int
	declare @MTRowsUpdated int
	Set @MTRowsUpdated = 0
	
	declare @UpdateEnabled tinyint

	----------------------------------------------------------
	-- Validate the inputs
	----------------------------------------------------------
	Set @message= ''
	Set @UpdateFilteredObsStatsOnly = IsNull(@UpdateFilteredObsStatsOnly, 0)
	Set @previewSql = IsNull(@previewSql, 0)
	
	
	----------------------------------------------------------
	-- Check the size of T_Peptides; if it contains over 2 million rows,
	--  then post a log entry saying this procedure is starting
	----------------------------------------------------------
	
	Set @TableRowCount = 0
	SELECT @TableRowCount = TableRowCount
	FROM V_Table_Row_Counts
	WHERE (TableName = 'T_Peptides')
	
	If @TableRowCount > 2000000 And @previewSql = 0
	Begin
		Set @message = 'Updating mass tag analysis counts using T_Peptides (' + Convert(varchar(19), @TableRowCount) + ' rows)'
		execute PostLogEntry 'Progress', @message, 'ComputeMassTagsAnalysisCounts'
		set @message = ''
		Set @lastProgressUpdate = GetDate()
	End

	-----------------------------------------------
	-- Update PMTs_Last_Affected in T_Analysis_Description
	-----------------------------------------------
	--
	Set @S = ''
	Set @S = @S + ' UPDATE T_Analysis_Description'
	Set @S = @S + ' SET PMTs_Last_Affected = LookupQ.Last_Affected'
	Set @S = @S + ' FROM T_Analysis_Description TAD INNER JOIN'
	Set @S = @S +    ' (	SELECT TAD.Job, MAX(MT.Last_Affected) AS Last_Affected'
	Set @S = @S +       ' FROM T_Mass_Tags MT'
	Set @S = @S +       ' INNER JOIN T_Peptides P ON MT.Mass_Tag_ID = P.Mass_Tag_ID'
	Set @S = @S +    ' INNER JOIN T_Analysis_Description TAD ON P.Job = TAD.Job'
	Set @S = @S +    ' GROUP BY TAD.Job'
	Set @S = @S +    ' ) LookupQ ON TAD.Job = LookupQ.Job'
	Set @S = @S + ' WHERE IsNull(PMTs_Last_Affected, 0) <> LookupQ.Last_Affected'
	
	If @PreviewSql <> 0
		Print @S
	Else
		Exec (@S)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error


	-----------------------------------------------
	-- Populate a temporary table with the list of known Result Types
	-----------------------------------------------
	CREATE TABLE #T_ResultTypeList (
		UniqueID int IDENTITY(1,1),
		ResultType varchar(64)
	)
	
	INSERT INTO #T_ResultTypeList (ResultType)
	SELECT ResultType
	FROM dbo.tblPeptideHitResultTypes()


	If @UpdateFilteredObsStatsOnly = 0
	Begin
		
		-----------------------------------------------------------
		-- Update the general stats by examining T_Peptides and associated tables
		-- Note that the source data for this query is a UNION between the 
		-- Peptide_Hit (Sequest) data, the XT_Peptide_Hit (XTandem) data, the IN_Peptide_Hit (Inspect) data, the MSG_Peptide_Hit (MSGFDB) data, and the MSA_Peptide_Hit (MSAlign) data
		--
		-- Only Sequest and Inspect data will have values in the Peptide_Prophet_Probability table of T_Score_Discriminant
		--	For Inspect, Peptide_Prophet_Probability = 1 - Inspect_PValue (populated during load into the PT database)
		-- For XTandem, we are assuming a value of 0.5 for the peptide prophet probability
		-----------------------------------------------------------
		--
		Set @S = ''
		Set @S = @S + ' UPDATE T_Mass_Tags'
		Set @S = @S + ' SET Number_Of_Peptides = IsNull(StatsQ.ObservationCount, 0),'
		Set @S = @S +    ' High_Normalized_Score = IsNull(StatsQ.Normalized_Score_Max, 0),'
		Set @S = @S +    ' High_Discriminant_Score = IsNull(StatsQ.Discriminant_Score_Max, 0),'
		Set @S = @S +    ' High_Peptide_Prophet_Probability = IsNull(StatsQ.Peptide_Prophet_Probability_Max, 0),'
		Set @S = @S +    ' Min_Log_EValue = IsNull(StatsQ.Log_Evalue_Min, 0),'
		Set @S = @S +    ' Min_MSGF_SpecProb = IsNull(StatsQ.MSGF_SpecProb_Min, 1)'
		Set @S = @S + ' FROM T_Mass_Tags LEFT OUTER JOIN'
		Set @S = @S +    ' ('
		Set @S = @S +       ' SELECT Mass_Tag_ID, '
		Set @S = @S +             ' COUNT(*) AS ObservationCount, '
		Set @S = @S +             ' MAX(Normalized_Score_Max) AS Normalized_Score_Max,'
		Set @S = @S +             ' MAX(Discriminant_Score_Max) AS Discriminant_Score_Max,'
		Set @S = @S +             ' MAX(Peptide_Prophet_Probability_Max) AS Peptide_Prophet_Probability_Max,'
		Set @S = @S +             ' MIN(Log_Evalue_Min) AS Log_Evalue_Min,'
		Set @S = @S +             ' MIN(MSGF_SpecProb_Min) AS MSGF_SpecProb_Min'
		Set @S = @S +       ' FROM (	SELECT Dataset_ID, Mass_Tag_ID, Scan_Number,'
		Set @S = @S +                '    MAX(Normalized_Score) AS Normalized_Score_Max, '
		Set @S = @S +                '    MAX(Discriminant_Score) AS Discriminant_Score_Max,'
		Set @S = @S +                '    MAX(Peptide_Prophet_Probability) AS Peptide_Prophet_Probability_Max,'
		Set @S = @S +                '    MIN(Log_Evalue) AS Log_Evalue_Min,'
		Set @S = @S +                '    MIN(MSGF_SpecProb) AS MSGF_SpecProb_Min'
		Set @S = @S +             ' FROM (	SELECT TAD.Dataset_ID, P.Mass_Tag_ID, P.Scan_Number, '
		Set @S = @S +                         ' ISNULL(SS.XCorr, 0) AS Normalized_Score,'
		Set @S = @S +                         ' ISNULL(SD.DiscriminantScoreNorm, 0) AS Discriminant_Score,'
		Set @S = @S +                      ' ISNULL(SD.Peptide_Prophet_Probability, 0) AS Peptide_Prophet_Probability,'
		Set @S = @S +                         ' 0 AS Log_Evalue,'
		Set @S = @S +                         ' ISNULL(SD.MSGF_SpecProb, 1) AS MSGF_SpecProb'
		Set @S = @S +                   ' FROM T_Peptides AS P INNER JOIN '
		Set @S = @S +                       '  T_Analysis_Description AS TAD ON P.Job = TAD.Job LEFT OUTER JOIN '
		Set @S = @S +                       '  T_Score_Sequest AS SS ON P.Peptide_ID = SS.Peptide_ID LEFT OUTER JOIN '
		Set @S = @S +                       '  T_Score_Discriminant AS SD ON P.Peptide_ID = SD.Peptide_ID'
		Set @S = @S +                   ' WHERE TAD.ResultType = ''Peptide_Hit'''
		Set @S = @S +                   ' UNION'
		Set @S = @S +                   ' SELECT TAD.Dataset_ID, P.Mass_Tag_ID, P.Scan_Number, '
		Set @S = @S +                         ' ISNULL(X.Normalized_Score, 0) AS Normalized_Score,'
		Set @S = @S +                         ' ISNULL(SD.DiscriminantScoreNorm, 0) AS Discriminant_Score,'
		----------------------------------------------------------------------------------------------------
		-- Note: Using 0.5 for Peptide Prophet Probability when the value is Null for XTandem results
		----------------------------------------------------------------------------------------------------
		Set @S = @S +                         ' ISNULL(SD.Peptide_Prophet_Probability, 0.5) AS Peptide_Prophet_Probability,'
		Set @S = @S +                         ' ISNULL(X.Log_Evalue, 0) AS Log_Evalue,'
		Set @S = @S +                         ' ISNULL(SD.MSGF_SpecProb, 1) AS MSGF_SpecProb'
		Set @S = @S +                   ' FROM T_Peptides AS P INNER JOIN '
		Set @S = @S +                       '  T_Analysis_Description AS TAD ON P.Job = TAD.Job LEFT OUTER JOIN '
		Set @S = @S +                       '  T_Score_XTandem AS X ON P.Peptide_ID = X.Peptide_ID LEFT OUTER JOIN '
		Set @S = @S +                       '  T_Score_Discriminant AS SD ON P.Peptide_ID = SD.Peptide_ID'
		Set @S = @S +                   ' WHERE TAD.ResultType = ''XT_Peptide_Hit'''
		Set @S = @S +                   ' UNION'
		Set @S = @S +                   ' SELECT TAD.Dataset_ID, P.Mass_Tag_ID, P.Scan_Number, '
		Set @S = @S +                         ' ISNULL(I.Normalized_Score, 0) AS Normalized_Score,'
		Set @S = @S +                         ' ISNULL(SD.DiscriminantScoreNorm, 0) AS Discriminant_Score,'
		Set @S = @S +                         ' ISNULL(SD.Peptide_Prophet_Probability, 0) AS Peptide_Prophet_Probability,'
		Set @S = @S +                         ' 0 AS Log_Evalue,'
		Set @S = @S +                         ' ISNULL(SD.MSGF_SpecProb, 1) AS MSGF_SpecProb'
		Set @S = @S +                   ' FROM T_Peptides AS P INNER JOIN '
		Set @S = @S +                       '  T_Analysis_Description AS TAD ON P.Job = TAD.Job LEFT OUTER JOIN '
		Set @S = @S +                       '  T_Score_Inspect AS I ON P.Peptide_ID = I.Peptide_ID LEFT OUTER JOIN '
		Set @S = @S +                       '  T_Score_Discriminant AS SD ON P.Peptide_ID = SD.Peptide_ID'
		Set @S = @S +                   ' WHERE TAD.ResultType = ''IN_Peptide_Hit'''
		Set @S = @S +                   ' UNION'
		Set @S = @S +                   ' SELECT TAD.Dataset_ID, P.Mass_Tag_ID, P.Scan_Number, '
		Set @S = @S +                         ' ISNULL(M.Normalized_Score, 0) AS Normalized_Score,'
		Set @S = @S +                         ' ISNULL(SD.DiscriminantScoreNorm, 0) AS Discriminant_Score,'
		Set @S = @S +                         ' ISNULL(SD.Peptide_Prophet_Probability, 0) AS Peptide_Prophet_Probability,'
		Set @S = @S +                         ' 0 AS Log_Evalue,'
		Set @S = @S +                         ' ISNULL(SD.MSGF_SpecProb, 1) AS MSGF_SpecProb'
		Set @S = @S +                   ' FROM T_Peptides AS P INNER JOIN '
		Set @S = @S +                        ' T_Analysis_Description AS TAD ON P.Job = TAD.Job LEFT OUTER JOIN '
		Set @S = @S +                        ' T_Score_MSGFDB AS M ON P.Peptide_ID = M.Peptide_ID LEFT OUTER JOIN '
		Set @S = @S +                        ' T_Score_Discriminant AS SD ON P.Peptide_ID = SD.Peptide_ID'
		Set @S = @S +                   ' WHERE TAD.ResultType = ''MSG_Peptide_Hit'''
		Set @S = @S +                   ' UNION'
		Set @S = @S +                   ' SELECT TAD.Dataset_ID, P.Mass_Tag_ID, P.Scan_Number, '
		Set @S = @S +                         ' ISNULL(M.Normalized_Score, 0) AS Normalized_Score,'
		Set @S = @S +                         ' ISNULL(SD.DiscriminantScoreNorm, 0) AS Discriminant_Score,'
		Set @S = @S +                         ' ISNULL(SD.Peptide_Prophet_Probability, 0) AS Peptide_Prophet_Probability,'
		Set @S = @S +                         ' 0 AS Log_Evalue,'
		Set @S = @S +                         ' ISNULL(SD.MSGF_SpecProb, 1) AS MSGF_SpecProb'
		Set @S = @S +                   ' FROM T_Peptides AS P INNER JOIN '
		Set @S = @S +                        ' T_Analysis_Description AS TAD ON P.Job = TAD.Job LEFT OUTER JOIN '
		Set @S = @S +                        ' T_Score_MSAlign AS M ON P.Peptide_ID = M.Peptide_ID LEFT OUTER JOIN '
		Set @S = @S +                        ' T_Score_Discriminant AS SD ON P.Peptide_ID = SD.Peptide_ID'
		Set @S = @S +                   ' WHERE TAD.ResultType = ''MSA_Peptide_Hit'''
		Set @S = @S +                '  ) AS SourceQ'
		Set @S = @S +             ' GROUP BY Dataset_ID, Mass_Tag_ID, Scan_Number'
		Set @S = @S +          ' ) AS DatasetQ'
		Set @S = @S +       ' GROUP BY DatasetQ.Mass_Tag_ID'
		Set @S = @S +    ' ) AS StatsQ ON T_Mass_Tags.Mass_Tag_ID = StatsQ.Mass_Tag_ID'
		
		If @PreviewSql <> 0
			Print @S
		Else
			Exec (@S)
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		If @myError <> 0
		Begin
			Set @message = 'Error updating Number_Of_Peptides and High_Normalized_Score in T_Mass_Tags: ' + Convert(varchar(12), @myError)
			execute PostLogEntry 'Error', @message, 'ComputeMassTagsAnalysisCounts'
		End

		if DateDiff(second, @lastProgressUpdate, GetDate()) >= @ProgressUpdateIntervalThresholdSeconds And @PreviewSql = 0
		Begin
			set @message = '...Processing: Updated the general stats in T_Mass_Tags (' + convert(varchar(19), @myRowCount) + ' rows updated)'
			execute PostLogEntry 'Progress', @message, 'ComputeMassTagsAnalysisCounts'
			set @message = ''
			set @lastProgressUpdate = GetDate()
		End

		If Exists(	SELECT *
					FROM T_Peptides P INNER JOIN
						 T_Analysis_Description TAD ON P.Job = TAD.Job INNER JOIN
						 T_Score_Discriminant SD ON P.Peptide_ID = SD.Peptide_ID
					WHERE TAD.ResultType = 'XT_Peptide_Hit' AND 
						  SD.Peptide_Prophet_Probability IS NULL
				 )
		Begin
			Set @message = 'XTandem search results do not have Peptide Prophet values defined.  Use udfLogEValueToPeptideProphetEstimate() to update Peptide_Prophet_Probability in T_Score_Discriminant; for now, will use 0.5 for null values.  Note that we do not run Peptide Prophet on XTandem analysis job results'
			execute PostLogEntry 'Error', @message, 'ComputeMassTagsAnalysisCounts'
			set @message = ''
		End


		-----------------------------------------------------------
		--  Verify that Internal_Standard_Only = 0 for all peptides with an entry in T_Peptides
		-----------------------------------------------------------
		--
		Set @S = ''
		Set @S = @S + ' UPDATE T_Mass_Tags'
		Set @S = @S + ' SET Internal_Standard_Only = 0'
		Set @S = @S + ' FROM T_Mass_Tags INNER JOIN T_Peptides ON '
		Set @S = @S +    ' T_Mass_Tags.Mass_Tag_ID = T_Peptides.Mass_Tag_ID'
		Set @S = @S + ' WHERE Internal_Standard_Only = 1'
		
		If @PreviewSql <> 0
			Print @S
		Else
			Exec (@S)
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		-- Validate that updating is enabled, abort if not enabled
		exec VerifyUpdateEnabled @CallingFunctionDescription = 'ComputeMassTagsAnalysisCounts', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
		If @UpdateEnabled = 0
			Goto Done
	End


	-----------------------------------------------------------
	-- Update the stats for column Peptide_Obs_Count_Passing_Filter
	-----------------------------------------------------------
	--

	Declare @ConfigValue varchar(128)
	Declare @FilterSetID int
	Declare @MTObsStatsRowCount int
	Set @MTObsStatsRowCount = 0
	
	-- Create a temporary table to track which PMTs pass the filter critera
	-- and the datasets and scan numbers the peptide was observed in

	if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#TmpMTObsStats]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [dbo].[#TmpMTObsStats]

	CREATE TABLE #TmpMTObsStats (
		[Mass_Tag_ID] int NOT NULL,
		[Dataset_ID] int NOT NULL,
		[Scan_Number] int NOT NULL
	) ON [PRIMARY]

	CREATE CLUSTERED INDEX [#IX_TmpMTObsStats] ON [dbo].[#TmpMTObsStats]([Mass_Tag_ID]) ON [PRIMARY]

	-- Define the default Filter_Set_ID
	Set @FilterSetID = 141

	-- Lookup the Peptide_Obs_Count Filter_Set_ID value
	SELECT TOP 1 @ConfigValue = Value
	FROM T_Process_Config
	WHERE [Name] = 'Peptide_Obs_Count_Filter_ID'
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error

	If @myRowCount = 0
	 Begin
		-- Use the default FilterSetID value; post a warning to the log
		set @message = 'Warning: Entry Peptide_Obs_Count_Filter_ID not found in T_Process_Config; using default value of ' + Convert(varchar(9), @FilterSetID)
		execute PostLogEntry 'Error', @message, 'ComputeMassTagsAnalysisCounts'
	 End
	Else
	 Begin
		If IsNumeric(IsNull(@ConfigValue, '')) = 1
			Set @FilterSetID = Convert(int, @ConfigValue)
		Else
		Begin
			-- Use the default FilterSetID value; post a warning to the log
			set @message = 'An invalid entry for Peptide_Obs_Count_Filter_ID was found in T_Process_Config: ' + IsNull(@ConfigValue, 'NULL') + '; using default value of ' + Convert(varchar(9), @FilterSetID)
			execute PostLogEntry 'Error', @message, 'ComputeMassTagsAnalysisCounts'
		End
	 End

	-- Define the filter threshold values
	Declare @CriteriaGroupStart int,
			@CriteriaGroupMatch int,
			@SpectrumCountComparison varchar(2),			-- Not used in this SP
			@SpectrumCountThreshold int,
			@ChargeStateComparison varchar(2),
			@ChargeStateThreshold tinyint,
			@HighNormalizedScoreComparison varchar(2),		-- Only used for Sequest results
			@HighNormalizedScoreThreshold float,
			@CleavageStateComparison varchar(2),
			@CleavageStateThreshold tinyint,
			@PeptideLengthComparison varchar(2),
			@PeptideLengthThreshold smallint,
			@MassComparison varchar(2),
			@MassThreshold float,
			@DeltaCnComparison varchar(2),					-- Only used for Sequest results
			@DeltaCnThreshold float,
			@DeltaCn2Comparison varchar(2),					-- Used for Sequest, X!Tandem, and Inspect results (T_Score_Sequest.DeltaCn2, T_Score_XTandem.DeltaCn2, and T_Score_Inspect.DeltaNormTotalPRMScore)
			@DeltaCn2Threshold float,
			@DiscriminantScoreComparison varchar(2),		-- Used for all three tools, though Discriminant is only truly accurate for Sequest
			@DiscriminantScoreThreshold float,
			@NETDifferenceAbsoluteComparison varchar(2),
			@NETDifferenceAbsoluteThreshold float,
			@DiscriminantInitialFilterComparison varchar(2),	-- Not used in this SP
			@DiscriminantInitialFilterThreshold float,
			@ProteinCountComparison varchar(2),
			@ProteinCountThreshold int,
			@TerminusStateComparison varchar(2),
			@TerminusStateThreshold tinyint,
			@XTandemHyperscoreComparison varchar(2),		-- Only used for X!Tandem results
			@XTandemHyperscoreThreshold real,
			@XTandemLogEValueComparison varchar(2),			-- Only used for X!Tandem results
			@XTandemLogEValueThreshold real,
			@PeptideProphetComparison varchar(2),			-- Note, for Inspect data, T_Score_Discriminant.Peptide_Prophet_Probability actually contains "1 minus T_Score_Inspect.PValue"
			@PeptideProphetThreshold float,					
			@RankScoreComparison varchar(2),				-- Not used in this SP
			@RankScoreThreshold smallint,
			@InspectMQScoreComparison varchar(2),			-- Only used for Inspect results
			@InspectMQScoreThreshold real,
			@InspectTotalPRMScoreComparison varchar(2),		-- Only used for Inspect results
			@InspectTotalPRMScoreThreshold real,
			@InspectFScoreComparison varchar(2),			-- Only used for Inspect results
			@InspectFScoreThreshold real,
			@InspectPValueComparison varchar(2),			-- Only used for Inspect results
			@InspectPValueThreshold real,
			@MSGFSpecProbComparison varchar(2),				-- Used for Sequest, X!Tandem, or Inspect results
			@MSGFSpecProbThreshold real,
			
			@MSGFDbSpecProbComparison varchar(2),			-- Only used for MSGFDB results
			@MSGFDbSpecProbThreshold real,
			@MSGFDbPValueComparison varchar(2),				-- Only used for MSGFDB results
			@MSGFDbPValueThreshold real,
			@MSGFDbFDRComparison varchar(2),				-- Only used for MSGFDB results
			@MSGFDbFDRThreshold real,
							
			@MSAlignPValueComparison varchar(2),		-- Used by MSAlign
			@MSAlignPValueThreshold real,			
			@MSAlignFDRComparison varchar(2),			-- Used by MSAlign
			@MSAlignFDRThreshold real



	-----------------------------------------------------------
	-- Validate that @FilterSetID is defined in V_Filter_Sets_Import
	-- Do this by calling GetThresholdsForFilterSet and examining @FilterGroupMatch
	-----------------------------------------------------------
	--
	Set @CriteriaGroupStart = 0
	Set @CriteriaGroupMatch = 0
	Exec @myError = GetThresholdsForFilterSet @FilterSetID, @CriteriaGroupStart, @CriteriaGroupMatch OUTPUT, @message OUTPUT
	
	If @myError <> 0
	Begin
		If Len(@message) = 0
			set @message = 'Could not validate filter set ID ' + Convert(varchar(11), @FilterSetID) + ' using GetThresholdsForFilterSet'		
		goto Done
	End
	
	If @CriteriaGroupMatch = 0 
	Begin

		-- Invalid filter defined; post message to log
		set @message = 'Filter set ID ' + Convert(varchar(11), @FilterSetID) + ' not found using GetThresholdsForFilterSet'
		SELECT @message
		execute PostLogEntry 'Error', @message, 'ComputeMassTagsAnalysisCounts'
		Set @message = ''
	End
	Else
	Begin -- <a>

		If @PreviewSql <> 0
			Print ' '

		-----------------------------------------------------------
		-- Now call GetThresholdsForFilterSet to get the thresholds to filter against
		-- Set Passes_Filter to 1 in #TmpMTObsStats for the matching mass tags
		-----------------------------------------------------------

		Set @CriteriaGroupStart = 0
		Set @TestThresholds = 1
		
		While @TestThresholds = 1
		Begin -- <b>
		
			Set @CriteriaGroupMatch = 0
			Exec @myError = GetThresholdsForFilterSet 
								@FilterSetID, @CriteriaGroupStart, @CriteriaGroupMatch OUTPUT, @message OUTPUT, 
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
								@XTandemLogEValueComparison OUTPUT, @XTandemLogEValueThreshold OUTPUT,
								@PeptideProphetComparison OUTPUT, @PeptideProphetThreshold OUTPUT,
								@RankScoreComparison OUTPUT, @RankScoreThreshold OUTPUT,
								@InspectMQScoreComparison = @InspectMQScoreComparison OUTPUT, @InspectMQScoreThreshold = @InspectMQScoreThreshold OUTPUT,
								@InspectTotalPRMScoreComparison = @InspectTotalPRMScoreComparison OUTPUT, @InspectTotalPRMScoreThreshold = @InspectTotalPRMScoreThreshold OUTPUT,
								@InspectFScoreComparison = @InspectFScoreComparison OUTPUT, @InspectFScoreThreshold = @InspectFScoreThreshold OUTPUT,
								@InspectPValueComparison = @InspectPValueComparison OUTPUT, @InspectPValueThreshold = @InspectPValueThreshold OUTPUT,
								@MSGFSpecProbComparison = @MSGFSpecProbComparison OUTPUT, @MSGFSpecProbThreshold = @MSGFSpecProbThreshold OUTPUT,
								@MSGFDbSpecProbComparison = @MSGFDbSpecProbComparison OUTPUT, @MSGFDbSpecProbThreshold = @MSGFDbSpecProbThreshold OUTPUT,
								@MSGFDbPValueComparison = @MSGFDbPValueComparison OUTPUT, @MSGFDbPValueThreshold = @MSGFDbPValueThreshold OUTPUT,
								@MSGFDbFDRComparison = @MSGFDbFDRComparison OUTPUT, @MSGFDbFDRThreshold = @MSGFDbFDRThreshold OUTPUT,
								@MSAlignPValueComparison = @MSAlignPValueComparison OUTPUT, @MSAlignPValueThreshold = @MSAlignPValueThreshold OUTPUT,
								@MSAlignFDRComparison = @MSAlignFDRComparison OUTPUT, @MSAlignFDRThreshold = @MSAlignFDRThreshold OUTPUT

			If @myError <> 0
			Begin
				Set @Message = 'Error retrieving next entry from GetThresholdsForFilterSet in CheckFilterForAnalysesWork'
				Goto Done
			End


			If @CriteriaGroupMatch <= 0
				Set @TestThresholds = 0
			Else
			Begin -- <c>

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
				
				-- Evaluate the filters in groups by ResultType
				--
				While Len(IsNull(@ResultType, '')) > 0 And @myError = 0
				Begin -- <d>

					-- Populate #TmpMTObsStats with the PMT tags passing the current criteria
					-- Initially set @myError to a non-zero value in case @ResultType is invalid for this SP
					-- Note that this error code is used below so be sure took update the value in both places if you change it
					--
					Set @myError = 51200
					If @ResultType = 'Peptide_Hit'
					Begin -- <e1>
						Set @S = ''
						Set @S = @S + ' INSERT INTO #TmpMTObsStats (Mass_Tag_ID, Dataset_ID, Scan_Number)'
						Set @S = @S + ' SELECT MT.Mass_Tag_ID, Dataset_ID, Scan_Number'
						Set @S = @S + ' FROM ('
						Set @S = @S +   ' SELECT Dataset_ID, Mass_Tag_ID, Scan_Number, GANET_Obs, Charge_State,'
						Set @S = @S +     ' MAX(SubQ.XCorr_Max) AS XCorr_Max,'
						Set @S = @S +     ' MAX(SubQ.Discriminant_Score_Max) AS Discriminant_Score_Max,'
						Set @S = @S +     ' MAX(SubQ.Peptide_Prophet_Max) AS Peptide_Prophet_Max,'
						Set @S = @S +     ' MIN(SubQ.MSGF_SpecProb_Min) AS MSGF_SpecProb_Min'
						Set @S = @S +   ' FROM ('
						Set @S = @S +      ' SELECT TAD.Dataset_ID, P.Mass_Tag_ID, P.Scan_Number, P.GANET_Obs,'
						Set @S = @S +             ' P.Charge_State,'
						Set @S = @S +             ' MAX(IsNull(SS.XCorr, 0)) AS XCorr_Max,'
						Set @S = @S +             ' MAX(IsNull(SD.DiscriminantScoreNorm, 0)) As Discriminant_Score_Max,'
						Set @S = @S +             ' MAX(IsNull(SD.Peptide_Prophet_Probability, 0)) As Peptide_Prophet_Max,'
						Set @S = @S +             ' MIN(IsNull(SD.MSGF_SpecProb, 1)) As MSGF_SpecProb_Min'
						Set @S = @S + ' FROM T_Peptides AS P INNER JOIN T_Analysis_Description AS TAD ON P.Job = TAD.Job'
						Set @S = @S +           ' LEFT OUTER JOIN T_Score_Sequest AS SS ON P.Peptide_ID = SS.Peptide_ID'
						Set @S = @S +           ' LEFT OUTER JOIN T_Score_Discriminant AS SD ON P.Peptide_ID = SD.Peptide_ID'
						Set @S = @S +      ' WHERE TAD.ResultType = ''Peptide_Hit'' AND NOT P.Charge_State IS NULL AND'
						Set @S = @S +            ' SS.DeltaCn ' + @DeltaCnComparison + Convert(varchar(11), @DeltaCnThreshold) + ' AND '
						Set @S = @S +            ' SS.DeltaCn2 ' + @DeltaCn2Comparison + Convert(varchar(11), @DeltaCn2Threshold)
						Set @S = @S +      ' GROUP BY TAD.Dataset_ID, P.Mass_Tag_ID, P.Scan_Number, P.GANET_Obs, P.Charge_State'
						Set @S = @S +      ') AS SubQ'
						Set @S = @S +   ' GROUP BY Dataset_ID, Mass_Tag_ID, Scan_Number, GANET_Obs, Charge_State'
						Set @S = @S +   ') AS StatsQ'
  						Set @S = @S +   ' INNER JOIN T_Mass_Tags AS MT ON StatsQ.Mass_Tag_ID = MT.Mass_Tag_ID'
						Set @S = @S + ' LEFT OUTER JOIN T_Mass_Tag_to_Protein_Map AS MTPM ON MT.Mass_Tag_ID = MTPM.Mass_Tag_ID'
						Set @S = @S + ' LEFT OUTER JOIN T_Mass_Tags_NET AS MTN ON MT.Mass_Tag_ID = MTN.Mass_Tag_ID'
						Set @S = @S + ' WHERE '
						Set @S = @S +   ' StatsQ.Charge_State ' +  @ChargeStateComparison + Convert(varchar(11), @ChargeStateThreshold) + ' AND '
						Set @S = @S +   ' StatsQ.XCorr_Max ' +  @HighNormalizedScoreComparison + Convert(varchar(11), @HighNormalizedScoreThreshold) + ' AND '
						Set @S = @S +   ' ISNULL(MTPM.Cleavage_State, 0) ' + @CleavageStateComparison + Convert(varchar(11), @CleavageStateThreshold) + ' AND '
						Set @S = @S +   ' ISNULL(MTPM.Terminus_State, 0) ' + @TerminusStateComparison + Convert(varchar(11), @TerminusStateThreshold) + ' AND '
						Set @S = @S +   ' LEN(MT.Peptide) ' + @PeptideLengthComparison + Convert(varchar(11), @PeptideLengthThreshold) + ' AND '
						Set @S = @S +   ' IsNull(MT.Monoisotopic_Mass, 0) ' + @MassComparison + Convert(varchar(11), @MassThreshold) + ' AND '
						Set @S = @S +   ' StatsQ.Discriminant_Score_Max ' + @DiscriminantScoreComparison + Convert(varchar(11), @DiscriminantScoreThreshold) + ' AND '
						Set @S = @S +   ' StatsQ.Peptide_Prophet_Max ' + @PeptideProphetComparison + Convert(varchar(11), @PeptideProphetThreshold) + ' AND '
						Set @S = @S +   ' StatsQ.MSGF_SpecProb_Min ' +   @MSGFSpecProbComparison +   Convert(varchar(11), @MSGFSpecProbThreshold) + ' AND '
						Set @S = @S +   ' IsNull(ABS(StatsQ.GANET_Obs - MTN.PNET), 0) ' + @NETDifferenceAbsoluteComparison + Convert(varchar(11), @NETDifferenceAbsoluteThreshold) + ' AND '
						Set @S = @S +   ' IsNull(MT.Multiple_Proteins, 0) + 1 ' + @ProteinCountComparison + Convert(varchar(11), @ProteinCountThreshold)
						Set @S = @S + ' GROUP BY MT.Mass_Tag_ID, Dataset_ID, Scan_Number'

						If @PreviewSql <> 0
						Begin
							Print 'Sequest data, Filter Set ID: ' + Convert(varchar(12), @FilterSetID) + ', Criteria Group: ' + Convert(varchar(12), @CriteriaGroupStart)
							Print @S
						End
						Else
							Exec sp_executesql @S
						--
						SELECT @myRowCount = @@rowcount, @myError = @@error
						--
						Set @MTObsStatsRowCount = @MTObsStatsRowCount + @myRowCount
					End -- </e1>

					If @ResultType = 'XT_Peptide_Hit'
					Begin -- <e2>
						Set @S = ''
						Set @S = @S + ' INSERT INTO #TmpMTObsStats (Mass_Tag_ID, Dataset_ID, Scan_Number)'
						Set @S = @S + ' SELECT MT.Mass_Tag_ID, Dataset_ID, Scan_Number'
						Set @S = @S + ' FROM ('
						Set @S = @S +   ' SELECT Dataset_ID, Mass_Tag_ID, Scan_Number, GANET_Obs, Charge_State,'
						Set @S = @S +     ' MAX(SubQ.Hyperscore_Max) AS Hyperscore_Max,'
						Set @S = @S +     ' MIN(SubQ.Log_EValue_Min) AS Log_EValue_Min,'
						Set @S = @S +     ' MAX(SubQ.Discriminant_Score_Max) AS Discriminant_Score_Max,'
						Set @S = @S +     ' MAX(SubQ.Peptide_Prophet_Max) AS Peptide_Prophet_Max,'
						Set @S = @S +     ' MIN(SubQ.MSGF_SpecProb_Min) AS MSGF_SpecProb_Min'
						Set @S = @S +   ' FROM ('
						Set @S = @S +      ' SELECT TAD.Dataset_ID, P.Mass_Tag_ID, P.Scan_Number, P.GANET_Obs,'
						Set @S = @S +             ' P.Charge_State,'
						Set @S = @S +             ' MAX(IsNull(X.Hyperscore, 0)) AS Hyperscore_Max,'
						Set @S = @S +             ' MIN(IsNull(X.Log_EValue, 0)) AS Log_EValue_Min,'
						Set @S = @S +             ' MAX(IsNull(SD.DiscriminantScoreNorm, 0)) As Discriminant_Score_Max,'
						Set @S = @S +             ' MAX(IsNull(SD.Peptide_Prophet_Probability, 0)) As Peptide_Prophet_Max,'
						Set @S = @S +             ' MIN(IsNull(SD.MSGF_SpecProb, 1)) As MSGF_SpecProb_Min'
						Set @S = @S +      ' FROM T_Peptides AS P INNER JOIN T_Analysis_Description AS TAD ON P.Job = TAD.Job'
						Set @S = @S +           ' LEFT OUTER JOIN T_Score_XTandem AS X ON P.Peptide_ID = X.Peptide_ID'
						Set @S = @S +           ' LEFT OUTER JOIN T_Score_Discriminant AS SD ON P.Peptide_ID = SD.Peptide_ID'
						Set @S = @S +      ' WHERE TAD.ResultType = ''XT_Peptide_Hit'' AND NOT P.Charge_State IS NULL AND'
						Set @S = @S +            ' X.DeltaCn2 ' + @DeltaCn2Comparison + Convert(varchar(11), @DeltaCn2Threshold)
						Set @S = @S +      ' GROUP BY TAD.Dataset_ID, P.Mass_Tag_ID, P.Scan_Number, P.GANET_Obs, P.Charge_State'
						Set @S = @S +      ') AS SubQ'
						Set @S = @S +   ' GROUP BY Dataset_ID, Mass_Tag_ID, Scan_Number, GANET_Obs, Charge_State'
						Set @S = @S +   ') AS StatsQ'
  						Set @S = @S +   ' INNER JOIN T_Mass_Tags AS MT ON StatsQ.Mass_Tag_ID = MT.Mass_Tag_ID'
						Set @S = @S +   ' LEFT OUTER JOIN T_Mass_Tag_to_Protein_Map AS MTPM ON MT.Mass_Tag_ID = MTPM.Mass_Tag_ID'
						Set @S = @S +   ' LEFT OUTER JOIN T_Mass_Tags_NET AS MTN ON MT.Mass_Tag_ID = MTN.Mass_Tag_ID'
						Set @S = @S + ' WHERE '
						Set @S = @S +   ' StatsQ.Charge_State ' +  @ChargeStateComparison + Convert(varchar(11), @ChargeStateThreshold) + ' AND '
						Set @S = @S +   ' StatsQ.Hyperscore_Max ' +  @XTandemHyperscoreComparison + Convert(varchar(11), @XTandemHyperscoreThreshold) + ' AND '
						Set @S = @S +   ' StatsQ.Log_EValue_Min ' +  @XTandemLogEValueComparison + Convert(varchar(11), @XTandemLogEValueThreshold) + ' AND '
						Set @S = @S +   ' ISNULL(MTPM.Cleavage_State, 0) ' + @CleavageStateComparison + Convert(varchar(11), @CleavageStateThreshold) + ' AND '
						Set @S = @S +   ' ISNULL(MTPM.Terminus_State, 0) ' + @TerminusStateComparison + Convert(varchar(11), @TerminusStateThreshold) + ' AND '
						Set @S = @S +   ' LEN(MT.Peptide) ' + @PeptideLengthComparison + Convert(varchar(11), @PeptideLengthThreshold) + ' AND '
						Set @S = @S +   ' IsNull(MT.Monoisotopic_Mass, 0) ' + @MassComparison + Convert(varchar(11), @MassThreshold) + ' AND '
						Set @S = @S +   ' StatsQ.Discriminant_Score_Max ' + @DiscriminantScoreComparison + Convert(varchar(11), @DiscriminantScoreThreshold) + ' AND '
						Set @S = @S +   ' StatsQ.Peptide_Prophet_Max ' + @PeptideProphetComparison + Convert(varchar(11), @PeptideProphetThreshold) + ' AND '
						Set @S = @S +   ' StatsQ.MSGF_SpecProb_Min ' +   @MSGFSpecProbComparison +   Convert(varchar(11), @MSGFSpecProbThreshold) + ' AND '
						Set @S = @S +   ' IsNull(ABS(StatsQ.GANET_Obs - MTN.PNET), 0) ' + @NETDifferenceAbsoluteComparison + Convert(varchar(11), @NETDifferenceAbsoluteThreshold) + ' AND '
						Set @S = @S +   ' IsNull(MT.Multiple_Proteins, 0) + 1 ' + @ProteinCountComparison + Convert(varchar(11), @ProteinCountThreshold)
						Set @S = @S + ' GROUP BY MT.Mass_Tag_ID, Dataset_ID, Scan_Number'

						If @PreviewSql <> 0
						Begin
							Print 'X!Tandem data, Filter Set ID: ' + Convert(varchar(12), @FilterSetID) + ', Criteria Group: ' + Convert(varchar(12), @CriteriaGroupStart)
							Print @S
						End
						Else
							Exec sp_executesql @S
						--
						SELECT @myRowCount = @@rowcount, @myError = @@error
						--
						Set @MTObsStatsRowCount = @MTObsStatsRowCount + @myRowCount
					End -- </e2>

					If @ResultType = 'IN_Peptide_Hit'
					Begin -- <e3>
						Set @S = ''
						Set @S = @S + ' INSERT INTO #TmpMTObsStats (Mass_Tag_ID, Dataset_ID, Scan_Number)'
						Set @S = @S + ' SELECT MT.Mass_Tag_ID, Dataset_ID, Scan_Number'
						Set @S = @S + ' FROM ('
						Set @S = @S +   ' SELECT Dataset_ID, Mass_Tag_ID, Scan_Number, GANET_Obs, Charge_State,'
						Set @S = @S +     ' MAX(SubQ.MQScore_Max) AS MQScore_Max,'
						Set @S = @S +     ' MAX(SubQ.TotalPRMScore_Max) AS TotalPRMScore_Max,'
						Set @S = @S +     ' MAX(SubQ.FScore_Max) AS FScore_Max,'
						Set @S = @S +     ' MIN(SubQ.PValue_Min) AS PValue_Min,'
						Set @S = @S +     ' MAX(SubQ.Discriminant_Score_Max) AS Discriminant_Score_Max,'
						Set @S = @S +     ' MAX(SubQ.Peptide_Prophet_Max) AS Peptide_Prophet_Max,'
						Set @S = @S +     ' MIN(SubQ.MSGF_SpecProb_Min) AS MSGF_SpecProb_Min'
						Set @S = @S +   ' FROM ('
						Set @S = @S +      ' SELECT TAD.Dataset_ID, P.Mass_Tag_ID, P.Scan_Number, P.GANET_Obs,'
						Set @S = @S +             ' P.Charge_State,'
						Set @S = @S +             ' MAX(IsNull(I.MQScore, 0)) AS MQScore_Max,'
						Set @S = @S +             ' MAX(IsNull(I.TotalPRMScore, 0)) AS TotalPRMScore_Max,'
						Set @S = @S +             ' MAX(IsNull(I.FScore, 0)) AS FScore_Max,'
						Set @S = @S +             ' MIN(IsNull(I.PValue, 1)) AS PValue_Min,'
						Set @S = @S +             ' MAX(IsNull(SD.DiscriminantScoreNorm, 0)) As Discriminant_Score_Max,'
						Set @S = @S +             ' MAX(IsNull(SD.Peptide_Prophet_Probability, 0)) As Peptide_Prophet_Max,'
						Set @S = @S +             ' MIN(IsNull(SD.MSGF_SpecProb, 1)) As MSGF_SpecProb_Min'
						Set @S = @S +      ' FROM T_Peptides AS P INNER JOIN T_Analysis_Description AS TAD ON P.Job = TAD.Job'
						Set @S = @S +           ' LEFT OUTER JOIN T_Score_Inspect AS I ON P.Peptide_ID = I.Peptide_ID'
						Set @S = @S +           ' LEFT OUTER JOIN T_Score_Discriminant AS SD ON P.Peptide_ID = SD.Peptide_ID'
						Set @S = @S +      ' WHERE TAD.ResultType = ''IN_Peptide_Hit'' AND NOT P.Charge_State IS NULL AND'
						Set @S = @S +            ' I.DeltaNormTotalPRMScore ' + @DeltaCn2Comparison + Convert(varchar(11), @DeltaCn2Threshold)
						Set @S = @S +      ' GROUP BY TAD.Dataset_ID, P.Mass_Tag_ID, P.Scan_Number, P.GANET_Obs, P.Charge_State'
						Set @S = @S +      ') AS SubQ'
						Set @S = @S +   ' GROUP BY Dataset_ID, Mass_Tag_ID, Scan_Number, GANET_Obs, Charge_State'
						Set @S = @S +   ') AS StatsQ'
  						Set @S = @S +   ' INNER JOIN T_Mass_Tags AS MT ON StatsQ.Mass_Tag_ID = MT.Mass_Tag_ID'
						Set @S = @S +   ' LEFT OUTER JOIN T_Mass_Tag_to_Protein_Map AS MTPM ON MT.Mass_Tag_ID = MTPM.Mass_Tag_ID'
						Set @S = @S +   ' LEFT OUTER JOIN T_Mass_Tags_NET AS MTN ON MT.Mass_Tag_ID = MTN.Mass_Tag_ID'
						Set @S = @S + ' WHERE '
						Set @S = @S +   ' StatsQ.Charge_State ' +  @ChargeStateComparison + Convert(varchar(11), @ChargeStateThreshold) + ' AND '
						Set @S = @S +   ' StatsQ.MQScore_Max ' +  @InspectMQScoreComparison + Convert(varchar(11), @InspectMQScoreThreshold) + ' AND '
						Set @S = @S +   ' StatsQ.TotalPRMScore_Max ' +  @InspectTotalPRMScoreComparison + Convert(varchar(11), @InspectTotalPRMScoreThreshold) + ' AND '
						Set @S = @S +   ' StatsQ.FScore_Max ' +  @InspectFScoreComparison + Convert(varchar(11), @InspectFScoreThreshold) + ' AND '
						Set @S = @S +   ' StatsQ.PValue_Min ' +  @InspectPValueComparison + Convert(varchar(11), @InspectPValueThreshold) + ' AND '
						Set @S = @S +   ' ISNULL(MTPM.Cleavage_State, 0) ' + @CleavageStateComparison + Convert(varchar(11), @CleavageStateThreshold) + ' AND '
						Set @S = @S +   ' ISNULL(MTPM.Terminus_State, 0) ' + @TerminusStateComparison + Convert(varchar(11), @TerminusStateThreshold) + ' AND '
						Set @S = @S +   ' LEN(MT.Peptide) ' + @PeptideLengthComparison + Convert(varchar(11), @PeptideLengthThreshold) + ' AND '
						Set @S = @S +   ' IsNull(MT.Monoisotopic_Mass, 0) ' + @MassComparison + Convert(varchar(11), @MassThreshold) + ' AND '
						Set @S = @S +   ' StatsQ.Discriminant_Score_Max ' + @DiscriminantScoreComparison + Convert(varchar(11), @DiscriminantScoreThreshold) + ' AND '
						Set @S = @S +   ' StatsQ.Peptide_Prophet_Max ' + @PeptideProphetComparison + Convert(varchar(11), @PeptideProphetThreshold) + ' AND '
						Set @S = @S +   ' StatsQ.MSGF_SpecProb_Min ' +   @MSGFSpecProbComparison +   Convert(varchar(11), @MSGFSpecProbThreshold) + ' AND '
						Set @S = @S +   ' IsNull(ABS(StatsQ.GANET_Obs - MTN.PNET), 0) ' + @NETDifferenceAbsoluteComparison + Convert(varchar(11), @NETDifferenceAbsoluteThreshold) + ' AND '
						Set @S = @S +   ' IsNull(MT.Multiple_Proteins, 0) + 1 ' + @ProteinCountComparison + Convert(varchar(11), @ProteinCountThreshold)
						Set @S = @S + ' GROUP BY MT.Mass_Tag_ID, Dataset_ID, Scan_Number'
						
						If @PreviewSql <> 0
						Begin
							Print 'Inspect data, Filter Set ID: ' + Convert(varchar(12), @FilterSetID) + ', Criteria Group: ' + Convert(varchar(12), @CriteriaGroupStart)
							Print @S
						End
						Else
							Exec sp_executesql @S
						--
						SELECT @myRowCount = @@rowcount, @myError = @@error
						--
						Set @MTObsStatsRowCount = @MTObsStatsRowCount + @myRowCount

					End -- </e3>
					
					If @ResultType = 'MSG_Peptide_Hit'
					Begin -- <e4>
						Set @S = ''
						Set @S = @S + ' INSERT INTO #TmpMTObsStats (Mass_Tag_ID, Dataset_ID, Scan_Number)'
						Set @S = @S + ' SELECT MT.Mass_Tag_ID, Dataset_ID, Scan_Number'
						Set @S = @S + ' FROM ('
						Set @S = @S +   ' SELECT Dataset_ID, Mass_Tag_ID, Scan_Number, GANET_Obs, Charge_State,'
						Set @S = @S +     ' MIN(SubQ.MSGFDB_SpecProb_Min) AS MSGFDB_SpecProb_Min,'
						Set @S = @S +     ' MIN(SubQ.MSGFDB_PValue_Min) AS MSGFDB_PValue_Min,'
						Set @S = @S +     ' MIN(SubQ.MSGFDB_FDR_Min) AS MSGFDB_FDR_Min,'
						Set @S = @S +     ' MAX(SubQ.Discriminant_Score_Max) AS Discriminant_Score_Max,'
						Set @S = @S +     ' MAX(SubQ.Peptide_Prophet_Max) AS Peptide_Prophet_Max,'
						Set @S = @S +     ' MIN(SubQ.MSGF_SpecProb_Min) AS MSGF_SpecProb_Min'
						Set @S = @S +   ' FROM ('
						Set @S = @S +      ' SELECT TAD.Dataset_ID, P.Mass_Tag_ID, P.Scan_Number, P.GANET_Obs,'
						Set @S = @S +             ' P.Charge_State,'
						Set @S = @S +             ' MIN(IsNull(M.SpecProb, 1)) AS MSGFDB_SpecProb_Min,'
						Set @S = @S +             ' MIN(IsNull(M.PValue, 1)) AS MSGFDB_PValue_Min,'
						Set @S = @S +             ' MIN(IsNull(M.FDR, 1)) AS MSGFDB_FDR_Min,'
						Set @S = @S +             ' MAX(IsNull(SD.DiscriminantScoreNorm, 0)) As Discriminant_Score_Max,'
						Set @S = @S +             ' MAX(IsNull(SD.Peptide_Prophet_Probability, 0)) As Peptide_Prophet_Max,'
						Set @S = @S +             ' MIN(IsNull(SD.MSGF_SpecProb, 1)) As MSGF_SpecProb_Min'
						Set @S = @S +      ' FROM T_Peptides AS P INNER JOIN T_Analysis_Description AS TAD ON P.Job = TAD.Job'
						Set @S = @S +           ' LEFT OUTER JOIN T_Score_MSGFDB AS M ON P.Peptide_ID = M.Peptide_ID'
						Set @S = @S +           ' LEFT OUTER JOIN T_Score_Discriminant AS SD ON P.Peptide_ID = SD.Peptide_ID'
						Set @S = @S +      ' WHERE TAD.ResultType = ''MSG_Peptide_Hit'' AND NOT P.Charge_State IS NULL'
						Set @S = @S +      ' GROUP BY TAD.Dataset_ID, P.Mass_Tag_ID, P.Scan_Number, P.GANET_Obs, P.Charge_State'
						Set @S = @S +      ') AS SubQ'
						Set @S = @S +   ' GROUP BY Dataset_ID, Mass_Tag_ID, Scan_Number, GANET_Obs, Charge_State'
						Set @S = @S +   ') AS StatsQ'
  						Set @S = @S +   ' INNER JOIN T_Mass_Tags AS MT ON StatsQ.Mass_Tag_ID = MT.Mass_Tag_ID'
						Set @S = @S +   ' LEFT OUTER JOIN T_Mass_Tag_to_Protein_Map AS MTPM ON MT.Mass_Tag_ID = MTPM.Mass_Tag_ID'
						Set @S = @S +   ' LEFT OUTER JOIN T_Mass_Tags_NET AS MTN ON MT.Mass_Tag_ID = MTN.Mass_Tag_ID'
						Set @S = @S + ' WHERE '
						Set @S = @S +   ' StatsQ.Charge_State ' +  @ChargeStateComparison + Convert(varchar(11), @ChargeStateThreshold) + ' AND '
						Set @S = @S +   ' StatsQ.MSGFDB_SpecProb_Min ' +  @MSGFDbSpecProbComparison + Convert(varchar(11), @MSGFDbSpecProbThreshold) + ' AND '
						Set @S = @S +   ' StatsQ.MSGFDB_PValue_Min ' +  @MSGFDbPValueComparison + Convert(varchar(11), @MSGFDbPValueThreshold) + ' AND '
						Set @S = @S +   ' StatsQ.MSGFDB_FDR_Min ' +  @MSGFDbFDRComparison + Convert(varchar(11), @MSGFDbFDRThreshold) + ' AND '
						Set @S = @S +   ' ISNULL(MTPM.Cleavage_State, 0) ' + @CleavageStateComparison + Convert(varchar(11), @CleavageStateThreshold) + ' AND '
						Set @S = @S +   ' ISNULL(MTPM.Terminus_State, 0) ' + @TerminusStateComparison + Convert(varchar(11), @TerminusStateThreshold) + ' AND '
						Set @S = @S +   ' LEN(MT.Peptide) ' + @PeptideLengthComparison + Convert(varchar(11), @PeptideLengthThreshold) + ' AND '
						Set @S = @S +   ' IsNull(MT.Monoisotopic_Mass, 0) ' + @MassComparison + Convert(varchar(11), @MassThreshold) + ' AND '
						Set @S = @S +   ' StatsQ.Discriminant_Score_Max ' + @DiscriminantScoreComparison + Convert(varchar(11), @DiscriminantScoreThreshold) + ' AND '
						Set @S = @S +   ' StatsQ.Peptide_Prophet_Max ' + @PeptideProphetComparison + Convert(varchar(11), @PeptideProphetThreshold) + ' AND '
						Set @S = @S +   ' StatsQ.MSGF_SpecProb_Min ' +   @MSGFSpecProbComparison +   Convert(varchar(11), @MSGFSpecProbThreshold) + ' AND '
						Set @S = @S +   ' IsNull(ABS(StatsQ.GANET_Obs - MTN.PNET), 0) ' + @NETDifferenceAbsoluteComparison + Convert(varchar(11), @NETDifferenceAbsoluteThreshold) + ' AND '
						Set @S = @S +   ' IsNull(MT.Multiple_Proteins, 0) + 1 ' + @ProteinCountComparison + Convert(varchar(11), @ProteinCountThreshold)
						Set @S = @S + ' GROUP BY MT.Mass_Tag_ID, Dataset_ID, Scan_Number'
						
						If @PreviewSql <> 0
						Begin
							Print 'MSGFDB data, Filter Set ID: ' + Convert(varchar(12), @FilterSetID) + ', Criteria Group: ' + Convert(varchar(12), @CriteriaGroupStart)
							Print @S
						End
						Else
							Exec sp_executesql @S
						--
						SELECT @myRowCount = @@rowcount, @myError = @@error
						--
						Set @MTObsStatsRowCount = @MTObsStatsRowCount + @myRowCount
					End -- </e4>

					If @ResultType = 'MSA_Peptide_Hit'
					Begin -- <e5>
						Set @S = ''
						Set @S = @S + ' INSERT INTO #TmpMTObsStats (Mass_Tag_ID, Dataset_ID, Scan_Number)'
						Set @S = @S + ' SELECT MT.Mass_Tag_ID, Dataset_ID, Scan_Number'
						Set @S = @S + ' FROM ('
						Set @S = @S +   ' SELECT Dataset_ID, Mass_Tag_ID, Scan_Number, GANET_Obs, Charge_State,'
						Set @S = @S +     ' MIN(SubQ.MSAlign_PValue_Min) AS MSAlign_PValue_Min,'
						Set @S = @S +     ' MIN(SubQ.MSAlign_FDR_Min) AS MSAlign_FDR_Min,'
						Set @S = @S +     ' MAX(SubQ.Discriminant_Score_Max) AS Discriminant_Score_Max,'
						Set @S = @S +     ' MAX(SubQ.Peptide_Prophet_Max) AS Peptide_Prophet_Max,'
						Set @S = @S +     ' MIN(SubQ.MSGF_SpecProb_Min) AS MSGF_SpecProb_Min'
						Set @S = @S +   ' FROM ('
						Set @S = @S +      ' SELECT TAD.Dataset_ID, P.Mass_Tag_ID, P.Scan_Number, P.GANET_Obs,'
						Set @S = @S +             ' P.Charge_State,'
						Set @S = @S +             ' MIN(IsNull(M.PValue, 1)) AS MSAlign_PValue_Min,'
						Set @S = @S +             ' MIN(IsNull(M.FDR, 1)) AS MSAlign_FDR_Min,'
						Set @S = @S +             ' MAX(IsNull(SD.DiscriminantScoreNorm, 0)) As Discriminant_Score_Max,'
						Set @S = @S +             ' MAX(IsNull(SD.Peptide_Prophet_Probability, 0)) As Peptide_Prophet_Max,'
						Set @S = @S +             ' MIN(IsNull(SD.MSGF_SpecProb, 1)) As MSGF_SpecProb_Min'
						Set @S = @S +      ' FROM T_Peptides AS P INNER JOIN T_Analysis_Description AS TAD ON P.Job = TAD.Job'
						Set @S = @S +           ' LEFT OUTER JOIN T_Score_MSAlign AS M ON P.Peptide_ID = M.Peptide_ID'
						Set @S = @S +           ' LEFT OUTER JOIN T_Score_Discriminant AS SD ON P.Peptide_ID = SD.Peptide_ID'
						Set @S = @S +      ' WHERE TAD.ResultType = ''MSA_Peptide_Hit'' AND NOT P.Charge_State IS NULL'
						Set @S = @S +  ' GROUP BY TAD.Dataset_ID, P.Mass_Tag_ID, P.Scan_Number, P.GANET_Obs, P.Charge_State'
						Set @S = @S +      ') AS SubQ'
						Set @S = @S +   ' GROUP BY Dataset_ID, Mass_Tag_ID, Scan_Number, GANET_Obs, Charge_State'
						Set @S = @S +   ') AS StatsQ'
  						Set @S = @S +   ' INNER JOIN T_Mass_Tags AS MT ON StatsQ.Mass_Tag_ID = MT.Mass_Tag_ID'
						Set @S = @S +   ' LEFT OUTER JOIN T_Mass_Tag_to_Protein_Map AS MTPM ON MT.Mass_Tag_ID = MTPM.Mass_Tag_ID'
						Set @S = @S +   ' LEFT OUTER JOIN T_Mass_Tags_NET AS MTN ON MT.Mass_Tag_ID = MTN.Mass_Tag_ID'
						Set @S = @S + ' WHERE '
						Set @S = @S +   ' StatsQ.Charge_State ' +  @ChargeStateComparison + Convert(varchar(11), @ChargeStateThreshold) + ' AND '
						Set @S = @S +   ' StatsQ.MSAlign_PValue_Min ' +  @MSAlignPValueComparison + Convert(varchar(11), @MSAlignPValueThreshold) + ' AND '
						Set @S = @S +   ' StatsQ.MSAlign_FDR_Min ' +  @MSAlignFDRComparison + Convert(varchar(11), @MSAlignFDRThreshold) + ' AND '
						Set @S = @S +   ' ISNULL(MTPM.Cleavage_State, 0) ' + @CleavageStateComparison + Convert(varchar(11), @CleavageStateThreshold) + ' AND '
						Set @S = @S +   ' ISNULL(MTPM.Terminus_State, 0) ' + @TerminusStateComparison + Convert(varchar(11), @TerminusStateThreshold) + ' AND '
						Set @S = @S +   ' LEN(MT.Peptide) ' + @PeptideLengthComparison + Convert(varchar(11), @PeptideLengthThreshold) + ' AND '
						Set @S = @S +   ' IsNull(MT.Monoisotopic_Mass, 0) ' + @MassComparison + Convert(varchar(11), @MassThreshold) + ' AND '
						Set @S = @S +   ' StatsQ.Discriminant_Score_Max ' + @DiscriminantScoreComparison + Convert(varchar(11), @DiscriminantScoreThreshold) + ' AND '
						Set @S = @S +   ' StatsQ.Peptide_Prophet_Max ' + @PeptideProphetComparison + Convert(varchar(11), @PeptideProphetThreshold) + ' AND '
						---------------------------------------------
						-- Note: Ignoring MSGF_SpecProb for MSAlign
						-- Set @S = @S +   ' StatsQ.MSGF_SpecProb_Min ' +   @MSGFSpecProbComparison +   Convert(varchar(11), @MSGFSpecProbThreshold) + ' AND '
						---------------------------------------------					
						Set @S = @S +   ' IsNull(ABS(StatsQ.GANET_Obs - MTN.PNET), 0) ' + @NETDifferenceAbsoluteComparison + Convert(varchar(11), @NETDifferenceAbsoluteThreshold) + ' AND '
						Set @S = @S +   ' IsNull(MT.Multiple_Proteins, 0) + 1 ' + @ProteinCountComparison + Convert(varchar(11), @ProteinCountThreshold)
						Set @S = @S + ' GROUP BY MT.Mass_Tag_ID, Dataset_ID, Scan_Number'
						
						If @PreviewSql <> 0
						Begin
							Print 'MSAlign data, Filter Set ID: ' + Convert(varchar(12), @FilterSetID) + ', Criteria Group: ' + Convert(varchar(12), @CriteriaGroupStart)
							Print @S
						End
						Else
							Exec sp_executesql @S
						--
						SELECT @myRowCount = @@rowcount, @myError = @@error
						--
						Set @MTObsStatsRowCount = @MTObsStatsRowCount + @myRowCount
					End -- </e5>
					
					--
					If @myError <> 0 
					Begin
						If @myError = 51200
							set @message = 'Error evaluating filter set criterion; Invalid ResultType ''' + @ResultType + ''''
						Else
							set @message = 'Error evaluating filter set criterion'
						Goto done
					End

					if DateDiff(second, @lastProgressUpdate, GetDate()) >= @ProgressUpdateIntervalThresholdSeconds And @PreviewSql = 0
					Begin
						set @message = '...Processing: Populating #TmpMTObsStats (has ' + convert(varchar(19), @MTObsStatsRowCount) + ' total rows)'
						execute PostLogEntry 'Progress', @message, 'ComputeMassTagsAnalysisCounts'
						set @message = ''
						set @lastProgressUpdate = GetDate()
						
						-- Validate that updating is enabled, abort if not enabled
						exec VerifyUpdateEnabled @CallingFunctionDescription = 'ComputeMassTagsAnalysisCounts', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
						If @UpdateEnabled = 0
							Goto Done
					End

					-----------------------------------------------------------
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

				End -- </d>
			End -- </c>	

			If @PreviewSql <> 0
				Print ' '
					
			-- Increment @CriteriaGroupStart so that we can lookup the next set of filters
			Set @CriteriaGroupStart = @CriteriaGroupMatch + 1

		End -- </b>
	
	
		-- Update T_Mass_Tags with the observation counts
		Set @S = ''
		Set @S = @S + ' UPDATE T_Mass_Tags'
		Set @S = @S + ' SET Peptide_Obs_Count_Passing_Filter = IsNull(StatsQ.Obs_Count, 0)'
		Set @S = @S + ' FROM T_Mass_Tags LEFT OUTER JOIN'
		Set @S = @S +    ' ( SELECT Mass_Tag_ID, Count(*) AS Obs_Count'
		Set @S = @S +      ' FROM ( SELECT DISTINCT Mass_Tag_ID, Dataset_ID, Scan_Number'
		Set @S = @S +             ' FROM #TmpMTObsStats'
		Set @S = @S +           ' ) InnerQ'
		Set @S = @S +      ' GROUP By Mass_Tag_ID'
		Set @S = @S +    ' ) AS StatsQ ON T_Mass_Tags.Mass_Tag_ID = StatsQ.Mass_Tag_ID'
		
		If @PreviewSql <> 0
			Print @S
		Else
			Exec sp_executesql @S
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		Set @MTRowsUpdated = @myRowCount

	End -- </a>

	If @PreviewSql = 0
	Begin
		-- Post a log entry
		Set @message = 'Updated observation counts in T_Mass_Tags using filter set ' + Convert(varchar(9), @FilterSetID) + '; ' + Convert(varchar(19), @MTRowsUpdated) + ' rows updated'
		execute PostLogEntry 'Normal', @message, 'ComputeMassTagsAnalysisCounts'
	End
	
Done:
	Return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[ComputeMassTagsAnalysisCounts] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[ComputeMassTagsAnalysisCounts] TO [MTS_DB_Lite] AS [dbo]
GO
