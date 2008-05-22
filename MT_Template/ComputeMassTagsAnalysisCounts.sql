/****** Object:  StoredProcedure [dbo].[ComputeMassTagsAnalysisCounts] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.ComputeMassTagsAnalysisCounts
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
**    
*****************************************************/
(
	@message varchar(255)='' OUTPUT,
	@UpdateFilteredObsStatsOnly tinyint = 0,
	@previewSql tinyint = 0
)
AS

	set nocount on

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

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
	Set @S = @S +    ' INNER JOIN T_Analysis_Description TAD ON P.Analysis_ID = TAD.Job'
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
	
	INSERT INTO #T_ResultTypeList (ResultType) Values ('Peptide_Hit')
	INSERT INTO #T_ResultTypeList (ResultType) Values ('XT_Peptide_Hit')


	If @UpdateFilteredObsStatsOnly = 0
	Begin
		
		-----------------------------------------------------------
		-- Update the general stats by examining T_Peptides and associated tables
		-- Note that the source data for this query is a UNION between the 
		-- Peptide_Hit (Sequest) data and the XT_Peptide_Hit (XTandem) data
		-----------------------------------------------------------
		--
		Set @S = ''
		Set @S = @S + ' UPDATE T_Mass_Tags'
		Set @S = @S + ' SET Number_Of_Peptides = IsNull(StatsQ.ObservationCount, 0),'
		Set @S = @S +    ' High_Normalized_Score = IsNull(StatsQ.Normalized_Score_Max, 0),'
		Set @S = @S +    ' High_Discriminant_Score = IsNull(StatsQ.Discriminant_Score_Max, 0),'
		Set @S = @S +    ' High_Peptide_Prophet_Probability = IsNull(StatsQ.Peptide_Prophet_Probability_Max, 0),'
		Set @S = @S +    ' Min_Log_EValue = IsNull(StatsQ.Log_Evalue_Min, 0)'
		Set @S = @S + ' FROM T_Mass_Tags LEFT OUTER JOIN'
		Set @S = @S +    ' ('
		Set @S = @S +       ' SELECT	Mass_Tag_ID, '
		Set @S = @S +             ' COUNT(*) AS ObservationCount, '
		Set @S = @S +             ' MAX(Normalized_Score_Max) AS Normalized_Score_Max,'
		Set @S = @S +             ' MAX(Discriminant_Score_Max) AS Discriminant_Score_Max,'
		Set @S = @S +             ' MAX(Peptide_Prophet_Probability_Max) AS Peptide_Prophet_Probability_Max,'
		Set @S = @S +             ' MIN(Log_Evalue_Min) AS Log_Evalue_Min'
		Set @S = @S +       ' FROM (	SELECT Dataset_ID, Mass_Tag_ID, Scan_Number,'
		Set @S = @S +                '    MAX(Normalized_Score) AS Normalized_Score_Max, '
		Set @S = @S +                '    MAX(Discriminant_Score) AS Discriminant_Score_Max,'
		Set @S = @S +                '    MAX(Peptide_Prophet_Probability) AS Peptide_Prophet_Probability_Max,'
		Set @S = @S +                '    MIN(Log_Evalue) AS Log_Evalue_Min'
		Set @S = @S +             ' FROM (	SELECT	TAD.Dataset_ID, P.Mass_Tag_ID, P.Scan_Number, '
		Set @S = @S +                         ' ISNULL(SS.XCorr, 0) AS Normalized_Score,'
		Set @S = @S +                         ' ISNULL(SD.DiscriminantScoreNorm, 0) AS Discriminant_Score,'
		Set @S = @S +                         ' ISNULL(SD.Peptide_Prophet_Probability, 0) AS Peptide_Prophet_Probability,'
		Set @S = @S +                         ' 0 AS Log_Evalue'
		Set @S = @S +                   ' FROM T_Peptides AS P INNER JOIN '
		Set @S = @S +                      '  T_Analysis_Description AS TAD ON P.Analysis_ID = TAD.Job LEFT OUTER JOIN '
		Set @S = @S +                      '  T_Score_Sequest AS SS ON P.Peptide_ID = SS.Peptide_ID LEFT OUTER JOIN '
		Set @S = @S +                      '  T_Score_Discriminant AS SD ON P.Peptide_ID = SD.Peptide_ID'
		Set @S = @S +                   ' WHERE TAD.ResultType = ''Peptide_Hit'''
		Set @S = @S +                   ' UNION'
		Set @S = @S +                   ' SELECT	TAD.Dataset_ID, P.Mass_Tag_ID, P.Scan_Number, '
		Set @S = @S +                         ' ISNULL(X.Normalized_Score, 0) AS Normalized_Score,'
		Set @S = @S +                         ' ISNULL(SD.DiscriminantScoreNorm, 0) AS Discriminant_Score,'
		Set @S = @S +                         ' ISNULL(SD.Peptide_Prophet_Probability, 0) AS Peptide_Prophet_Probability,'
		Set @S = @S +                         ' ISNULL(X.Log_Evalue, 0) AS Log_Evalue'
		Set @S = @S +                   ' FROM T_Peptides AS P INNER JOIN '
		Set @S = @S +                      '  T_Analysis_Description AS TAD ON P.Analysis_ID = TAD.Job LEFT OUTER JOIN '
		Set @S = @S +                      '  T_Score_XTandem AS X ON P.Peptide_ID = X.Peptide_ID LEFT OUTER JOIN '
		Set @S = @S +                '  T_Score_Discriminant AS SD ON P.Peptide_ID = SD.Peptide_ID'
		Set @S = @S +                   ' WHERE TAD.ResultType = ''XT_Peptide_Hit'''
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
			@SpectrumCountThreshold int,					-- Not used in this SP
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
			@DeltaCnComparison varchar(2),					-- Only used for Sequest results
			@DeltaCnThreshold float,						-- Only used for Sequest results
			@DeltaCn2Comparison varchar(2),					-- Used for both Sequest and XTandem results
			@DeltaCn2Threshold float,						-- Used for both Sequest and XTandem results
			@DiscriminantScoreComparison varchar(2),
			@DiscriminantScoreThreshold float,
			@NETDifferenceAbsoluteComparison varchar(2),
			@NETDifferenceAbsoluteThreshold float,
			@DiscriminantInitialFilterComparison varchar(2),	-- Not used in this SP
			@DiscriminantInitialFilterThreshold float,			-- Not used in this SP
			@ProteinCountComparison varchar(2),
			@ProteinCountThreshold int,
			@TerminusStateComparison varchar(2),
			@TerminusStateThreshold tinyint,
			@XTandemHyperscoreComparison varchar(2),		-- Only used for XTandem results
			@XTandemHyperscoreThreshold real,				-- Only used for XTandem results
			@XTandemLogEValueComparison varchar(2),			-- Only used for XTandem results
			@XTandemLogEValueThreshold real,				-- Only used for XTandem results
			@PeptideProphetComparison varchar(2),
			@PeptideProphetThreshold float

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

		-- Now call GetThresholdsForFilterSet to get the tresholds to filter against
		-- Set Passes_Filter to 1 in #TmpMTObsStats for the matching mass tags
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
										@XTandemLogEValueComparison OUTPUT, @XTandemLogEValueThreshold OUTPUT,
										@PeptideProphetComparison OUTPUT, @PeptideProphetThreshold OUTPUT

		While @CriteriaGroupMatch > 0
		Begin -- <b>

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
			Begin -- <c>

				-- Populate #TmpMTObsStats with the PMT tags passing the current criteria
				-- Initially set @myError to a non-zero value in case @ResultType is invalid for this SP
				-- Note that this error code is used below so update in both places if changing
				--
				Set @myError = 51200
				If @ResultType = 'Peptide_Hit'
				Begin -- <d>
					Set @S = ''
					Set @S = @S + ' INSERT INTO #TmpMTObsStats (Mass_Tag_ID, Dataset_ID, Scan_Number)'
					Set @S = @S + ' SELECT MT.Mass_Tag_ID, Dataset_ID, Scan_Number'
					Set @S = @S + ' FROM ('
					Set @S = @S +   ' SELECT Dataset_ID, Mass_Tag_ID, Scan_Number, GANET_Obs, Charge_State,'
					Set @S = @S +     ' MAX(SubQ.XCorr_Max) AS XCorr_Max,'
					Set @S = @S +     ' MAX(SubQ.Discriminant_Score_Max) AS Discriminant_Score_Max,'
					Set @S = @S +     ' MAX(SubQ.Peptide_Prophet_Max) AS Peptide_Prophet_Max'
					Set @S = @S +   ' FROM ('
					Set @S = @S +      ' SELECT TAD.Dataset_ID, P.Mass_Tag_ID, P.Scan_Number, P.GANET_Obs,'
					Set @S = @S +             ' P.Charge_State,'
					Set @S = @S +             ' MAX(IsNull(SS.XCorr, 0)) AS XCorr_Max,'
					Set @S = @S +             ' MAX(IsNull(SD.DiscriminantScoreNorm, 0)) As Discriminant_Score_Max,'
					Set @S = @S +             ' MAX(IsNull(SD.Peptide_Prophet_Probability, 0)) As Peptide_Prophet_Max'
					Set @S = @S +      ' FROM T_Peptides AS P INNER JOIN T_Analysis_Description AS TAD ON P.Analysis_ID = TAD.Job'
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
					Set @S = @S +   ' LEFT OUTER JOIN T_Mass_Tags_NET AS MTN ON MT.Mass_Tag_ID = MTN.Mass_Tag_ID'
					Set @S = @S + ' WHERE '
					Set @S = @S +   ' StatsQ.Charge_State ' +  @ChargeStateComparison + Convert(varchar(11), @ChargeStateThreshold) + ' AND '
					Set @S = @S +   ' XCorr_Max ' +  @HighNormalizedScoreComparison + Convert(varchar(11), @HighNormalizedScoreThreshold) + ' AND '
					Set @S = @S +   ' ISNULL(MTPM.Cleavage_State, 0) ' + @CleavageStateComparison + Convert(varchar(11), @CleavageStateThreshold) + ' AND '
					Set @S = @S +   ' ISNULL(MTPM.Terminus_State, 0) ' + @TerminusStateComparison + Convert(varchar(11), @TerminusStateThreshold) + ' AND '
					Set @S = @S +   ' LEN(MT.Peptide) ' + @PeptideLengthComparison + Convert(varchar(11), @PeptideLengthThreshold) + ' AND '
					Set @S = @S +   ' IsNull(MT.Monoisotopic_Mass, 0) ' + @MassComparison + Convert(varchar(11), @MassThreshold) + ' AND '
					Set @S = @S +   ' StatsQ.Discriminant_Score_Max ' + @DiscriminantScoreComparison + Convert(varchar(11), @DiscriminantScoreThreshold) + ' AND '
					Set @S = @S +   ' StatsQ.Peptide_Prophet_Max ' + @PeptideProphetComparison + Convert(varchar(11), @PeptideProphetThreshold) + ' AND '
					Set @S = @S +   ' IsNull(ABS(StatsQ.GANET_Obs - MTN.PNET), 0) ' + @NETDifferenceAbsoluteComparison + Convert(varchar(11), @NETDifferenceAbsoluteThreshold) + ' AND '
					Set @S = @S +   ' IsNull(MT.Multiple_Proteins, 0) + 1 ' + @ProteinCountComparison + Convert(varchar(11), @ProteinCountThreshold)
					Set @S = @S + ' GROUP BY MT.Mass_Tag_ID, Dataset_ID, Scan_Number'

					If @PreviewSql <> 0
						Print @S
					Else
						Exec sp_executesql @S
					--
					SELECT @myRowCount = @@rowcount, @myError = @@error
					--
					Set @MTObsStatsRowCount = @MTObsStatsRowCount + @myRowCount
				End -- </d>

				If @ResultType = 'XT_Peptide_Hit'
				Begin -- <d>
					Set @S = ''
					Set @S = @S + ' INSERT INTO #TmpMTObsStats (Mass_Tag_ID, Dataset_ID, Scan_Number)'
					Set @S = @S + ' SELECT MT.Mass_Tag_ID, Dataset_ID, Scan_Number'
					Set @S = @S + ' FROM ('
					Set @S = @S +   ' SELECT Dataset_ID, Mass_Tag_ID, Scan_Number, GANET_Obs, Charge_State,'
					Set @S = @S +     ' MAX(SubQ.Hyperscore_Max) AS Hyperscore_Max,'
					Set @S = @S +     ' MIN(SubQ.Log_EValue_Min) AS Log_EValue_Min,'
					Set @S = @S +     ' MAX(SubQ.Discriminant_Score_Max) AS Discriminant_Score_Max,'
					Set @S = @S +     ' MAX(SubQ.Peptide_Prophet_Max) AS Peptide_Prophet_Max'
					Set @S = @S +   ' FROM ('
					Set @S = @S +      ' SELECT TAD.Dataset_ID, P.Mass_Tag_ID, P.Scan_Number, P.GANET_Obs,'
					Set @S = @S +             ' P.Charge_State,'
					Set @S = @S +             ' MAX(IsNull(X.Hyperscore, 0)) AS Hyperscore_Max,'
					Set @S = @S +             ' MIN(IsNull(X.Log_EValue, 0)) AS Log_EValue_Min,'
					Set @S = @S +             ' MAX(IsNull(SD.DiscriminantScoreNorm, 0)) As Discriminant_Score_Max,'
					Set @S = @S +             ' MAX(IsNull(SD.Peptide_Prophet_Probability, 0)) As Peptide_Prophet_Max'
					Set @S = @S +      ' FROM T_Peptides AS P INNER JOIN T_Analysis_Description AS TAD ON P.Analysis_ID = TAD.Job'
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
					Set @S = @S +   ' Hyperscore_Max ' +  @XTandemHyperscoreComparison + Convert(varchar(11), @XTandemHyperscoreThreshold) + ' AND '
					Set @S = @S +   ' Log_EValue_Min ' +  @XTandemLogEValueComparison + Convert(varchar(11), @XTandemLogEValueThreshold) + ' AND '
					Set @S = @S +   ' ISNULL(MTPM.Cleavage_State, 0) ' + @CleavageStateComparison + Convert(varchar(11), @CleavageStateThreshold) + ' AND '
					Set @S = @S +   ' ISNULL(MTPM.Terminus_State, 0) ' + @TerminusStateComparison + Convert(varchar(11), @TerminusStateThreshold) + ' AND '
					Set @S = @S +   ' LEN(MT.Peptide) ' + @PeptideLengthComparison + Convert(varchar(11), @PeptideLengthThreshold) + ' AND '
					Set @S = @S +   ' IsNull(MT.Monoisotopic_Mass, 0) ' + @MassComparison + Convert(varchar(11), @MassThreshold) + ' AND '
					Set @S = @S +   ' StatsQ.Discriminant_Score_Max ' + @DiscriminantScoreComparison + Convert(varchar(11), @DiscriminantScoreThreshold) + ' AND '
					Set @S = @S +   ' StatsQ.Peptide_Prophet_Max ' + @PeptideProphetComparison + Convert(varchar(11), @PeptideProphetThreshold) + ' AND '
					Set @S = @S +   ' IsNull(ABS(StatsQ.GANET_Obs - MTN.PNET), 0) ' + @NETDifferenceAbsoluteComparison + Convert(varchar(11), @NETDifferenceAbsoluteThreshold) + ' AND '
					Set @S = @S +   ' IsNull(MT.Multiple_Proteins, 0) + 1 ' + @ProteinCountComparison + Convert(varchar(11), @ProteinCountThreshold)
					Set @S = @S + ' GROUP BY MT.Mass_Tag_ID, Dataset_ID, Scan_Number'

					If @PreviewSql <> 0
						Print @S
					Else
						Exec sp_executesql @S
					--
					SELECT @myRowCount = @@rowcount, @myError = @@error
					--
					Set @MTObsStatsRowCount = @MTObsStatsRowCount + @myRowCount
				End -- </d>

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

			End -- </c>
			
			-- Lookup the next set of filters
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
											@XTandemLogEValueComparison OUTPUT, @XTandemLogEValueThreshold OUTPUT,
											@PeptideProphetComparison OUTPUT, @PeptideProphetThreshold OUTPUT

			If @myError <> 0
			Begin
				Set @Message = 'Error retrieving next entry from GetThresholdsForFilterSet in CheckFilterForAvailableAnalyses'
				Goto Done
			End


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
