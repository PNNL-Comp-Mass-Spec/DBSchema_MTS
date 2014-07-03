/****** Object:  StoredProcedure [dbo].[ComputePMTQualityScore] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure ComputePMTQualityScore
/****************************************************	
**	Populates the PMT_Quality_Score column in T_Mass Tags by examining
**   the highest normalized score value for each mass tag, the number
**   of MS/MS analyses the peptide was observed in, and several other metrics
**
**	Auth:	mem
**	Date:	01/07/2004
**			01/13/2004 mem - added @ResetScoresToZero parameter
**			01/22/2004 mem - Moved Exec (@S) to be between the Begin/End pair constructing @S
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
**			10/16/2007 mem - Added support for an instrument class filter in T_Process_Config
**						   - Now also populating T_PMT_QS_Job_Usage with the Job Numbers considered for each filter set tested
**			04/07/2008 mem - Now optionally updating PMT_Quality_Score_Local in T_Peptides
**			11/05/2008 mem - Added support for Inspect results (type IN_Peptide_Hit)
**			07/22/2009 mem - Added support for Inspect_PValue filtering
**						   - Added parameters @PopulatePMTQSJobUsage, @DebugMode, and, @PeptideIDMax
**			11/12/2010 klc - Added support for MSGF_SpecProb filtering
**			12/04/2010 mem - Now displaying additional MT count info in the status message
**			10/03/2011 mem - Added support for MSGFDB results (type MSG_Peptide_Hit)
**			01/06/2012 mem - Updated to use T_Peptides.Job
**			12/05/2012 mem - Added support for MSAlign (type MSA_Peptide_Hit)
**			05/07/2013 mem - Renamed @MSGFDbFDR variables to @MSGFPlusQValue
**							 Added support for filtering on MSGF+ PepQValue
**			06/18/2013 mem - Fixed bug that was trying to access non-existent column RankSpecProb in table T_Score_MSAlign
**
****************************************************/
(
	@message varchar(512)='' Output,
	@InfoOnly tinyint = 0,
	@ResetScoresToZero tinyint = 1,				-- By default, will reset all of the PMT_Quality_Scores to 0 before applying the above filter; set to 0 to not reset the scores
	@ComputePMTQualityScoreLocal tinyint = 0,
	@PopulatePMTQSJobUsage tinyint = 1,
	@DebugMode tinyint = 0,						-- When non-zero, then the first 100,000 rows of #PeptideStats are displayed and the contents of #NewMassTagScores are displayed
	@PeptideIDMax int = 0,						-- Useful for debugging
	@PreviewSql tinyint = 0
)
As
	Set NoCount On

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Declare @FilterSetText varchar(256),
			@FilterSetID int,
			@FilterSetScore float,
			@FilterSetExperimentFilter varchar(128),
			@FilterSetInstrumentClassFilter varchar(128),
			@FilterSetInfoID int

	Declare @MassTagCountNonZero int = 0,
			@MassTagCountZero int = 0,
			@MassTagCount1 int = 0,
			@MassTagCount2 int = 0,
			@MassTagCount3 int = 0,			
			@UniqueRowID int,
			@Continue int,
			@TestThresholds int
	
	Declare @FilterSetsEvaluated int
	Set @FilterSetsEvaluated = 0
	
	Declare @RowCountTotalEvaluated int
	Set @RowCountTotalEvaluated = 0

	Declare @WarningMessage varchar(75),
			@S nvarchar(max),
			@ObsSql varchar(64),
			@FilterSetList varchar(512)
	
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

	Set @ResetScoresToZero = IsNull(@ResetScoresToZero, 1)
	Set @ComputePMTQualityScoreLocal = IsNull(@ComputePMTQualityScoreLocal, 0)

	Set @PopulatePMTQSJobUsage = IsNull(@PopulatePMTQSJobUsage, 1)
	Set @DebugMode = IsNull(@DebugMode, 0)

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
		
	INSERT INTO #T_ResultTypeList (ResultType)
	SELECT ResultType
	FROM dbo.tblPeptideHitResultTypes()


	-----------------------------------------------------------
	-- Create a temporary table to store the new PMT Quality Score values
	-- Necessary if @InfoOnly = 1, and also useful to reduce the total additions to the database's transaction log
	-----------------------------------------------------------

	CREATE TABLE #NewMassTagScores (
		Mass_Tag_ID int NOT NULL,
		PMT_Quality_Score float NOT NULL
	)

	CREATE UNIQUE INDEX #IX_NewMassTagScores ON #NewMassTagScores (Mass_Tag_ID ASC)
	
	If @PreviewSql = 0
	Begin
		If @ResetScoresToZero <> 0
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

		If @ResetScoresToZero <> 0
		Begin
			UPDATE T_Peptides
			SET PMT_Quality_Score_Local = 0
			WHERE IsNull(PMT_Quality_Score_Local, 1) > 0
		End
	End
		 
	-----------------------------------------------------------
	-- Create the Peptide Stats temporary table
	-- This table keeps track of stats at the mass tag level (one row per unique sequence)
	-----------------------------------------------------------

	if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#PeptideStats]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		truncate table [dbo].[#PeptideStats]
	else
	Begin
		CREATE TABLE #PeptideStats (
			Mass_Tag_ID int NOT NULL,
			PeptideLength smallint NOT NULL,
			MonoisotopicMass float NOT NULL,
			NETDifferenceAbsolute real NOT NULL,
			ProteinCount int NOT NULL,
			MaxCleavageState tinyint NOT NULL,
			MaxTerminusState tinyint NOT NULL,
			ObservationCount int NOT NULL,			-- Total number of observations for given Mass Tag for all charge states
			Charge_State smallint NOT NULL,
			XCorr_Max float NOT NULL,				-- Only used for Sequest data
			Hyperscore_Max real NOT NULL,			-- Only used for X!Tandem data
			Log_EValue_Min real NOT NULL,			-- Only used for X!Tandem data
			MQScore_Max real NOT NULL,				-- Only used for Inspect data
			TotalPRMScore_Max real NOT NULL,		-- Only used for Inspect data
			FScore_Max real NOT NULL,				-- Only used for Inspect data
			PValue_Min real NOT NULL,				-- Only used for Inspect data
			MSGFDB_SpecProb_Min float NOT NULL,		-- Only used for MSGFDB data
			MSGFDB_PValue_Min float NOT NULL, 		-- Only used for MSGFDB data
			MSGFPlus_QValue_Min float NOT NULL,		-- Only used for MSGF+ data
			MSGFPlus_PepQValue_Min float NOT NULL,	-- Only used for MGSF+ data
			MSAlign_PValue_Min float NOT NULL,		-- Only used for MSAlign data
			MSAlign_FDR_Min float NOT NULL,			-- Only used for MSAlign data
			Discriminant_Score_Max float NOT NULL,
			Peptide_Prophet_Max float NOT NULL,
			MSGF_SpecProb_Min float NOT NULL			-- Used for Sequest, X!Tandem, Inspect, or MSGF_DB results; ignored for MSAlign
		)
		
		CREATE UNIQUE INDEX #IX_PeptideStats ON #PeptideStats (Mass_Tag_ID, Charge_State)
	End

	-----------------------------------------------------------
	-- Create the temporary tables that tracks the analysis jobs analyzed for each filter set definition
	-----------------------------------------------------------

	CREATE TABLE #TmpPMTQSJobUsageFilterInfo (
		Filter_Set_Info_ID_Local int Identity(1,1),
		Filter_Set_Info varchar(256) NOT NULL,
		Filter_Set_ID int NOT NULL, 
		PMT_Quality_Score int NOT NULL,
		Filter_Set_Info_ID int NULL
	)

	CREATE TABLE #TmpPMTQSJobUsage (
		Filter_Set_Info_ID_Local int NOT NULL,
		Job int NOT NULL
	)

	-----------------------------------------------------------
	-- Create the temporary table to hold the Filter Sets to test
	-----------------------------------------------------------

	CREATE TABLE #FilterSetDetails (
		Filter_Set_Text varchar(256),
		Filter_Set_ID int NULL,
		Score_Value real NULL,
		Experiment_Filter varchar(128) NULL,
		Instrument_Class_Filter varchar(128) NULL,
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
			@RankScoreComparison varchar(2),				-- Used for Sequest and Inspect results (T_Score_Sequest.RankXC and T_Score_Inspect.RankFScore); ignored for X!Tandem
			@RankScoreThreshold smallint,
			@InspectMQScoreComparison varchar(2),			-- Only used for Inspect results
			@InspectMQScoreThreshold real,
			@InspectTotalPRMScoreComparison varchar(2),		-- Only used for Inspect results
			@InspectTotalPRMScoreThreshold real,
			@InspectFScoreComparison varchar(2),			-- Only used for Inspect results
			@InspectFScoreThreshold real,
			@InspectPValueComparison varchar(2),			-- Only used for Inspect results
			@InspectPValueThreshold real,
						
			@MSGFSpecProbComparison varchar(2),				-- Used for Sequest, X!Tandem, or Inspect results; Ignored for MSAlign
			@MSGFSpecProbThreshold real,

			@MSGFDbSpecProbComparison varchar(2),			-- Only used for MSGFDB results
			@MSGFDbSpecProbThreshold real,
			@MSGFDbPValueComparison varchar(2),				-- Only used for MSGFDB results
			@MSGFDbPValueThreshold real,

			@MSGFPlusQValueComparison varchar(2),			-- Only used for MSGF+ results (was FDR for MSGFDB)
			@MSGFPlusQValueThreshold real, 				
			@MSGFPlusPepQValueComparison varchar(2),		-- Only used for MSGF+ results (was PepFDR for MSGFDB)
			@MSGFPlusPepQValueThreshold real, 

			@MSAlignPValueComparison varchar(2),			-- Used by MSAlign
			@MSAlignPValueThreshold real,			
			@MSAlignFDRComparison varchar(2),				-- Used by MSAlign
			@MSAlignFDRThreshold real
			
	-----------------------------------------------------------
	-- The following hold the DeltaCn thresholds last used to populate #PeptideStats
	-----------------------------------------------------------
	Declare @PopulatePeptideStats int,
			@SavedResultType varchar(64),
			@SavedDeltaCnComparison varchar(2),
			@SavedDeltaCnThreshold float,
			@SavedDeltaCn2Comparison varchar(2),
			@SavedDeltaCn2Threshold float,
			@SavedRankScoreComparison varchar(2),
			@SavedRankScoreThreshold smallint,
			@SavedPeptideStatsRowCount int,
			@SavedExperimentFilter varchar(128),
			@SavedInstrumentClassFilter varchar(128)

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
			
			SELECT TOP 1 @FilterSetText = Filter_Set_Text,
						 @FilterSetID = Filter_Set_ID,
						 @FilterSetScore = IsNull(Score_Value, 1),
						 @FilterSetExperimentFilter = IsNull(Experiment_Filter, ''),
						 @FilterSetInstrumentClassFilter = IsNull(Instrument_Class_Filter, ''),
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
							Set @FilterSetList = @FilterSetList + ' (' + @FilterSetExperimentFilter + ')'

						If Len(@FilterSetInstrumentClassFilter) > 0
							Set @FilterSetList = @FilterSetList + ' (' + @FilterSetInstrumentClassFilter + ')'

					End

					-----------------------------------------------------------
					-- Add the filter set info to #TmpPMTQSJobUsageFilterInfo
					-----------------------------------------------------------
					
					INSERT INTO #TmpPMTQSJobUsageFilterInfo (Filter_Set_Info, Filter_Set_ID, PMT_Quality_Score)
					VALUES (@FilterSetText, @FilterSetID, @FilterSetScore)
					--
					SELECT @myError = @@error, @myRowCount = @@RowCount, @FilterSetInfoID = SCOPE_IDENTITY()

					If @PreviewSql <> 0
						Print ' '
						
					-----------------------------------------------------------
					-- Append #TmpPMTQSJobUsage with the jobs that will be analyzed for this filter set
					-----------------------------------------------------------
					--
					Set @S = ''
					Set @S = @S + ' INSERT INTO #TmpPMTQSJobUsage (Filter_Set_Info_ID_Local, Job)'
					Set @S = @S + ' SELECT ' + Convert(varchar(12), @FilterSetInfoID) + ', Job'
					Set @S = @S + ' FROM T_Analysis_Description AS TAD'
					Set @S = @S + ' WHERE TAD.ResultType = ''' + @ResultType + ''''
					
					If Len(@FilterSetExperimentFilter) > 0
						Set @S = @S +    ' AND TAD.Experiment LIKE (''' + @FilterSetExperimentFilter + ''')'
					
					If Len(@FilterSetInstrumentClassFilter) > 0
						Set @S = @S +    ' AND TAD.Instrument_Class LIKE (''' + @FilterSetInstrumentClassFilter + ''')'
						
					-- Execute the Sql to populate #TmpPMTQSJobUsage
					if @PreviewSql <> 0
						Print @S
					
					Exec sp_executesql @S
					--
					SELECT @myError = @@error, @myRowCount = @@RowCount
					--
		
					-----------------------------------------------------------
					-- Now call GetThresholdsForFilterSet to get the tresholds to filter against
					-- Set PMT_Quality_Score to @FilterSetScore in #NewMassTagScores for the matching mass tags
					-----------------------------------------------------------

					Set @CriteriaGroupStart = 0
					Set @TestThresholds = 1
					
					While @TestThresholds = 1
					Begin -- <e>
					
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
											@MSGFPlusQValueComparison = @MSGFPlusQValueComparison OUTPUT, @MSGFPlusQValueThreshold = @MSGFPlusQValueThreshold OUTPUT,
											@MSGFPlusPepQValueComparison = @MSGFPlusPepQValueComparison OUTPUT, @MSGFPlusPepQValueThreshold = @MSGFPlusPepQValueThreshold OUTPUT,
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
						Begin -- <f>

							-- Determine whether we need to populate #PeptideStats
							Set @PopulatePeptideStats = -1
							
							If @ResultType = 'Peptide_Hit'					
							Begin
								-- Sequest results
								If @SavedResultType <> @ResultType OR
									@SavedDeltaCnComparison <> @DeltaCnComparison OR @SavedDeltaCnThreshold <> @DeltaCnThreshold OR
									@SavedDeltaCn2Comparison <> @DeltaCn2Comparison OR @SavedDeltaCn2Threshold <> @DeltaCn2Threshold OR
									@SavedRankScoreComparison <> @RankScoreComparison OR @SavedRankScoreThreshold <> @RankScoreThreshold OR
									@SavedExperimentFilter <> @FilterSetExperimentFilter OR
									@SavedInstrumentClassFilter <> @FilterSetInstrumentClassFilter OR
									(@PreviewSql = 0 AND @SavedPeptideStatsRowCount = 0)
									Set @PopulatePeptideStats = 1
								Else
									Set @PopulatePeptideStats = 0
							End
							
							If @ResultType = 'XT_Peptide_Hit'
							Begin
								-- X!Tandem results
								-- Do not consider DeltaCN or RankScore
								If @SavedResultType <> @ResultType OR
									@SavedDeltaCn2Comparison <> @DeltaCn2Comparison OR @SavedDeltaCn2Threshold <> @DeltaCn2Threshold OR
									@SavedExperimentFilter <> @FilterSetExperimentFilter OR
									@SavedInstrumentClassFilter <> @FilterSetInstrumentClassFilter OR
									(@PreviewSql = 0 AND @SavedPeptideStatsRowCount = 0)
									Set @PopulatePeptideStats = 1
								Else
									Set @PopulatePeptideStats = 0
							End							

							If @ResultType = 'IN_Peptide_Hit'
							Begin
								-- Inspect results
								-- Do not consider DeltaCN
								If @SavedResultType <> @ResultType OR
									@SavedDeltaCn2Comparison <> @DeltaCn2Comparison OR @SavedDeltaCn2Threshold <> @DeltaCn2Threshold OR
									@SavedRankScoreComparison <> @RankScoreComparison OR @SavedRankScoreThreshold <> @RankScoreThreshold OR
									@SavedExperimentFilter <> @FilterSetExperimentFilter OR
									@SavedInstrumentClassFilter <> @FilterSetInstrumentClassFilter OR
									(@PreviewSql = 0 AND @SavedPeptideStatsRowCount = 0)
									Set @PopulatePeptideStats = 1
								Else
									Set @PopulatePeptideStats = 0
							End

							If @ResultType IN ('MSG_Peptide_Hit', 'MSA_Peptide_Hit')
							Begin
								-- MSGF-DB or MSAlign results
								-- Do not consider DeltaCN or DeltaCn2
								If @SavedResultType <> @ResultType OR
									@SavedRankScoreComparison <> @RankScoreComparison OR @SavedRankScoreThreshold <> @RankScoreThreshold OR
									@SavedExperimentFilter <> @FilterSetExperimentFilter OR
									@SavedInstrumentClassFilter <> @FilterSetInstrumentClassFilter OR
									(@PreviewSql = 0 AND @SavedPeptideStatsRowCount = 0)
									Set @PopulatePeptideStats = 1
								Else
									Set @PopulatePeptideStats = 0
							End

							If @PopulatePeptideStats = -1
							Begin
								-- Unknown value for @ResultType
								Set @message = '@ResultType contains an unsupported value: ' + @ResultType + '; unable to continue'
								Set @myError = 52000
								Goto Done
							End
							
							If @PopulatePeptideStats = 1
							Begin -- <g1>
								-----------------------------------------------------------
								-- Make sure #PeptideStats is empty
								-----------------------------------------------------------
								--
								DELETE FROM #PeptideStats
								--
								SELECT @myError = @@error, @myRowCount = @@RowCount

								-----------------------------------------------------------
								-- Populate the #PeptideStats temporary table
								-- Note that ObservationCount is not a unique Job count, but a unique number of times the peptide has been observed
								-- Additionally, this count considers the possiblity that the same dataset may have been analyzed several times with
								--  similar or identical Sequest parameter files
								-- We use the @DeltaCnThreshold and @DeltaCn2Threshold values when populating this table to filter out unwanted peptide observations
								-----------------------------------------------------------
								--

								If @UseFilteredPeptideObsCount = 0
									Set @ObsSql = 'IsNull(MT.Number_Of_Peptides, 0)'
								Else
									Set @ObsSql = 'IsNull(MT.Peptide_Obs_Count_Passing_Filter, 0)'

								Set @S = ''
								Set @S = @S + ' INSERT INTO #PeptideStats ('
								Set @S = @S +   ' Mass_Tag_ID, PeptideLength, MonoisotopicMass,'
								Set @S = @S +   ' NETDifferenceAbsolute, ProteinCount, MaxCleavageState, MaxTerminusState,'
								Set @S = @S +   ' ObservationCount, Charge_State, XCorr_Max, Hyperscore_Max, Log_EValue_Min,'
								Set @S = @S +   ' MQScore_Max, TotalPRMScore_Max, FScore_Max, PValue_Min,'
								Set @S = @S +   ' MSGFDB_SpecProb_Min, MSGFDB_PValue_Min, MSGFPlus_QValue_Min, MSGFPlus_PepQValue_Min,'
								Set @S = @S +   ' MSAlign_PValue_Min, MSAlign_FDR_Min,'
								Set @S = @S +   ' Discriminant_Score_Max, Peptide_Prophet_Max, MSGF_SpecProb_Min'
								Set @S = @S + ' )'
								Set @S = @S + ' SELECT	MT.Mass_Tag_ID, '
								Set @S = @S +   ' LEN(MT.Peptide) AS PeptideLength,'
								Set @S = @S +   ' IsNull(MT.Monoisotopic_Mass, 0) AS MonoisotopicMass,'
								Set @S = @S +   ' IsNull(ABS(MTN.Avg_GANET - MTN.PNET), 0) AS NETDifferenceAbsolute,'
								Set @S = @S +   ' IsNull(MT.Multiple_Proteins, 0) + 1 AS ProteinCount,'
								Set @S = @S +   ' MAX(ISNULL(MTPM.Cleavage_State, 0)) AS MaxCleavageState,'
								Set @S = @S +   ' MAX(ISNULL(MTPM.Terminus_State, 0)) AS MaxTerminusState,'
								Set @S = @S +   ' ' + @ObsSql + ' AS ObservationCount,'
								Set @S = @S +   ' StatsQ.Charge_State,'
								Set @S = @S +   ' MAX(StatsQ.XCorr_Max) AS XCorr_Max,'								
												-- X!Tandem Scores
								Set @S = @S +   ' MAX(StatsQ.Hyperscore_Max) AS Hyperscore_Max,'
								Set @S = @S +   ' MIN(StatsQ.Log_EValue_Min) AS Log_EValue_Min,'								
												-- Inspect Scores
								Set @S = @S +   ' MAX(StatsQ.MQScore_Max) AS MQScore_Max,'
								Set @S = @S +   ' MAX(StatsQ.TotalPRMScore_Max) AS TotalPRMScore_Max,'
								Set @S = @S +   ' MAX(StatsQ.FScore_Max) AS FScore_Max,'
								Set @S = @S +   ' MIN(StatsQ.PValue_Min) AS PValue_Min,'								
												-- MSGFDB Scores
								Set @S = @S +   ' MIN(StatsQ.MSGFDB_SpecProb_Min) AS MSGFDB_SpecProb_Min,'
								Set @S = @S +   ' MIN(StatsQ.MSGFDB_PValue_Min) AS MSGFDB_PValue_Min,'
								Set @S = @S +   ' MIN(StatsQ.MSGFPlus_QValue_Min) AS MSGFPlus_QValue_Min,'
								Set @S = @S +   ' MIN(StatsQ.MSGFPlus_PepQValue_Min) AS MSGFPlus_PepQValue_Min,'
												-- MSAlign Scores
								Set @S = @S +   ' MIN(StatsQ.MSAlign_PValue_Min) AS MSAlign_PValue_Min,'
								Set @S = @S +   ' MIN(StatsQ.MSAlign_FDR_Min) AS MSAlign_FDR_Min,'
												-- Discriminant, Peptide Prophet, and MSGF
								Set @S = @S +   ' MAX(StatsQ.Discriminant_Score_Max) AS Discriminant_Score_Max,'
								Set @S = @S +   ' MAX(StatsQ.Peptide_Prophet_Max) AS Peptide_Prophet_Max,'
								Set @S = @S +   ' MIN(StatsQ.MSGF_SpecProb) AS MSGF_SpecProb'
								
								Set @S = @S + ' FROM ('
								Set @S = @S +    ' SELECT Mass_Tag_ID,'
								Set @S = @S +   ' Charge_State,'
								Set @S = @S +      ' MAX(SubQ.XCorr_Max) AS XCorr_Max,'
													-- X!Tandem Scores
								Set @S = @S +	   ' MAX(SubQ.Hyperscore_Max) AS Hyperscore_Max,'
								Set @S = @S +	   ' MIN(SubQ.Log_EValue_Min) AS Log_EValue_Min,'
													-- Inspect Scores
								Set @S = @S +      ' MAX(SubQ.MQScore_Max) AS MQScore_Max,'
								Set @S = @S +      ' MAX(SubQ.TotalPRMScore_Max) AS TotalPRMScore_Max,'
								Set @S = @S +      ' MAX(SubQ.FScore_Max) AS FScore_Max,'
								Set @S = @S +      ' MIN(SubQ.PValue_Min) AS PValue_Min,'	
													-- MSGFDB Scores
								Set @S = @S +      ' MIN(SubQ.MSGFDB_SpecProb_Min) AS MSGFDB_SpecProb_Min,'	
								Set @S = @S +      ' MIN(SubQ.MSGFDB_PValue_Min) AS MSGFDB_PValue_Min,'	
								Set @S = @S +      ' MIN(SubQ.MSGFPlus_QValue_Min) AS MSGFPlus_QValue_Min,'	
								Set @S = @S +      ' MIN(SubQ.MSGFPlus_PepQValue_Min) AS MSGFPlus_PepQValue_Min,'	
													-- MSAlign Scores
								Set @S = @S +      ' MIN(SubQ.MSAlign_PValue_Min) AS MSAlign_PValue_Min,'	
								Set @S = @S +      ' MIN(SubQ.MSAlign_FDR_Min) AS MSAlign_FDR_Min,'	
													-- Discriminant, Peptide Prophet, and MSGF	
								Set @S = @S +      ' MAX(SubQ.Discriminant_Score_Max) AS Discriminant_Score_Max,'
								Set @S = @S +      ' MAX(SubQ.Peptide_Prophet_Max) AS Peptide_Prophet_Max,'
								Set @S = @S +      ' MIN(SubQ.MSGF_SpecProb) AS MSGF_SpecProb'
								
								Set @S = @S +  ' FROM ('
								Set @S = @S +          ' SELECT P.Mass_Tag_ID,'
								Set @S = @S +            ' P.Scan_Number,'
								Set @S = @S +            ' P.Charge_State,'
								
								If @ResultType = 'Peptide_Hit'
								Begin -- <h1>
									-- Sequest
									Set @S = @S +        ' MAX(IsNull(SS.XCorr, 0)) AS XCorr_Max,'
									Set @S = @S +        ' 0 AS Hyperscore_Max,'
									Set @S = @S +        ' 0 AS Log_EValue_Min,'
									Set @S = @S +        ' 0 AS MQScore_Max,'
									Set @S = @S +        ' 0 AS TotalPRMScore_Max,'
									Set @S = @S +        ' 0 AS FScore_Max,'
									Set @S = @S +        ' 1 AS PValue_Min,'
									Set @S = @S +        ' 1 AS MSGFDB_SpecProb_Min,'
									Set @S = @S +        ' 1 AS MSGFDB_PValue_Min,'
									Set @S = @S +        ' 1 AS MSGFPlus_QValue_Min,'
									Set @S = @S +        ' 1 AS MSGFPlus_PepQValue_Min,'
									Set @S = @S +        ' 1 AS MSAlign_PValue_Min,'
									Set @S = @S +        ' 1 AS MSAlign_FDR_Min,'	
									Set @S = @S +        ' MAX(IsNull(SD.DiscriminantScoreNorm, 0)) As Discriminant_Score_Max,'
									Set @S = @S +        ' MAX(IsNull(SD.Peptide_Prophet_Probability, 0)) As Peptide_Prophet_Max,'
									Set @S = @S +        ' MIN(IsNull(SD.MSGF_SpecProb, 1)) As MSGF_SpecProb'
									Set @S = @S +      ' FROM T_Peptides AS P INNER JOIN T_Analysis_Description AS TAD ON P.Job = TAD.Job'
									Set @S = @S +        ' LEFT OUTER JOIN T_Score_Sequest AS SS ON P.Peptide_ID = SS.Peptide_ID'
									Set @S = @S +        ' LEFT OUTER JOIN T_Score_Discriminant AS SD ON P.Peptide_ID = SD.Peptide_ID'
									Set @S = @S +      ' WHERE TAD.ResultType = ''Peptide_Hit'' AND NOT P.Charge_State IS NULL AND'
									Set @S = @S +        ' SS.DeltaCn ' + @DeltaCnComparison + Convert(varchar(11), @DeltaCnThreshold) + ' AND '
									Set @S = @S +        ' SS.DeltaCn2 ' + @DeltaCn2Comparison + Convert(varchar(11), @DeltaCn2Threshold) + ' AND '
									Set @S = @S +        ' SS.RankXc ' + @RankScoreComparison + Convert(varchar(11), @RankScoreThreshold)
								End -- </h1>

								If @ResultType = 'XT_Peptide_Hit'
								Begin -- <h2>
									-- X!Tandem
									Set @S = @S +        ' 0 AS XCorr_Max,'
									Set @S = @S +        ' MAX(IsNull(X.Hyperscore, 0)) AS Hyperscore_Max,'
									Set @S = @S +        ' MIN(IsNull(X.Log_EValue, 0)) AS Log_EValue_Min,'
									Set @S = @S +        ' 0 AS MQScore_Max,'
									Set @S = @S +        ' 0 AS TotalPRMScore_Max,'
									Set @S = @S +        ' 0 AS FScore_Max,'
									Set @S = @S +        ' 1 AS PValue_Min,'
									Set @S = @S +        ' 1 AS MSGFDB_SpecProb_Min,'
									Set @S = @S +        ' 1 AS MSGFDB_PValue_Min,'
									Set @S = @S +        ' 1 AS MSGFPlus_QValue_Min,'
									Set @S = @S +        ' 1 AS MSGFPlus_PepQValue_Min,'
									Set @S = @S +        ' 1 AS MSAlign_PValue_Min,'
									Set @S = @S +        ' 1 AS MSAlign_FDR_Min,'	
									Set @S = @S +        ' MAX(IsNull(SD.DiscriminantScoreNorm, 0)) As Discriminant_Score_Max,'
									Set @S = @S +        ' MAX(IsNull(SD.Peptide_Prophet_Probability, 0)) As Peptide_Prophet_Max,'
									Set @S = @S +        ' MIN(IsNull(SD.MSGF_SpecProb, 1)) As MSGF_SpecProb'
									Set @S = @S +      ' FROM T_Peptides AS P INNER JOIN T_Analysis_Description AS TAD ON P.Job = TAD.Job'
									Set @S = @S +    ' LEFT OUTER JOIN T_Score_XTandem AS X ON P.Peptide_ID = X.Peptide_ID'
									Set @S = @S +        ' LEFT OUTER JOIN T_Score_Discriminant AS SD ON P.Peptide_ID = SD.Peptide_ID'
									Set @S = @S +      ' WHERE TAD.ResultType = ''XT_Peptide_Hit'' AND NOT P.Charge_State IS NULL AND'
									Set @S = @S +        ' X.DeltaCn2 ' + @DeltaCn2Comparison + Convert(varchar(11), @DeltaCn2Threshold)
								End -- </h2>

								If @ResultType = 'IN_Peptide_Hit'
								Begin -- <h3>
									-- Inspect
									Set @S = @S +        ' 0 AS XCorr_Max,'
									Set @S = @S +        ' 0 AS Hyperscore_Max,'
									Set @S = @S +        ' 0 AS Log_EValue_Min,'
									Set @S = @S +        ' MAX(IsNull(I.MQScore, 0)) AS MQScore_Max,'
									Set @S = @S +        ' MAX(IsNull(I.TotalPRMScore, 0)) AS TotalPRMScore_Max,'
									Set @S = @S +        ' MAX(IsNull(I.FScore, 0)) AS FScore_Max,'
									Set @S = @S +        ' MIN(IsNull(I.PValue, 1)) AS PValue_Min,'
									Set @S = @S +        ' 1 AS MSGFDB_SpecProb_Min,'
									Set @S = @S +        ' 1 AS MSGFDB_PValue_Min,'
									Set @S = @S +        ' 1 AS MSGFPlus_QValue_Min,'
									Set @S = @S +        ' 1 AS MSGFPlus_PepQValue_Min,'
									Set @S = @S +        ' 1 AS MSAlign_PValue_Min,'
									Set @S = @S +        ' 1 AS MSAlign_FDR_Min,'	
									Set @S = @S +        ' MAX(IsNull(SD.DiscriminantScoreNorm, 0)) As Discriminant_Score_Max,'
									Set @S = @S +        ' MAX(IsNull(SD.Peptide_Prophet_Probability, 0)) As Peptide_Prophet_Max,'
									Set @S = @S +        ' MIN(IsNull(SD.MSGF_SpecProb, 1)) As MSGF_SpecProb'
									Set @S = @S +      ' FROM T_Peptides AS P INNER JOIN T_Analysis_Description AS TAD ON P.Job = TAD.Job'
									Set @S = @S +        ' LEFT OUTER JOIN T_Score_Inspect AS I ON P.Peptide_ID = I.Peptide_ID'
									Set @S = @S +        ' LEFT OUTER JOIN T_Score_Discriminant AS SD ON P.Peptide_ID = SD.Peptide_ID'
									Set @S = @S +      ' WHERE TAD.ResultType = ''IN_Peptide_Hit'' AND NOT P.Charge_State IS NULL AND'
									Set @S = @S +        ' I.DeltaNormTotalPRMScore ' + @DeltaCn2Comparison + Convert(varchar(11), @DeltaCn2Threshold) + ' AND '
									Set @S = @S +        ' I.RankFScore ' + @RankScoreComparison + Convert(varchar(11), @RankScoreThreshold)
								End -- </h3>

								If @ResultType = 'MSG_Peptide_Hit'
								Begin -- <h4>
									-- MSGFDB
									Set @S = @S +        ' 0 AS XCorr_Max,'
									Set @S = @S +        ' 0 AS Hyperscore_Max,'
									Set @S = @S +        ' 0 AS Log_EValue_Min,'
									Set @S = @S +        ' 0 AS MQScore_Max,'
									Set @S = @S +        ' 0 AS TotalPRMScore_Max,'
									Set @S = @S +        ' 0 AS FScore_Max,'
									Set @S = @S +        ' 1 AS PValue_Min,'																		
									Set @S = @S +        ' MIN(IsNull(M.SpecProb, 1)) AS MSGFDB_SpecProb_Min,'
									Set @S = @S +        ' MIN(IsNull(M.PValue, 1)) AS MSGFDB_PValue_Min,'
									Set @S = @S +        ' MIN(IsNull(M.FDR, 1)) AS MSGFPlus_QValue_Min,'
									Set @S = @S +    ' MIN(IsNull(M.PepFDR, 1)) AS MSGFPlus_PepQValue_Min,'
									Set @S = @S +        ' 1 AS MSAlign_PValue_Min,'
									Set @S = @S +        ' 1 AS MSAlign_FDR_Min,'	
									Set @S = @S +        ' MAX(IsNull(SD.DiscriminantScoreNorm, 0)) As Discriminant_Score_Max,'
									Set @S = @S +        ' MAX(IsNull(SD.Peptide_Prophet_Probability, 0)) As Peptide_Prophet_Max,'
									Set @S = @S +        ' MIN(IsNull(SD.MSGF_SpecProb, 1)) As MSGF_SpecProb'
									Set @S = @S +      ' FROM T_Peptides AS P INNER JOIN T_Analysis_Description AS TAD ON P.Job = TAD.Job'
									Set @S = @S +        ' LEFT OUTER JOIN T_Score_MSGFDB AS M ON P.Peptide_ID = M.Peptide_ID'
									Set @S = @S +        ' LEFT OUTER JOIN T_Score_Discriminant AS SD ON P.Peptide_ID = SD.Peptide_ID'
									Set @S = @S +      ' WHERE TAD.ResultType = ''MSG_Peptide_Hit'' AND NOT P.Charge_State IS NULL AND'
									Set @S = @S +        ' M.RankSpecProb ' + @RankScoreComparison + Convert(varchar(11), @RankScoreThreshold)
								End -- </h4>

								If @ResultType = 'MSA_Peptide_Hit'
								Begin -- <h5>
									-- MSAlign
									Set @S = @S +        ' 0 AS XCorr_Max,'
									Set @S = @S +        ' 0 AS Hyperscore_Max,'
									Set @S = @S +        ' 0 AS Log_EValue_Min,'
									Set @S = @S +        ' 0 AS MQScore_Max,'
									Set @S = @S +        ' 0 AS TotalPRMScore_Max,'
									Set @S = @S +        ' 0 AS FScore_Max,'
									Set @S = @S +        ' 1 AS PValue_Min,'
									Set @S = @S +        ' 1 AS MSGFDB_SpecProb_Min,'
									Set @S = @S +        ' 1 AS MSGFDB_PValue_Min,'
									Set @S = @S +        ' 1 AS MSGFPlus_QValue_Min,'
									Set @S = @S +        ' 1 AS MSGFPlus_PepQValue_Min,'
									Set @S = @S +        ' MIN(IsNull(M.PValue, 1)) AS MSAlign_PValue_Min,'
									Set @S = @S +        ' MIN(IsNull(M.FDR, 1)) AS MSAlign_FDR_Min,'																		
									Set @S = @S +        ' MAX(IsNull(SD.DiscriminantScoreNorm, 0)) As Discriminant_Score_Max,'
									Set @S = @S +        ' MAX(IsNull(SD.Peptide_Prophet_Probability, 0)) As Peptide_Prophet_Max,'
									Set @S = @S +        ' MIN(IsNull(SD.MSGF_SpecProb, 1)) As MSGF_SpecProb'
									Set @S = @S +      ' FROM T_Peptides AS P INNER JOIN T_Analysis_Description AS TAD ON P.Job = TAD.Job'
									Set @S = @S +        ' LEFT OUTER JOIN T_Score_MSAlign AS M ON P.Peptide_ID = M.Peptide_ID'
									Set @S = @S +        ' LEFT OUTER JOIN T_Score_Discriminant AS SD ON P.Peptide_ID = SD.Peptide_ID'
									Set @S = @S +      ' WHERE TAD.ResultType = ''MSA_Peptide_Hit'' AND NOT P.Charge_State IS NULL AND'
									Set @S = @S +        ' P.RankHit ' + @RankScoreComparison + Convert(varchar(11), @RankScoreThreshold)
								End -- </h5>
																
								If Len(@FilterSetExperimentFilter) > 0
									Set @S = @S +        ' AND TAD.Experiment LIKE (''' + @FilterSetExperimentFilter + ''')'
								
								If Len(@FilterSetInstrumentClassFilter) > 0
									Set @S = @S +        ' AND TAD.Instrument_Class LIKE (''' + @FilterSetInstrumentClassFilter + ''')'
								
								If @PeptideIDMax <> 0
									Set @S = @S +        ' AND P.Peptide_ID <= ' + Convert(varchar(19), @PeptideIDMax)
								
								Set @S = @S +          ' GROUP BY TAD.Dataset_ID,'
								Set @S = @S +            ' P.Mass_Tag_ID,'
								Set @S = @S +            ' P.Scan_Number,'
								Set @S = @S +            ' P.Charge_State'
								
								Set @S = @S +    ' ) AS SubQ'
								Set @S = @S +    ' GROUP BY Mass_Tag_ID,'
								Set @S = @S +      ' Charge_State'
								Set @S = @S + ' ) AS StatsQ'
  								Set @S = @S +   ' INNER JOIN T_Mass_Tags AS MT ON StatsQ.Mass_Tag_ID = MT.Mass_Tag_ID'
								Set @S = @S +     ' LEFT OUTER JOIN T_Mass_Tag_to_Protein_Map AS MTPM ON MT.Mass_Tag_ID = MTPM.Mass_Tag_ID'
								Set @S = @S +     ' LEFT OUTER JOIN T_Mass_Tags_NET AS MTN ON MT.Mass_Tag_ID = MTN.Mass_Tag_ID'
								Set @S = @S + ' GROUP BY MT.Mass_Tag_ID, '
								Set @S = @S +   ' LEN(MT.Peptide),'
								Set @S = @S +   ' IsNull(MT.Monoisotopic_Mass, 0),'
								Set @S = @S +   ' IsNull(ABS(MTN.Avg_GANET - MTN.PNET), 0),'
								Set @S = @S +   ' IsNull(MT.Multiple_Proteins, 0) + 1,'
								Set @S = @S +   ' ' + @ObsSql + ','
								Set @S = @S +   ' StatsQ.Charge_State'
								Set @S = @S + ' ORDER BY MT.Mass_Tag_ID'

								if @PreviewSql <> 0
									Print @S
								else
									Exec sp_executesql @S
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

								If @PreviewSql = 0 And @DebugMode <> 0
									SELECT TOP 100000 *
									FROM #PeptideStats
									ORDER BY Mass_Tag_ID

									
								Set @SavedResultType = @ResultType
								Set @SavedDeltaCnComparison = @DeltaCnComparison
								Set @SavedDeltaCnThreshold = @DeltaCnThreshold
								Set @SavedDeltaCn2Comparison = @DeltaCn2Comparison
								Set @SavedDeltaCn2Threshold = @DeltaCn2Threshold
								Set @SavedRankScoreComparison = @RankScoreComparison
								Set @SavedRankScoreThreshold = @RankScoreThreshold
								Set @SavedExperimentFilter = @FilterSetExperimentFilter
								Set @SavedInstrumentClassFilter = @FilterSetInstrumentClassFilter
						
							End -- </g1>


							-----------------------------------------------------------
							-- Update #NewMassTagScores for the entries in #PeptideStats
							-- that pass the thresholds
							-----------------------------------------------------------
							--
							Set @S = ''
							Set @S = @S + ' UPDATE #NewMassTagScores'
							Set @S = @S + ' SET PMT_Quality_Score = ' + Convert(varchar(11), @FilterSetScore)
							Set @S = @S + ' FROM ('
							Set @S = @S +   ' SELECT DISTINCT Mass_Tag_ID'
							Set @S = @S +   ' FROM #PeptideStats'
							Set @S = @S +   ' WHERE  Charge_State ' +  @ChargeStateComparison +      Convert(varchar(11), @ChargeStateThreshold) + ' AND '
							Set @S = @S +          ' ObservationCount ' + @SpectrumCountComparison + Convert(varchar(11), @SpectrumCountThreshold) + ' AND '
							
							If @ResultType = 'Peptide_Hit'
								Set @S = @S + ' XCorr_Max ' +  @HighNormalizedScoreComparison +  Convert(varchar(11), @HighNormalizedScoreThreshold) + ' AND '
								
							If @ResultType = 'XT_Peptide_Hit'
							Begin
								Set @S = @S +      ' Hyperscore_Max ' +  @XTandemHyperscoreComparison +  Convert(varchar(11), @XTandemHyperscoreThreshold) + ' AND '
								Set @S = @S +      ' Log_EValue_Min ' +  @XTandemLogEValueComparison +  Convert(varchar(11), @XTandemLogEValueThreshold) + ' AND '
							End

							If @ResultType = 'IN_Peptide_Hit'
							Begin
								Set @S = @S +      ' MQScore_Max ' +  @InspectMQScoreComparison + Convert(varchar(11), @InspectMQScoreThreshold) + ' AND '
								Set @S = @S +      ' TotalPRMScore_Max ' + @InspectTotalPRMScoreComparison + Convert(varchar(11), @InspectTotalPRMScoreThreshold) + ' AND '
								Set @S = @S +      ' FScore_Max ' +  @InspectFScoreComparison + Convert(varchar(11), @InspectFScoreThreshold) + ' AND '
								Set @S = @S +      ' PValue_Min ' +  @InspectPValueComparison + Convert(varchar(11), @InspectPValueThreshold) + ' AND '
							End
														
							If @ResultType = 'MSG_Peptide_Hit'
							Begin
								Set @S = @S +      ' MSGFDB_SpecProb_Min ' +  @MSGFDbSpecProbComparison + Convert(varchar(11), @MSGFDbSpecProbThreshold) + ' AND '
								Set @S = @S +      ' MSGFDB_PValue_Min ' +  @MSGFDbPValueComparison + Convert(varchar(11), @MSGFDbPValueThreshold) + ' AND '
								Set @S = @S +      ' MSGFPlus_QValue_Min ' +  @MSGFPlusQValueComparison + Convert(varchar(11), @MSGFPlusQValueThreshold) + ' AND '
								Set @S = @S +      ' MSGFPlus_PepQValue_Min ' +  @MSGFPlusPepQValueComparison + Convert(varchar(11), @MSGFPlusPepQValueThreshold) + ' AND '
							End

							If @ResultType = 'MSA_Peptide_Hit'
							Begin
								Set @S = @S +      ' MSAlign_PValue_Min ' +  @MSAlignPValueComparison + Convert(varchar(11), @MSAlignPValueThreshold) + ' AND '
								Set @S = @S +      ' MSAlign_FDR_Min ' +  @MSAlignFDRComparison + Convert(varchar(11), @MSAlignFDRThreshold) + ' AND '
							End
														
							Set @S = @S +          ' MaxCleavageState ' + @CleavageStateComparison + Convert(varchar(11), @CleavageStateThreshold) + ' AND '
							Set @S = @S +          ' MaxTerminusState ' + @TerminusStateComparison + Convert(varchar(11), @TerminusStateThreshold) + ' AND '
							Set @S = @S +		   ' PeptideLength ' + @PeptideLengthComparison +  Convert(varchar(11), @PeptideLengthThreshold) + ' AND '
							Set @S = @S +		   ' MonoisotopicMass ' + @MassComparison +          Convert(varchar(11), @MassThreshold) + ' AND '
							Set @S = @S +          ' Discriminant_Score_Max ' + @DiscriminantScoreComparison +    Convert(varchar(11), @DiscriminantScoreThreshold) + ' AND '
							Set @S = @S +          ' Peptide_Prophet_Max ' + @PeptideProphetComparison +          Convert(varchar(11), @PeptideProphetThreshold) + ' AND '
							Set @S = @S +          ' NETDifferenceAbsolute ' + @NETDifferenceAbsoluteComparison + Convert(varchar(11), @NETDifferenceAbsoluteThreshold) + ' AND '
							Set @S = @S +          ' ProteinCount ' + @ProteinCountComparison +      Convert(varchar(11), @ProteinCountThreshold)
							
							If @ResultType <> 'MSA_Peptide_Hit'
								Set @S = @S +          ' AND MSGF_SpecProb_Min ' + @MSGFSpecProbComparison + Convert(varchar(11), @MSGFSpecProbThreshold)
							
							Set @S = @S +   ' ) AS CompareQ'
							Set @S = @S +   ' WHERE #NewMassTagScores.Mass_Tag_ID = CompareQ.Mass_Tag_ID AND '
							Set @S = @S +     ' PMT_Quality_Score < ' + Convert(varchar(11), @FilterSetScore)

							-- Execute the Sql to update the PMT_Quality_Score column
							if @PreviewSql <> 0
								Print @S
							else
								Exec sp_executesql @S
							--
							SELECT @myError = @@error, @myRowCount = @@RowCount
							--
							Set @RowCountTotalEvaluated = @RowCountTotalEvaluated + @myRowCount

							If @PreviewSql = 0 And @DebugMode <> 0
								SELECT PMT_Quality_Score, COUNT(*) as MTCount
								FROM #NewMassTagScores
								GROUP BY PMT_Quality_Score
								ORDER BY PMT_Quality_Score


							If @ComputePMTQualityScoreLocal <> 0
							Begin -- <g2>
								Set @S = ''
								Set @S = @S +   ' UPDATE T_Peptides'
								Set @S = @S +   ' SET PMT_Quality_Score_Local = ' + Convert(varchar(11), @FilterSetScore)
								
								Set @S = @S +	' FROM T_Peptides P INNER JOIN '
								Set @S = @S +	   '(SELECT SubQ.Peptide_ID, '
								Set @S = @S +    ' LEN(MT.Peptide) AS PeptideLength,'
								Set @S = @S +         ' IsNull(MT.Monoisotopic_Mass, 0) AS MonoisotopicMass,'
								Set @S = @S +  ' IsNull(ABS(SubQ.GANET_Obs - MTN.PNET), 0) AS NETDifferenceAbsolute,'
								Set @S = @S +         ' IsNull(MT.Multiple_Proteins, 0) + 1 AS ProteinCount,'
								Set @S = @S +         ' MAX(ISNULL(MTPM.Cleavage_State, 0)) AS MaxCleavageState,'
								Set @S = @S +         ' MAX(ISNULL(MTPM.Terminus_State, 0)) AS MaxTerminusState,'
								Set @S = @S +    ' ' + @ObsSql + ' AS ObservationCount'

								Set @S = @S +      ' FROM T_Mass_Tags AS MT INNER JOIN ('
								Set @S = @S +          ' SELECT P.Peptide_ID,'
								Set @S = @S +            ' P.Mass_Tag_ID,'
								Set @S = @S +            ' P.Scan_Number,'
								Set @S = @S +            ' P.GANET_Obs'
								
								If @ResultType = 'Peptide_Hit'
								Begin -- <h4>
									Set @S = @S +      ' FROM T_Peptides AS P INNER JOIN T_Analysis_Description AS TAD ON P.Job = TAD.Job'
									Set @S = @S +        ' INNER JOIN T_Score_Sequest AS SS ON P.Peptide_ID = SS.Peptide_ID'
									Set @S = @S + ' INNER JOIN T_Score_Discriminant AS SD ON P.Peptide_ID = SD.Peptide_ID'
									Set @S = @S +      ' WHERE TAD.ResultType = ''Peptide_Hit'' AND NOT P.Charge_State IS NULL AND'
									Set @S = @S +        ' P.Charge_State ' +  @ChargeStateComparison + Convert(varchar(11), @ChargeStateThreshold) + ' AND '
									Set @S = @S +        ' SS.DeltaCn ' + @DeltaCnComparison + Convert(varchar(11), @DeltaCnThreshold) + ' AND '
									Set @S = @S +        ' SS.DeltaCn2 ' + @DeltaCn2Comparison + Convert(varchar(11), @DeltaCn2Threshold) + ' AND '
									Set @S = @S +        ' SS.RankXc ' + @RankScoreComparison + Convert(varchar(11), @RankScoreThreshold) + ' AND '
									Set @S = @S +        ' IsNull(SS.XCorr, 0) ' +  @HighNormalizedScoreComparison +  Convert(varchar(11), @HighNormalizedScoreThreshold) + ' AND '
									Set @S = @S +        ' IsNull(SD.DiscriminantScoreNorm, 0) ' + @DiscriminantScoreComparison +  Convert(varchar(11), @DiscriminantScoreThreshold) + ' AND '
									Set @S = @S +        ' IsNull(SD.Peptide_Prophet_Probability, 0) ' + @PeptideProphetComparison + Convert(varchar(11), @PeptideProphetThreshold) + ' AND '
									Set @S = @S +        ' IsNull(SD.MSGF_SpecProb, 1) ' + @MSGFSpecProbComparison + Convert(varchar(11), @MSGFSpecProbThreshold)
								End -- </h4>

								If @ResultType = 'XT_Peptide_Hit'
								Begin -- <h5>
									Set @S = @S +      ' FROM T_Peptides AS P INNER JOIN T_Analysis_Description AS TAD ON P.Job = TAD.Job'
									Set @S = @S +        ' INNER JOIN T_Score_XTandem AS X ON P.Peptide_ID = X.Peptide_ID'
									Set @S = @S +        ' INNER JOIN T_Score_Discriminant AS SD ON P.Peptide_ID = SD.Peptide_ID'
									Set @S = @S +      ' WHERE TAD.ResultType = ''XT_Peptide_Hit'' AND NOT P.Charge_State IS NULL AND'
									Set @S = @S +        ' P.Charge_State ' +  @ChargeStateComparison + Convert(varchar(11), @ChargeStateThreshold) + ' AND '
									Set @S = @S +        ' X.DeltaCn2 ' + @DeltaCn2Comparison + Convert(varchar(11), @DeltaCn2Threshold) + ' AND '
									Set @S = @S +        ' IsNull(X.Hyperscore, 0) ' +  @XTandemHyperscoreComparison +  Convert(varchar(11), @XTandemHyperscoreThreshold) + ' AND '
									Set @S = @S +        ' IsNull(X.Log_EValue, 0) ' +  @XTandemLogEValueComparison +  Convert(varchar(11), @XTandemLogEValueThreshold) + ' AND '
									Set @S = @S +        ' IsNull(SD.DiscriminantScoreNorm, 0) ' + @DiscriminantScoreComparison +  Convert(varchar(11), @DiscriminantScoreThreshold) + ' AND '
									Set @S = @S +        ' IsNull(SD.Peptide_Prophet_Probability, 0) ' + @PeptideProphetComparison + Convert(varchar(11), @PeptideProphetThreshold) + ' AND '
									Set @S = @S +        ' IsNull(SD.MSGF_SpecProb, 1) ' + @MSGFSpecProbComparison + Convert(varchar(11), @MSGFSpecProbThreshold)
								End -- </h5>

								If @ResultType = 'IN_Peptide_Hit'
								Begin -- <h6>
									Set @S = @S +      ' FROM T_Peptides AS P INNER JOIN T_Analysis_Description AS TAD ON P.Job = TAD.Job'
									Set @S = @S +        ' INNER JOIN T_Score_Inspect AS I ON P.Peptide_ID = I.Peptide_ID'
									Set @S = @S +        ' INNER JOIN T_Score_Discriminant AS SD ON P.Peptide_ID = SD.Peptide_ID'
									Set @S = @S + ' WHERE TAD.ResultType = ''IN_Peptide_Hit'' AND NOT P.Charge_State IS NULL AND'
									Set @S = @S +        ' P.Charge_State ' +  @ChargeStateComparison + Convert(varchar(11), @ChargeStateThreshold) + ' AND '
									Set @S = @S +        ' I.DeltaNormTotalPRMScore  ' + @DeltaCn2Comparison + Convert(varchar(11), @DeltaCn2Threshold) + ' AND '
									Set @S = @S +        ' I.RankFScore ' + @RankScoreComparison + Convert(varchar(11), @RankScoreThreshold) + ' AND '
									Set @S = @S +        ' IsNull(I.MQScore, 0) ' +  @InspectMQScoreComparison +  Convert(varchar(11), @InspectMQScoreThreshold) + ' AND '
									Set @S = @S +        ' IsNull(I.TotalPRMScore, 0) ' +  @InspectTotalPRMScoreComparison +  Convert(varchar(11), @InspectTotalPRMScoreThreshold) + ' AND '
									Set @S = @S +        ' IsNull(I.FScore, 0) ' +  @InspectFScoreComparison +  Convert(varchar(11), @InspectFScoreThreshold) + ' AND '
									Set @S = @S +        ' IsNull(I.PValue, 1) ' +  @InspectPValueComparison +  Convert(varchar(11), @InspectPValueThreshold) + ' AND '
									Set @S = @S +        ' IsNull(SD.DiscriminantScoreNorm, 0) ' + @DiscriminantScoreComparison +  Convert(varchar(11), @DiscriminantScoreThreshold) + ' AND '
									Set @S = @S +        ' IsNull(SD.Peptide_Prophet_Probability, 0) ' + @PeptideProphetComparison + Convert(varchar(11), @PeptideProphetThreshold) + ' AND '
									Set @S = @S +        ' IsNull(SD.MSGF_SpecProb, 1) ' + @MSGFSpecProbComparison + Convert(varchar(11), @MSGFSpecProbThreshold)
								End -- </h6>


								If @ResultType = 'MSG_Peptide_Hit'
								Begin -- <h7>
									Set @S = @S +      ' FROM T_Peptides AS P INNER JOIN T_Analysis_Description AS TAD ON P.Job = TAD.Job'
									Set @S = @S +        ' INNER JOIN T_Score_MSGFDB AS M ON P.Peptide_ID = M.Peptide_ID'
									Set @S = @S +        ' INNER JOIN T_Score_Discriminant AS SD ON P.Peptide_ID = SD.Peptide_ID'
									Set @S = @S + ' WHERE TAD.ResultType = ''MSG_Peptide_Hit'' AND NOT P.Charge_State IS NULL AND'
									Set @S = @S +        ' P.Charge_State ' +  @ChargeStateComparison + Convert(varchar(11), @ChargeStateThreshold) + ' AND '
									Set @S = @S +        ' M.RankSpecProb ' + @RankScoreComparison + Convert(varchar(11), @RankScoreThreshold) + ' AND '
									Set @S = @S +        ' IsNull(M.SpecProb, 1) ' +  @MSGFDbSpecProbComparison +  Convert(varchar(11), @MSGFDbSpecProbThreshold) + ' AND '
									Set @S = @S +        ' IsNull(M.PValue, 1) ' +    @MSGFDbPValueComparison +  Convert(varchar(11), @MSGFDbPValueThreshold) + ' AND '
									Set @S = @S +        ' IsNull(M.FDR, 1) ' +       @MSGFPlusQValueComparison +  Convert(varchar(11), @MSGFPlusQValueThreshold) + ' AND '
									Set @S = @S +        ' IsNull(M.PepFDR, 1) ' +    @MSGFPlusPepQValueComparison +  Convert(varchar(11), @MSGFPlusPepQValueThreshold) + ' AND '
									Set @S = @S +        ' IsNull(SD.DiscriminantScoreNorm, 0) ' + @DiscriminantScoreComparison +  Convert(varchar(11), @DiscriminantScoreThreshold) + ' AND '
									Set @S = @S +        ' IsNull(SD.Peptide_Prophet_Probability, 0) ' + @PeptideProphetComparison + Convert(varchar(11), @PeptideProphetThreshold) + ' AND '
									Set @S = @S +        ' IsNull(SD.MSGF_SpecProb, 1) ' + @MSGFSpecProbComparison + Convert(varchar(11), @MSGFSpecProbThreshold)
								End -- </h6>

								If @ResultType = 'MSA_Peptide_Hit'
								Begin -- <h7>
									Set @S = @S +      ' FROM T_Peptides AS P INNER JOIN T_Analysis_Description AS TAD ON P.Job = TAD.Job'
									Set @S = @S +        ' INNER JOIN T_Score_MSAlign AS M ON P.Peptide_ID = M.Peptide_ID'
									Set @S = @S +        ' INNER JOIN T_Score_Discriminant AS SD ON P.Peptide_ID = SD.Peptide_ID'
									Set @S = @S + ' WHERE TAD.ResultType = ''MSA_Peptide_Hit'' AND NOT P.Charge_State IS NULL AND'
									Set @S = @S +        ' P.Charge_State ' +  @ChargeStateComparison + Convert(varchar(11), @ChargeStateThreshold) + ' AND '
									Set @S = @S +        ' IsNull(M.PValue, 1) ' +    @MSAlignPValueComparison +  Convert(varchar(11), @MSAlignPValueThreshold) + ' AND '
									Set @S = @S +        ' IsNull(M.FDR, 1) ' +       @MSAlignFDRComparison +  Convert(varchar(11), @MSAlignFDRThreshold) + ' AND '
									Set @S = @S +        ' IsNull(SD.DiscriminantScoreNorm, 0) ' + @DiscriminantScoreComparison +  Convert(varchar(11), @DiscriminantScoreThreshold) + ' AND '
									Set @S = @S +        ' IsNull(SD.Peptide_Prophet_Probability, 0) ' + @PeptideProphetComparison + Convert(varchar(11), @PeptideProphetThreshold)
									---------------------------------------------
									-- Note: Ignoring MSGF_SpecProb for MSAlign
									-- Set @S = @S +        ' AND IsNull(SD.MSGF_SpecProb, 1) ' + @MSGFSpecProbComparison + Convert(varchar(11), @MSGFSpecProbThreshold)
									---------------------------------------------
								End -- </h7>

								If Len(@FilterSetExperimentFilter) > 0
									Set @S = @S +        ' AND TAD.Experiment LIKE (''' + @FilterSetExperimentFilter + ''')'
								
								If Len(@FilterSetInstrumentClassFilter) > 0
									Set @S = @S +        ' AND TAD.Instrument_Class LIKE (''' + @FilterSetInstrumentClassFilter + ''')'

								If @PeptideIDMax <> 0
									Set @S = @S +        ' AND P.Peptide_ID <= ' + Convert(varchar(19), @PeptideIDMax)
									
								Set @S = @S +         ' ) AS SubQ ON MT.Mass_Tag_ID = SubQ.Mass_Tag_ID'
							
								Set @S = @S +        ' LEFT OUTER JOIN T_Mass_Tag_to_Protein_Map AS MTPM ON MT.Mass_Tag_ID = MTPM.Mass_Tag_ID'
								Set @S = @S +        ' LEFT OUTER JOIN T_Mass_Tags_NET AS MTN ON MT.Mass_Tag_ID = MTN.Mass_Tag_ID'

								Set @S = @S +     ' GROUP BY SubQ.Peptide_ID, '
								Set @S = @S +              ' SubQ.Scan_Number,'
								Set @S = @S +              ' MT.Mass_Tag_ID, '
								Set @S = @S +              ' LEN(MT.Peptide),'
								Set @S = @S +   ' IsNull(MT.Monoisotopic_Mass, 0),'
								Set @S = @S +              ' IsNull(ABS(SubQ.GANET_Obs - MTN.PNET), 0),'
								Set @S = @S +              ' IsNull(MT.Multiple_Proteins, 0) + 1,'
								Set @S = @S +              ' ' + @ObsSql
								
								Set @S = @S +     ' ) AS StatsQ ON StatsQ.Peptide_ID = P.Peptide_ID'

								Set @S = @S +   ' WHERE  StatsQ.ObservationCount ' + @SpectrumCountComparison + Convert(varchar(11), @SpectrumCountThreshold) + ' AND '
								Set @S = @S +          ' StatsQ.MaxCleavageState ' + @CleavageStateComparison + Convert(varchar(11), @CleavageStateThreshold) + ' AND '
								Set @S = @S +          ' StatsQ.MaxTerminusState ' + @TerminusStateComparison + Convert(varchar(11), @TerminusStateThreshold) + ' AND '
								Set @S = @S +		   ' StatsQ.PeptideLength ' + @PeptideLengthComparison +    Convert(varchar(11), @PeptideLengthThreshold) + ' AND '
								Set @S = @S +		   ' StatsQ.MonoisotopicMass ' + @MassComparison +          Convert(varchar(11), @MassThreshold) + ' AND '
								Set @S = @S +          ' StatsQ.NETDifferenceAbsolute ' + @NETDifferenceAbsoluteComparison + Convert(varchar(11), @NETDifferenceAbsoluteThreshold) + ' AND '
								Set @S = @S +          ' StatsQ.ProteinCount ' + @ProteinCountComparison +      Convert(varchar(11), @ProteinCountThreshold) + ' AND '
								Set @S = @S +          ' IsNull(P.PMT_Quality_Score_Local, 0) < ' + Convert(varchar(11), @FilterSetScore)

								-- Execute the Sql to update the PMT_Quality_Score_Local column
								if @PreviewSql <> 0
									Print @S
								else
									Exec sp_executesql @S
								--
								SELECT @myError = @@error, @myRowCount = @@RowCount

							End -- </g2>

							
							if DateDiff(second, @lastProgressUpdate, GetDate()) >= @ProgressUpdateIntervalThresholdSeconds
							Begin
								set @message = '...Processing: populated PMT_Quality_Score in #NewMassTagScores (' + Convert(varchar(12), @RowCountTotalEvaluated) + ' total rows updated)'
								execute PostLogEntry 'Progress', @message, 'ComputePMTQualityScore'
								set @message = ''
								set @lastProgressUpdate = GetDate()
							End
						
						End -- </f>

						-- Increment @CriteriaGroupStart so that we can lookup the next set of filters
						Set @CriteriaGroupStart = @CriteriaGroupMatch + 1
						
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

		SELECT @MassTagCount1 = COUNT(Mass_Tag_ID)
		FROM #NewMassTagScores
		WHERE PMT_Quality_Score = 1

		SELECT @MassTagCount2 = COUNT(Mass_Tag_ID)
		FROM #NewMassTagScores
		WHERE PMT_Quality_Score = 2

		SELECT @MassTagCount3 = COUNT(Mass_Tag_ID)
		FROM #NewMassTagScores
		WHERE PMT_Quality_Score = 3
	End
		
	If @InfoOnly <> 0
	Begin
		If @PreviewSql <> 0
			Set @message = 'Preview of SQL for updating PMT_Quality_Score values'
		Else
			Set @message = 'Preview of update to PMT_Quality_Score values: '

	End
	Else
	Begin -- <p>

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
		--  populating #NewMassTagScores, this will only be true for
		--  PMTs with Internal_Standard_Only <> 0
		-----------------------------------------------------------
		UPDATE T_Mass_Tags
		SET PMT_Quality_Score = 0
		WHERE PMT_Quality_Score Is Null
		--
		SELECT @myError = @@error, @myRowCount = @@RowCount


		If @PopulatePMTQSJobUsage <> 0
		Begin -- <q>

			-----------------------------------------------------------
			-- Populate T_PMT_QS_Job_Usage_Filter_Info and T_PMT_QS_Job_Usage
			-----------------------------------------------------------

			-- Add new values to T_PMT_QS_Job_Usage_Filter_Info, if necessary
			--
			INSERT INTO T_PMT_QS_Job_Usage_Filter_Info( Filter_Set_Info,
			  Filter_Set_ID,
			                                            PMT_Quality_Score )
			SELECT NewInfo.Filter_Set_Info,
			       NewInfo.Filter_Set_ID,
			       NewInfo.PMT_Quality_Score
			FROM ( SELECT Filter_Set_Info,
			              Filter_Set_ID,
			              PMT_Quality_Score,
			              MIN(Filter_Set_Info_ID_Local) AS Filter_Set_Info_ID_Local
			       FROM #TmpPMTQSJobUsageFilterInfo
			       GROUP BY Filter_Set_Info, Filter_Set_ID, PMT_Quality_Score ) NewInfo
			     LEFT OUTER JOIN T_PMT_QS_Job_Usage_Filter_Info StoredInfo
			       ON NewInfo.Filter_Set_Info = StoredInfo.Filter_Set_Info AND
			          NewInfo.Filter_Set_ID = StoredInfo.Filter_Set_ID AND
			          NewInfo.PMT_Quality_Score = StoredInfo.PMT_Quality_Score
			WHERE StoredInfo.Filter_Set_Info_ID IS NULL
			ORDER BY NewInfo.Filter_Set_Info_ID_Local
			--
			SELECT @myError = @@error, @myRowCount = @@RowCount


			-- Populate column Filter_Set_Info_ID in #TmpPMTQSJobUsageFilterInfo
			-- using T_PMT_QS_Job_Usage_Filter_Info
			--
			UPDATE #TmpPMTQSJobUsageFilterInfo
			SET Filter_Set_Info_ID = StoredInfo.Filter_Set_Info_ID
			FROM #TmpPMTQSJobUsageFilterInfo NewInfo
			     INNER JOIN T_PMT_QS_Job_Usage_Filter_Info StoredInfo
			       ON NewInfo.Filter_Set_Info = StoredInfo.Filter_Set_Info AND
			          NewInfo.Filter_Set_ID = StoredInfo.Filter_Set_ID AND
			          NewInfo.PMT_Quality_Score = StoredInfo.PMT_Quality_Score
			--
			SELECT @myError = @@error, @myRowCount = @@RowCount
					
			
			-- Populate T_PMT_QS_Job_Usage, using the official Filter_Set_Info_ID value
			--
			INSERT INTO T_PMT_QS_Job_Usage( Filter_Set_Info_ID, Job )
			SELECT FI.Filter_Set_Info_ID,
			       NewInfo.Job
			FROM #TmpPMTQSJobUsage NewInfo
			     INNER JOIN #TmpPMTQSJobUsageFilterInfo FI
			       ON NewInfo.Filter_Set_Info_ID_Local = FI.Filter_Set_Info_ID_Local
			WHERE NOT FI.Filter_Set_Info IS NULL
			ORDER BY Job, FI.Filter_Set_Info_ID
			--
			SELECT @myError = @@error, @myRowCount = @@RowCount
			
		End -- </q>		
				
		-----------------------------------------------------------
		-- Invalidate any cached histograms with Mode 4 = PMT Quality Score
		--  or with PMT_Quality_Score_Minimum defined
		-----------------------------------------------------------
		Exec UpdateCachedHistograms @HistogramModeFilter = 4, @InvalidateButDoNotProcess=1
		
	End -- </p>

	
	If @PreviewSql = 0
	Begin
		Set @message = @message + convert(varchar(11), @MassTagCountNonZero) + ' AMTs have scores > 0; '
		Set @message = @message + convert(varchar(11), @MassTagCountZero) +    ' AMTs have scores <= 0'
		
		Set @message = @message + '; PMTQS 1 = ' + convert(varchar(11), @MassTagCount1) + ' AMTs'
		Set @message = @message + ', PMTQS 2 = ' + convert(varchar(11), @MassTagCount2) + ' AMTs'
		
		If @MassTagCount3 > 0
			Set @message = @message + ', PMTQS 3 = ' + convert(varchar(11), @MassTagCount3) + ' AMTs'			
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
GRANT VIEW DEFINITION ON [dbo].[ComputePMTQualityScore] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[ComputePMTQualityScore] TO [MTS_DB_Lite] AS [dbo]
GO
