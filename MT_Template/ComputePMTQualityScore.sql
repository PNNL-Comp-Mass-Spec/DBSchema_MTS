/****** Object:  StoredProcedure [dbo].[ComputePMTQualityScore] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.ComputePMTQualityScore
/****************************************************	
**	Populates the PMT_Quality_Score column in T_Mass Tags by examining
**   the highest normalized score value for each mass tag, the number
**   of MS/MS analyses the peptide was observed in, and several other metrics
**
**	Auth:	mem
**	Date:	01/07/2004
**			01/13/2004 mem - added @ResetScoresToZero parameter
**			01/22/2004 mem - Moved Exec (@Sql) to be between the Begin/End pair constructing @Sql
**			02/02/2004 mem - Changed to looser scoring criteria
**			02/09/2004 mem - Switched from specifying thresholds as input parameters to using T_PMT_Quality_Score_Sets and T_PMT_Quality_Score_SetDetails
**			03/27/2004 mem - Added Cleavage_State_Threshold to T_PMT_Quality_Score_SetDetails and moved T_PMT_Quality_Score_Sets and T_PMT_Quality_Score_SetDetails to MT_Main
**						   - Added InfoOnly parameter, to allow previewing what would get changed
**			04/12/2004 mem - Added support for Peptide_Length_Comparison and Peptide_Length_Threshold
**			05/10/1004 mem - Modified logic to only count once identifications of the same peptide in the same scan from multiple Sequest analyses of the same Dataset
**			05/11/2004 mem - Now updating T_Mass_Tags.Number_Of_Peptides for each mass tag with the non-redundant identification count value
**			09/20/2004 mem - Updated to use T_Process_Config and the new T_Score tables and to use DMS-based filters; fixed bug with computation of ObservationCount
**			09/28/2004 mem - Added support for DeltaCn and DeltaCn2 thresholds
**			09/29/2004 mem - Added support for an Experiment name filter in T_Process_Config
**			01/20/2005 mem - Added sorting of data in #FilterSetDetails by ascending Score_Value
**			01/27/2005 mem - Fixed bug with @DiscriminantScoreComparison variable length
**			03/26/2005 mem - Updated call to GetThresholdsForFilterSet to include @ProteinCount and @TerminusState criteria
**			05/04/2005 mem - Now listing PMT Quality Score IDs in log message
**			05/20/2005 mem - Updated logic to only use entries from T_Mass_Tags with Internal_Standard_Only = 0
**			09/28/2005 mem - Added support for option PMT_Quality_Score_Uses_Filtered_Peptide_Obs_Count in T_Process_Config
**			12/11/2005 mem - Added support for XTandem results
**			01/23/2006 mem - Now posting a message to T_Log_Entries on Success
**			03/13/2006 mem - Now calling UpdateCachedHistograms
**			07/10/2006 mem - Added support for Peptide Prophet scores
**			08/26/2006 mem - Added support for RankScore (aka RankXc for Sequest); currently only used with Sequest results
**			02/07/2007 mem - Added parameter @PreviewSql and switched to using sp_executesql
**			06/08/2007 mem - Now calling GetPMTQualityScoreFilterSetDetails to populate #FilterSetDetails
**			09/07/2007 mem - Now posting log entries if the stored procedure runs for more than 2 minutes
**
****************************************************/
(
	@message varchar(255)='' Output,
	@InfoOnly tinyint = 0,
	@ResetScoresToZero tinyint = 1,			-- By default, will reset all of the PMT_Quality_Scores to 0 before applying the above filter; set to 0 to not reset the scores
	@PreviewSql tinyint = 0
)
As
	Set NoCount On

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Declare @FilterSetID int,
			@FilterSetScore float,
			@FilterSetExperimentFilter varchar(128)

	Declare @MassTagCountNonZero int,
			@MassTagCountZero int,
			@UniqueRowID int,
			@Continue int
	
	Declare @FilterSetsEvaluated int
	Set @FilterSetsEvaluated = 0
	
	Declare @RowCountTotalEvaluated int
	Set @RowCountTotalEvaluated = 0

	Declare @WarningMessage varchar(75),
			@Sql nvarchar(max),
			@ObsSql varchar(64),
			@FilterSetList varchar(128)
			
	Set @message= ''
	Set @WarningMessage = ''
	Set @FilterSetList = ''

	declare @ResultTypeID int
	declare @ResultType varchar(64)
	Set @ResultType = 'Unknown'

	declare @lastProgressUpdate datetime
	Set @lastProgressUpdate = GetDate()

	declare @ProgressUpdateIntervalThresholdSeconds int
	Set @ProgressUpdateIntervalThresholdSeconds = 120

	-----------------------------------------------
	-- Validate the inputs
	-----------------------------------------------
	Set @InfoOnly = IsNull(@InfoOnly, 0)
	Set @PreviewSql = IsNull(@PreviewSql, 0)
	
	If @PreviewSql <> 0
		Set @InfoOnly = 1
		
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
	-- Create a temporary table to store the new PMT Quality Score values
	-- Necessary if @InfoOnly = 1, and also useful to reduce the total additions to the database's transaction log
	-----------------------------------------------------------

	CREATE TABLE #NewMassTagScores (
		[Mass_Tag_ID] int NOT NULL,
		[PMT_Quality_Score] float NOT NULL
	) ON [PRIMARY]

	CREATE UNIQUE INDEX #IX_NewMassTagScores ON #NewMassTagScores (Mass_Tag_ID ASC)
	
	If @PreviewSql = 0
	Begin
		If IsNull(@ResetScoresToZero, 0) <> 0
		Begin
			INSERT INTO #NewMassTagScores
			SELECT Mass_Tag_ID, 0
			FROM T_Mass_Tags
			WHERE Internal_Standard_Only = 0
			ORDER BY Mass_Tag_ID
		End
		Else
		Begin
			INSERT INTO #NewMassTagScores
			SELECT Mass_Tag_ID, IsNull(PMT_Quality_Score, 0) AS PMT_Quality_Score
			FROM T_Mass_Tags
			WHERE Internal_Standard_Only = 0
			ORDER BY Mass_Tag_ID
		End
		--
		SELECT @myError = @@error, @myRowCount = @@RowCount
		--
		If @myError <> 0
		Begin
			Set @Message = 'Error populating #NewMassTagScores'
			Goto Done
		End
	End
		 
	-----------------------------------------------------------
	-- Create the Peptide Stats temporary table
	-----------------------------------------------------------

	if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#PeptideStats]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		truncate table [dbo].[#PeptideStats]
	else
	Begin
		CREATE TABLE #PeptideStats (
			[Mass_Tag_ID] [int] NOT NULL,
			[PeptideLength] [smallint] NOT NULL,
			[MonoisotopicMass] [float] NOT NULL,
			[NETDifferenceAbsolute] [real] NOT NULL,
			[ProteinCount] [int] NOT NULL,
			[MaxCleavageState] [tinyint] NOT NULL,
			[MaxTerminusState] [tinyint] NOT NULL,
			[ObservationCount] [int] NOT NULL,			-- Total number of observations for given Mass Tag for all charge states
			[Charge_State] [smallint] NOT NULL,
			[XCorr_Max] [float] NOT NULL,				-- Only used for Sequest data
			[Hyperscore_Max] [real] NOT NULL,			-- Only used for XTandem data
			[Log_EValue_Min] [real] NOT NULL,			-- Only used for XTandem data
			[Discriminant_Score_Max] [float] NOT NULL,
			[Peptide_Prophet_Max] [float] NOT NULL
		) ON [PRIMARY]
		
		CREATE UNIQUE INDEX #IX_PeptideStats ON #PeptideStats (Mass_Tag_ID, Charge_State)
	End


	-----------------------------------------------------------
	-- Create the temporary table to hold the Filter Sets to test
	-----------------------------------------------------------

	CREATE TABLE #FilterSetDetails (
		Filter_Set_Text varchar(256),
		Filter_Set_ID int NULL,
		Score_Value real NULL,
		Experiment_Filter varchar(128) NULL,
		Unique_Row_ID int Identity(1,1)
	)
	
	-----------------------------------------------------------
	-- Populate the table with the Filter Set Info
	-----------------------------------------------------------
	--
	Exec @myError = GetPMTQualityScoreFilterSetDetails @message = @message output
	
	If @myError <> 0
		Goto Done
		
	-----------------------------------------------------------
	-- Lookup the value of PMT_Quality_Score_Uses_Filtered_Peptide_Obs_Count
	-----------------------------------------------------------
	Declare @ConfigValue varchar(128)
	Declare @UseFilteredPeptideObsCount tinyint
	
	Set @ConfigValue = '0'
	SELECT @ConfigValue = LTrim(RTrim(Value))
	FROM T_Process_Config
	WHERE [Name] = 'PMT_Quality_Score_Uses_Filtered_Peptide_Obs_Count' AND Len(Value) > 0
	--
	SELECT @myError = @@error, @myRowCount = @@RowCount

	If IsNull(@ConfigValue, 0) = '1'
		Set @UseFilteredPeptideObsCount = 1
	Else
		Set @UseFilteredPeptideObsCount = 0
	
	-----------------------------------------------------------
	-- Define the filter threshold values
	-----------------------------------------------------------
	
	Declare @CriteriaGroupStart int,
			@CriteriaGroupMatch int,
			@SpectrumCountComparison varchar(2),
			@SpectrumCountThreshold int,
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
			@DiscriminantInitialFilterComparison varchar(2),		-- Not used in this SP
			@DiscriminantInitialFilterThreshold float,				-- Not used in this SP
			@ProteinCountComparison varchar(2),
			@ProteinCountThreshold int,
			@TerminusStateComparison varchar(2),
			@TerminusStateThreshold tinyint,
			@XTandemHyperscoreComparison varchar(2),		-- Only used for XTandem results
			@XTandemHyperscoreThreshold real,				-- Only used for XTandem results
			@XTandemLogEValueComparison varchar(2),			-- Only used for XTandem results
			@XTandemLogEValueThreshold real,				-- Only used for XTandem results
			@PeptideProphetComparison varchar(2),
			@PeptideProphetThreshold float,
			@RankScoreComparison varchar(2),				-- Only used for Sequest results
			@RankScoreThreshold smallint					-- Only used for Sequest results

	-----------------------------------------------------------
	-- The following hold the DeltaCn thresholds last used to populate #PeptideStats
	-----------------------------------------------------------
	Declare @PopulatePeptideStats tinyint,
			@SavedResultType varchar(64),
			@SavedDeltaCnComparison varchar(2),
			@SavedDeltaCnThreshold float,
			@SavedDeltaCn2Comparison varchar(2),
			@SavedDeltaCn2Threshold float,
			@SavedRankScoreComparison varchar(2),
			@SavedRankScoreThreshold float,
			@SavedPeptideStatsRowCount int,
			@SavedExperimentFilter varchar(128)

	-- Initialize to impossible values
	Set @SavedResultType = '~~'
	Set @SavedDeltaCnComparison = '~~'
	Set @SavedDeltaCnThreshold = -1
	Set @SavedDeltaCn2Comparison = '~~'
	Set @SavedDeltaCn2Threshold = -1
	Set @SavedRankScoreComparison = '~~'
	Set @SavedRankScoreThreshold = -1
	Set @SavedPeptideStatsRowCount = 0
	Set @SavedExperimentFilter = ''

	-----------------------------------------------------------
	-- Loop through the known ResultTypes
	-----------------------------------------------------------
	Set @ResultTypeID = 0
	--	
	SELECT TOP 1 @ResultType = ResultType, @ResultTypeID = UniqueID
	FROM #T_ResultTypeList
	WHERE UniqueID > @ResultTypeID
	ORDER BY UniqueID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	While Len(IsNull(@ResultType, '')) > 0 And @myError = 0
	Begin -- <a>	
		-----------------------------------------------------------
		-- Loop through the Filter_Set_ID values in #FilterSetDetails
		-----------------------------------------------------------

		Set @UniqueRowID = 0
		Set @Continue = 1
		Set @FilterSetsEvaluated = 0
		
		While @Continue > 0
		Begin -- <b>
			Set @FilterSetID = 0
			
			SELECT TOP 1 @FilterSetID = Filter_Set_ID,
						@FilterSetScore = IsNull(Score_Value, 1),
						@FilterSetExperimentFilter = IsNull(Experiment_Filter, ''),
						@UniqueRowID = Unique_Row_ID
			FROM #FilterSetDetails
			WHERE Unique_Row_ID > @UniqueRowID
			ORDER BY Unique_Row_ID
			--
			SELECT @myError = @@error, @myRowCount = @@RowCount

			If @myRowCount = 0
				Set @Continue = 0
			Else
			Begin -- <c>

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

					-- Invalid filter defined; post message to log, but continue processing
					set @message = 'Filter set ID ' + Convert(varchar(11), @FilterSetID) + ' not found using GetThresholdsForFilterSet'
					SELECT @message
					execute PostLogEntry 'Error', @message, 'ComputePMTQualityScore'
					Set @message = ''
				End
				Else
				Begin -- <d>

					If @ResultTypeID = 1
					Begin
						If Len(@FilterSetList) = 0
							Set @FilterSetList = 'Filter Set Info: '
						Else
							Set @FilterSetList = @FilterSetList + '; '
						
						Set @FilterSetList = @FilterSetList + Convert(varchar(11), @FilterSetID) + ' = ' + Convert(varchar(11), @FilterSetScore)
						
						If Len(@FilterSetExperimentFilter) > 0
							Set @FilterSetList = @FilterSetList + '(' + @FilterSetExperimentFilter + ')'
					End

					-----------------------------------------------------------
					-- Now call GetThresholdsForFilterSet to get the tresholds to filter against
					-- Set PMT_Quality_Score to @FilterSetScore in #NewMassTagScores for the matching mass tags
					-----------------------------------------------------------

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
													@PeptideProphetComparison OUTPUT, @PeptideProphetThreshold OUTPUT,
													@RankScoreComparison OUTPUT, @RankScoreThreshold OUTPUT

					While @CriteriaGroupMatch > 0
					Begin -- <e>

						-- Determine whether we need to populate #PeptideStats
						Set @PopulatePeptideStats = 0
						
						If @ResultType = 'XT_Peptide_Hit'
						Begin
							-- Do not consider DeltaCN or RankScore for XTandem results
							If @SavedResultType <> @ResultType OR
							   @SavedDeltaCn2Comparison <> @DeltaCn2Comparison OR @SavedDeltaCn2Threshold <> @DeltaCn2Threshold OR
							 @SavedExperimentFilter <> @FilterSetExperimentFilter OR
							   @SavedPeptideStatsRowCount = 0
							Set @PopulatePeptideStats = 1
						End
						Else
						Begin
							If @SavedResultType <> @ResultType OR
							   @SavedDeltaCnComparison <> @DeltaCnComparison OR @SavedDeltaCnThreshold <> @DeltaCnThreshold OR
							   @SavedDeltaCn2Comparison <> @DeltaCn2Comparison OR @SavedDeltaCn2Threshold <> @DeltaCn2Threshold OR
							   @SavedRankScoreComparison <> @RankScoreComparison OR @SavedRankScoreThreshold <> @RankScoreThreshold OR
							   @SavedExperimentFilter <> @FilterSetExperimentFilter OR
							   @SavedPeptideStatsRowCount = 0
							Set @PopulatePeptideStats = 1
						End
						
						If @PopulatePeptideStats = 1
						Begin -- <f>
							-----------------------------------------------------------
							-- Make sure #PeptideStats is empty
							-----------------------------------------------------------
							--
							DELETE FROM #PeptideStats
							--
							SELECT @myError = @@error, @myRowCount = @@RowCount

							-----------------------------------------------------------
							-- Populate the #PeptideStats temporary table
							-- Note that ObservationCount is not a unique analysis_id count, but a unique number of times the peptide has been observed
							-- Additionally, this count considers the possiblity that the same dataset may have been analyzed several times with
							--  similar or identical Sequest parameter files
							-- We use the @DeltaCnThreshold and @DeltaCn2Threshold values when populating this table to filter out unwanted peptide observations
							-----------------------------------------------------------
							--

							If @UseFilteredPeptideObsCount = 0
								Set @ObsSql = 'IsNull(MT.Number_Of_Peptides, 0)'
							Else
								Set @ObsSql = 'IsNull(MT.Peptide_Obs_Count_Passing_Filter, 0)'

							Set @Sql = ''
							Set @Sql = @Sql + ' INSERT INTO #PeptideStats ('
							Set @Sql = @Sql +   ' Mass_Tag_ID, PeptideLength, MonoisotopicMass,'
							Set @Sql = @Sql +   ' NETDifferenceAbsolute, ProteinCount, MaxCleavageState, MaxTerminusState,'
							Set @Sql = @Sql +   ' ObservationCount, Charge_State, XCorr_Max, Hyperscore_Max, Log_EValue_Min,'
							Set @Sql = @Sql +   ' Discriminant_Score_Max, Peptide_Prophet_Max'
							Set @Sql = @Sql + ' )'
							Set @Sql = @Sql + ' SELECT	MT.Mass_Tag_ID, '
							Set @Sql = @Sql +   ' LEN(MT.Peptide) AS PeptideLength,'
							Set @Sql = @Sql +   ' IsNull(MT.Monoisotopic_Mass, 0) AS MonoisotopicMass,'
							Set @Sql = @Sql +   ' IsNull(ABS(MTN.Avg_GANET - MTN.PNET), 0) AS NETDifferenceAbsolute,'
							Set @Sql = @Sql +   ' IsNull(MT.Multiple_Proteins, 0) + 1 AS ProteinCount,'
							Set @Sql = @Sql +   ' MAX(ISNULL(MTPM.Cleavage_State, 0)) AS MaxCleavageState,'
							Set @Sql = @Sql +   ' MAX(ISNULL(MTPM.Terminus_State, 0)) AS MaxTerminusState,'
							Set @Sql = @Sql +   ' ' + @ObsSql + ' AS ObservationCount,'
							Set @Sql = @Sql +   ' StatsQ.Charge_State,'
							Set @Sql = @Sql +   ' MAX(StatsQ.XCorr_Max) AS XCorr_Max,'
							Set @Sql = @Sql +   ' MAX(StatsQ.Hyperscore_Max) AS Hyperscore_Max,'
							Set @Sql = @Sql +   ' MIN(StatsQ.Log_EValue_Min) AS Log_EValue_Min,'
							Set @Sql = @Sql +   ' MAX(StatsQ.Discriminant_Score_Max) AS Discriminant_Score_Max,'
							Set @Sql = @Sql +   ' MAX(StatsQ.Peptide_Prophet_Max) AS Peptide_Prophet_Max'
							Set @Sql = @Sql + ' FROM ('
							Set @Sql = @Sql +    ' SELECT Mass_Tag_ID,'
							Set @Sql = @Sql +      ' Charge_State,'
							Set @Sql = @Sql +      ' MAX(SubQ.XCorr_Max) AS XCorr_Max,'
							Set @Sql = @Sql +	   ' MAX(SubQ.Hyperscore_Max) AS Hyperscore_Max,'
							Set @Sql = @Sql +	   ' MIN(SubQ.Log_EValue_Min) AS Log_EValue_Min,'
							Set @Sql = @Sql +      ' MAX(SubQ.Discriminant_Score_Max) AS Discriminant_Score_Max,'
							Set @Sql = @Sql +      ' MAX(SubQ.Peptide_Prophet_Max) AS Peptide_Prophet_Max'
							Set @Sql = @Sql +    ' FROM ('
							
							If @ResultType = 'Peptide_Hit'
							Begin
								Set @Sql = @Sql +      ' SELECT P.Mass_Tag_ID,'
								Set @Sql = @Sql +        ' P.Scan_Number,'
								Set @Sql = @Sql +        ' P.Charge_State,'
								Set @Sql = @Sql +        ' MAX(IsNull(SS.XCorr, 0)) AS XCorr_Max,'
								Set @Sql = @Sql +        ' 0 AS Hyperscore_Max,'
								Set @Sql = @Sql + ' 0 AS Log_EValue_Min,'
								Set @Sql = @Sql +        ' MAX(IsNull(SD.DiscriminantScoreNorm, 0)) As Discriminant_Score_Max,'
								Set @Sql = @Sql +        ' MAX(IsNull(SD.Peptide_Prophet_Probability, 0)) As Peptide_Prophet_Max'
								Set @Sql = @Sql +      ' FROM T_Peptides AS P INNER JOIN T_Analysis_Description AS TAD ON P.Analysis_ID = TAD.Job'
								Set @Sql = @Sql +        ' LEFT OUTER JOIN T_Score_Sequest AS SS ON P.Peptide_ID = SS.Peptide_ID'
								Set @Sql = @Sql +        ' LEFT OUTER JOIN T_Score_Discriminant AS SD ON P.Peptide_ID = SD.Peptide_ID'
								Set @Sql = @Sql +      ' WHERE TAD.ResultType = ''Peptide_Hit'' AND NOT P.Charge_State IS NULL AND'
								Set @Sql = @sql +        ' SS.DeltaCn ' + @DeltaCnComparison + Convert(varchar(11), @DeltaCnThreshold) + ' AND '
								Set @Sql = @sql +        ' SS.DeltaCn2 ' + @DeltaCn2Comparison + Convert(varchar(11), @DeltaCn2Threshold) + ' AND '
								Set @Sql = @sql +        ' SS.RankXc ' + @RankScoreComparison + Convert(varchar(11), @RankScoreThreshold)
								
								If Len(@FilterSetExperimentFilter) > 0
									Set @Sql = @sql +    ' AND TAD.Experiment LIKE (''' + @FilterSetExperimentFilter + ''')'
									
								Set @Sql = @sql +      ' GROUP BY TAD.Dataset_ID,'
								Set @Sql = @sql +        ' P.Mass_Tag_ID,'
								Set @Sql = @sql +        ' P.Scan_Number,'
								Set @Sql = @sql +        ' P.Charge_State'
							End

							If @ResultType = 'XT_Peptide_Hit'
							Begin
								Set @Sql = @Sql +      ' SELECT P.Mass_Tag_ID,'
								Set @Sql = @Sql +        ' P.Scan_Number,'
								Set @Sql = @Sql +        ' P.Charge_State,'
								Set @Sql = @Sql +        ' 0 AS XCorr_Max,'
								Set @Sql = @Sql +        ' MAX(IsNull(X.Hyperscore, 0)) AS Hyperscore_Max,'
								Set @Sql = @Sql +        ' MIN(IsNull(X.Log_EValue, 0)) AS Log_EValue_Min,'
								Set @Sql = @Sql +        ' MAX(IsNull(SD.DiscriminantScoreNorm, 0)) As Discriminant_Score_Max,'
								Set @Sql = @Sql +        ' MAX(IsNull(SD.Peptide_Prophet_Probability, 0)) As Peptide_Prophet_Max'
								Set @Sql = @Sql +      ' FROM T_Peptides AS P INNER JOIN T_Analysis_Description AS TAD ON P.Analysis_ID = TAD.Job'
								Set @Sql = @Sql +        ' LEFT OUTER JOIN T_Score_XTandem AS X ON P.Peptide_ID = X.Peptide_ID'
								Set @Sql = @Sql +        ' LEFT OUTER JOIN T_Score_Discriminant AS SD ON P.Peptide_ID = SD.Peptide_ID'
								Set @Sql = @Sql +      ' WHERE TAD.ResultType = ''XT_Peptide_Hit'' AND NOT P.Charge_State IS NULL AND'
								Set @Sql = @sql +        ' X.DeltaCn2 ' + @DeltaCn2Comparison + Convert(varchar(11), @DeltaCn2Threshold)
								If Len(@FilterSetExperimentFilter) > 0
									Set @Sql = @sql +    ' AND TAD.Experiment LIKE (''' + @FilterSetExperimentFilter + ''')'
									
								Set @Sql = @sql +      ' GROUP BY TAD.Dataset_ID,'
								Set @Sql = @sql +        ' P.Mass_Tag_ID,'
								Set @Sql = @sql +        ' P.Scan_Number,'
								Set @Sql = @sql +        ' P.Charge_State'
							End
														
							Set @Sql = @sql +    ' ) AS SubQ'
							Set @Sql = @sql +    ' GROUP BY Mass_Tag_ID,'
							Set @Sql = @sql +      ' Charge_State'
							Set @Sql = @sql + ' ) AS StatsQ'
  							Set @Sql = @sql +   ' INNER JOIN T_Mass_Tags AS MT ON StatsQ.Mass_Tag_ID = MT.Mass_Tag_ID'
							Set @Sql = @sql +   ' LEFT OUTER JOIN T_Mass_Tag_to_Protein_Map AS MTPM ON MT.Mass_Tag_ID = MTPM.Mass_Tag_ID'
							Set @Sql = @sql +   ' LEFT OUTER JOIN T_Mass_Tags_NET AS MTN ON MT.Mass_Tag_ID = MTN.Mass_Tag_ID'
							Set @Sql = @sql + ' GROUP BY MT.Mass_Tag_ID, '
							Set @Sql = @sql +   ' LEN(MT.Peptide),'
							Set @Sql = @sql +   ' IsNull(MT.Monoisotopic_Mass, 0),'
							Set @Sql = @sql +   ' IsNull(ABS(MTN.Avg_GANET - MTN.PNET), 0),'
							Set @Sql = @sql +   ' IsNull(MT.Multiple_Proteins, 0) + 1,'
							Set @Sql = @sql +   ' ' + @ObsSql + ','
							Set @Sql = @sql +   ' StatsQ.Charge_State'
							Set @Sql = @sql + ' ORDER BY MT.Mass_Tag_ID'

							if @PreviewSql <> 0
								Print @Sql
							else
								Exec sp_executesql @Sql
							--
							SELECT @myError = @@error, @SavedPeptideStatsRowCount = @@RowCount
							--
							If @myError <> 0
							Begin
								Set @Message = 'Error populating #PeptideStats in ComputePMTQualityScore'
								Goto Done
							End

							if DateDiff(second, @lastProgressUpdate, GetDate()) >= @ProgressUpdateIntervalThresholdSeconds
							Begin
								set @message = '...Processing: Populated #PeptideStats for Filter Set ID ' + Convert(varchar(12), @FilterSetID) + ' and Criteria Group ' + convert(varchar(19), @CriteriaGroupMatch)
								execute PostLogEntry 'Progress', @message, 'ComputePMTQualityScore'
								set @message = ''
								set @lastProgressUpdate = GetDate()
							End

							Set @SavedResultType = @ResultType
							Set @SavedDeltaCnComparison = @DeltaCnComparison
							Set @SavedDeltaCnThreshold = @DeltaCnThreshold
							Set @SavedDeltaCn2Comparison = @DeltaCn2Comparison
							Set @SavedDeltaCn2Threshold = @DeltaCn2Threshold
							Set @SavedRankScoreComparison = @RankScoreComparison
							Set @SavedRankScoreThreshold = @RankScoreThreshold
							Set @SavedExperimentFilter = @FilterSetExperimentFilter
							
						End -- </f>


						-----------------------------------------------------------
						-- Update #NewMassTagScores for the entries in #PeptideStats
						-- that pass the thresholds
						-----------------------------------------------------------
						--
						Set @Sql = ''
						Set @Sql = @Sql + ' UPDATE #NewMassTagScores'
						Set @Sql = @Sql + ' SET PMT_Quality_Score = ' + Convert(varchar(11), @FilterSetScore)
						Set @Sql = @Sql + ' FROM ('
						Set @Sql = @Sql +   ' SELECT DISTINCT Mass_Tag_ID'
						Set @Sql = @Sql +   ' FROM #PeptideStats'
						Set @Sql = @Sql +   ' WHERE  Charge_State ' +  @ChargeStateComparison +      Convert(varchar(11), @ChargeStateThreshold) + ' AND '
						Set @Sql = @sql +          ' ObservationCount ' + @SpectrumCountComparison + Convert(varchar(11), @SpectrumCountThreshold) + ' AND '
						
						If @ResultType = 'Peptide_Hit'
							Set @Sql = @Sql + ' XCorr_Max ' +  @HighNormalizedScoreComparison +  Convert(varchar(11), @HighNormalizedScoreThreshold) + ' AND '
							
						If @ResultType = 'XT_Peptide_Hit'
						Begin
							Set @Sql = @Sql +      ' Hyperscore_Max ' +  @XTandemHyperscoreComparison +  Convert(varchar(11), @XTandemHyperscoreThreshold) + ' AND '
							Set @Sql = @Sql +      ' Log_EValue_Min ' +  @XTandemLogEValueComparison +  Convert(varchar(11), @XTandemLogEValueThreshold) + ' AND '
						End
						
						Set @Sql = @Sql +          ' MaxCleavageState ' + @CleavageStateComparison + Convert(varchar(11), @CleavageStateThreshold) + ' AND '
						Set @Sql = @Sql +          ' MaxTerminusState ' + @TerminusStateComparison + Convert(varchar(11), @TerminusStateThreshold) + ' AND '
						Set @Sql = @Sql +		   ' PeptideLength ' + @PeptideLengthComparison +    Convert(varchar(11), @PeptideLengthThreshold) + ' AND '
						Set @Sql = @Sql +		   ' MonoisotopicMass ' + @MassComparison +          Convert(varchar(11), @MassThreshold) + ' AND '
						Set @Sql = @sql +          ' Discriminant_Score_Max ' + @DiscriminantScoreComparison +  Convert(varchar(11), @DiscriminantScoreThreshold) + ' AND '
						Set @Sql = @sql +          ' Peptide_Prophet_Max ' + @PeptideProphetComparison +        Convert(varchar(11), @PeptideProphetThreshold) + ' AND '
						Set @Sql = @sql +          ' NETDifferenceAbsolute ' + @NETDifferenceAbsoluteComparison + Convert(varchar(11), @NETDifferenceAbsoluteThreshold) + ' AND '
						Set @Sql = @sql +          ' ProteinCount ' + @ProteinCountComparison +      Convert(varchar(11), @ProteinCountThreshold)
						Set @Sql = @Sql +   ' ) AS CompareQ'
						Set @Sql = @Sql +   ' WHERE #NewMassTagScores.Mass_Tag_ID = CompareQ.Mass_Tag_ID AND '
						Set @Sql = @Sql +     Convert(varchar(11), @FilterSetScore) + ' > PMT_Quality_Score'

						-- Execute the Sql to update the PMT_Quality_Score column
						if @PreviewSql <> 0
							Print @Sql
						else
							Exec sp_executesql @Sql
						--
						SELECT @myError = @@error, @myRowCount = @@RowCount
						--
						Set @RowCountTotalEvaluated = @RowCountTotalEvaluated + @myRowCount
						
						if DateDiff(second, @lastProgressUpdate, GetDate()) >= @ProgressUpdateIntervalThresholdSeconds
						Begin
							set @message = '...Processing: populated PMT_Quality_Score in #NewMassTagScores (' + Convert(varchar(12), @RowCountTotalEvaluated) + ' total rows updated)'
							execute PostLogEntry 'Progress', @message, 'ComputePMTQualityScore'
							set @message = ''
							set @lastProgressUpdate = GetDate()
						End


						-----------------------------------------------------------
						-- Lookup the next set of filters
						-----------------------------------------------------------
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
														@XTandemLogEValueComparison OUTPUT, @XTandemLogEValueThreshold OUTPUT,
														@PeptideProphetComparison OUTPUT, @PeptideProphetThreshold OUTPUT,
														@RankScoreComparison OUTPUT, @RankScoreThreshold OUTPUT

						If @myError <> 0
						Begin
							Set @Message = 'Error retrieving next entry from GetThresholdsForFilterSet in CheckFilterForAvailableAnalyses'
							Goto Done
						End


					End -- </e>
				
					Set @FilterSetsEvaluated = @FilterSetsEvaluated + 1
				
				End -- </d>
			
			End -- </c>
		End -- </b>

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
									
	End -- </a>
	
	-----------------------------------------------------------
	-- Raise a warning if no valid Filter Sets were found
	-----------------------------------------------------------

	If @FilterSetsEvaluated < 1
		Set @WarningMessage = 'Warning: No valid Filter Sets were found'


	-----------------------------------------------------------
	-- Calculate some stats
	-----------------------------------------------------------
	
	If @PreviewSql = 0
	Begin
		SELECT @MassTagCountNonZero = COUNT(Mass_Tag_ID)
		FROM #NewMassTagScores
		WHERE PMT_Quality_Score > 0

		SELECT @MassTagCountZero = COUNT(Mass_Tag_ID)
		FROM #NewMassTagScores
		WHERE PMT_Quality_Score <=0
	End
		
	If @InfoOnly <> 0
	Begin
		If @PreviewSql <> 0
			Set @message = 'Preview of SQL for updating PMT_Quality_Score values'
		Else
			Set @message = 'Preview of update to PMT_Quality_Score values: '
	End
	Else
	Begin

		-----------------------------------------------------------
		-- Store the newly computed scores
		-----------------------------------------------------------
		
		UPDATE T_Mass_Tags
		SET PMT_Quality_Score = #NewMassTagScores.PMT_Quality_Score
		FROM #NewMassTagScores
		WHERE T_Mass_Tags.Mass_Tag_ID = #NewMassTagScores.Mass_Tag_ID
		--
		SELECT @myError = @@error, @myRowCount = @@RowCount
		--
		If @myError <> 0
		Begin
			Set @Message = 'Error updating PMT_Quality_Scores in T_Mass_Tags'
			Goto Done
		End
		--
		Set @message = 'Updated PMT_Quality_Score values: '
		

		-----------------------------------------------------------
		-- Make sure none of the mass tags have a null PMT Quality Score value
		-- Due to the Internal_Standard_Only = 0 restriction used when
		-- populating #NewMassTagScores, this will only be true for
		-- PMTs with Internal_Standard_Only <> 0
		-----------------------------------------------------------
		UPDATE T_Mass_Tags
		SET PMT_Quality_Score = 0
		WHERE PMT_Quality_Score Is Null
		--
		SELECT @myError = @@error, @myRowCount = @@RowCount

		-----------------------------------------------------------
		-- Invalidate any cached histograms with Mode 4 = PMT Quality Score
		--  or with PMT_Quality_Score_Minimum defined
		-----------------------------------------------------------
		Exec UpdateCachedHistograms @HistogramModeFilter = 4, @InvalidateButDoNotProcess=1
		
	End
	
	If @PreviewSql = 0
	Begin
		Set @message = @message + convert(varchar(11), @MassTagCountNonZero) + ' mass tags have scores > 0; '
		Set @message = @message + convert(varchar(11), @MassTagCountZero) + ' mass tags have scores <= 0'
	End
	Set @message = @message + '; ' + @FilterSetList
	
	If Len(@WarningMessage) > 0
		Set @message = @message + ' (' + @WarningMessage + ')'

	-- Echo message to console	
	SELECT @message

	-----------------------------------------------
	-- Post @message to the log
	-----------------------------------------------
	If @InfoOnly = 0
		EXEC PostLogEntry 'Normal', @message, 'ComputePMTQualityScore'

Done:	
	If @InfoOnly = 0 And @myError <> 0
		EXEC PostLogEntry 'Error', @message, 'ComputePMTQualityScore'


	DROP INDEX #PeptideStats.#IX_PeptideStats
	DROP INDEX #NewMassTagScores.#IX_NewMassTagScores
	
	Return @myError


GO
