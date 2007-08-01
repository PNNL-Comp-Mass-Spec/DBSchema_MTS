/****** Object:  StoredProcedure [dbo].[CheckFilterForAnalysesWork] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.CheckFilterForAnalysesWork
/****************************************************
**
**	Desc: 
**		Tests the peptides in the specified analyses against the given filter set
**
**		The calling procedure must create tables #JobsInBatch and #PeptideFilterResults
**		However, it only needs to populate table #JobsInBatch; this procedure will populate
**		table #PeptideFilterResults using #PeptideFilterStats
**
**			CREATE TABLE #JobsInBatch (
**				Job int
**			)
**
**			CREATE TABLE #PeptideFilterResults (
**				Analysis_ID int NOT NULL ,
**				Peptide_ID int NOT NULL ,
**				Pass_FilterSet tinyint NOT NULL			-- 0 or 1
**			)
**			
**			CREATE UNIQUE INDEX #IX_PeptideFilterResults ON #PeptideFilterResults (Peptide_ID)
**
**
**	Return values: 0 if no error; otherwise error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	06/08/2007
**    
*****************************************************/
(
	@filterSetID int,
	@PreviewSql tinyint=0,
	@message varchar(512)='' OUTPUT
)
AS
	Set NoCount On

	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	set @message = ''

	Declare @ResultType varchar(64)
	Declare @ResultTypeID int

	Declare @Continue tinyint
	
	declare @Sql varchar(4000)


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
			set @message = 'Could not validate filter set ID ' + Convert(varchar(12), @FilterSetID) + ' using GetThresholdsForFilterSet'		
		goto Done
	end
	
	if @CriteriaGroupMatch = 0 
	begin
		set @message = 'Filter set ID ' + Convert(varchar(12), @FilterSetID) + ' not found using GetThresholdsForFilterSet'
		set @myError = 51100
		goto Done
	end


	-----------------------------------------------------------
	-- Set up the Peptide stats table
	-----------------------------------------------------------

	-- Create a temporary table to store the peptides for the jobs to process
	CREATE TABLE #PeptideStats (
		Analysis_ID int NOT NULL ,
		Peptide_ID int NOT NULL ,
		PeptideLength smallint NOT NULL,
		Charge_State smallint NOT NULL,
		XCorr float NOT NULL,							-- Only used for Sequest data
		Hyperscore real NOT NULL,						-- Only used for XTandem data
		Log_EValue real NOT NULL,						-- Only used for XTandem data
		Cleavage_State tinyint NOT NULL,
		Terminus_State tinyint NOT NULL,
		Mass float NOT NULL,
		DeltaCn float NOT NULL,							-- Only used for Sequest data
		DeltaCn2 float NOT NULL,
		Discriminant_Score real NOT NULL,
		NET_Difference_Absolute float NOT NULL,
		PassFilt int NOT NULL,							-- aka Discriminant_Initial_Filter; Always 1 for XTandem data
		Pass_FilterSet_Group tinyint NOT NULL			-- 0 or 1
	)
	
	CREATE UNIQUE INDEX #IX_PeptideStats ON #PeptideStats ([Peptide_ID])

	-----------------------------------------------
	-- Populate a temporary table with the list of Result_Types defined for the jobs in #JobsInBatch
	-----------------------------------------------
	CREATE TABLE #JobResultTypes (
		UniqueID int IDENTITY(1,1),
		ResultType varchar(64)
	)
	
	INSERT INTO #JobResultTypes (ResultType)
	SELECT DISTINCT TAD.ResultType
	FROM T_Analysis_Description TAD INNER JOIN
		 #JobsInBatch ON TAD.Job = #JobsInBatch.Job


	-----------------------------------------------
	-- Clear #PeptideFilterResults
	-----------------------------------------------
	--
	DELETE FROM #PeptideFilterResults
	
	Set @ResultTypeID = 0
	Set @Continue = 1
	
	While @Continue = 1
	Begin -- <a>
		SELECT TOP 1 
				@ResultType = ResultType,
				@ResultTypeID = UniqueID
		FROM #JobResultTypes
		WHERE UniqueID > @ResultTypeID
		ORDER BY UniqueID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0
		begin
			set @message = 'Could not get next @ResultType from #JobResultTypes'
			set @myError = 55000
			goto Done
		end

		If @myRowCount = 0
			Set @Continue = 0
		Else
		Begin -- <b>

			TRUNCATE TABLE #PeptideStats
			
			-----------------------------------------------
			-- Populate the PeptideStats temporary table using #JobsInBatch with ResultType @ResultType
			-- Initially set @myError to a non-zero value in case @ResultType is invalid for this SP
			-- Note that this error code is used below so update in both places if changing
			-----------------------------------------------
			
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
						FROM #JobsInBatch INNER JOIN
							 T_Analysis_Description TAD ON #JobsInBatch.Job = TAD.Job AND TAD.ResultType = @ResultType INNER JOIN
							 T_Peptides P ON #JobsInBatch.Job = P.Analysis_ID INNER JOIN 
							 T_Score_Sequest S ON P.Peptide_ID = S.Peptide_ID INNER JOIN 
							 T_Score_Discriminant SD ON P.Peptide_ID = SD.Peptide_ID INNER JOIN 
							 T_Peptide_to_Protein_Map PP ON P.Peptide_ID = PP.Peptide_ID INNER JOIN 
							 T_Sequence TS ON P.Seq_ID = TS.Seq_ID
					) LookupQ
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
						FROM #JobsInBatch INNER JOIN
							 T_Analysis_Description TAD ON #JobsInBatch.Job = TAD.Job AND TAD.ResultType = @ResultType INNER JOIN
							 T_Peptides P ON #JobsInBatch.Job = P.Analysis_ID INNER JOIN 
							 T_Score_XTandem X ON P.Peptide_ID = X.Peptide_ID INNER JOIN 
							 T_Score_Discriminant SD ON P.Peptide_ID = SD.Peptide_ID INNER JOIN 
							 T_Peptide_to_Protein_Map PP ON P.Peptide_ID = PP.Peptide_ID INNER JOIN 
							 T_Sequence TS ON P.Seq_ID = TS.Seq_ID
					) LookupQ
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
					set @message = 'Error populating #PeptideStats in CheckFilterForAnalysesWork; Invalid ResultType ''' + @ResultType + ''''
				Else
					set @message = 'Error populating #PeptideStats in CheckFilterForAnalysesWork'
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
			Begin -- <c>

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
				If @PreviewSql <> 0
					Print @sql
				Else
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
					Set @Message = 'Error retrieving next entry from GetThresholdsForFilterSet in CheckFilterForAnalysesWork'
					Goto Done
				End

			End -- </c>
		
			-----------------------------------------------
			-- Populate #PeptideFilterResults with the results
			-----------------------------------------------
			--
			INSERT INTO #PeptideFilterResults (Analysis_ID, Peptide_ID, Pass_FilterSet)
			SELECT Analysis_ID, Peptide_ID, Pass_FilterSet_Group
			FROM #PeptideStats
			--
			SELECT @myError = @@error, @myRowCount = @@RowCount
			
		End -- </b>
	End -- </a>
	
	
Done:
	Return @myError


GO
GRANT EXECUTE ON [dbo].[CheckFilterForAnalysesWork] TO [DMS_SP_User]
GO
