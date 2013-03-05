/****** Object:  StoredProcedure [dbo].[CheckFilterForAnalysesWork] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE CheckFilterForAnalysesWork
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
**				Job int NOT NULL ,
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
**	Date:	06/09/2007
**			10/17/2007 mem - Added support for RankScore (aka RankXc for Sequest)
**			11/03/2008 mem - Added support for Inspect results (type IN_Peptide_Hit)
**			07/21/2009 mem - Added support for Inspect_PValue filtering
**			07/28/2009 mem - Fixed column naming bug
**			08/16/2010 mem - Added support for MSGF_SpecProb filtering
**			10/03/2011 mem - Added column MSGFDB_FDR to #PeptideStats
**			10/13/2011 mem - Fixed bug populating #PeptideStats with MSGFDB results
**			01/06/2012 mem - Updated to use T_Peptides.Job
**			12/05/2012 mem - Added support for MSAlign (type MSA_Peptide_Hit)
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
	Declare @TestThresholds tinyint
	
	declare @S varchar(max)

	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Begin Try

		-----------------------------------------------------------
		-- Define the filter threshold values
		-----------------------------------------------------------
		
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
				@DiscriminantScoreComparison varchar(2),		-- Only accurate for Sequest; approximated for X!Tandem and Inspect; always 0.5 for MSGFDB and MSAlign
				@DiscriminantScoreThreshold float,
				@NETDifferenceAbsoluteComparison varchar(2),
				@NETDifferenceAbsoluteThreshold float,
				@DiscriminantInitialFilterComparison varchar(2),	-- Not used in this SP (only used in PT Databases)
				@DiscriminantInitialFilterThreshold float,
				@ProteinCountComparison varchar(2),					-- Not used in this SP
				@ProteinCountThreshold int,
				@TerminusStateComparison varchar(2),
				@TerminusStateThreshold tinyint,
				@XTandemHyperscoreComparison varchar(2),		-- Only used for X!Tandem results
				@XTandemHyperscoreThreshold real,				
				@XTandemLogEValueComparison varchar(2),			-- Only used for X!Tandem results
				@XTandemLogEValueThreshold real,				
				@PeptideProphetComparison varchar(2),			-- Note, for Inspect data, T_Score_Discriminant.Peptide_Prophet_Probability actually contains "1 minus T_Score_Inspect.PValue"
				@PeptideProphetThreshold float,					
				@RankScoreComparison varchar(2),				-- Used for Sequest, Inspect, MSGFDB, and MSAlign results; ignored for X!Tandem
				@RankScoreThreshold smallint,
				@InspectMQScoreComparison varchar(2),			-- Only used for Inspect results
				@InspectMQScoreThreshold real,
				@InspectTotalPRMScoreComparison varchar(2),		-- Only used for Inspect results
				@InspectTotalPRMScoreThreshold real,
				@InspectFScoreComparison varchar(2),			-- Only used for Inspect results
				@InspectFScoreThreshold real,
				@InspectPValueComparison varchar(2),			-- Only used for Inspect results
				@InspectPValueThreshold real,
				
				@MSGFSpecProbComparison varchar(2),				-- MSGF re-scorer tool
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
			Job int NOT NULL ,
			Peptide_ID int NOT NULL ,
			PeptideLength smallint NOT NULL,
			Charge_State smallint NOT NULL,
			XCorr float NOT NULL,							-- Only used for Sequest data
			RankScore int NOT NULL,							-- Used for Sequest, X!Tandem, MSGFDB, and MSAlign
			
			Hyperscore real NOT NULL,						-- Only used for X!Tandem data
			Log_EValue real NOT NULL,						-- Only used for X!Tandem data
			
			Inspect_MQScore real NOT NULL ,					-- Only used for Inspect data
			Inspect_TotalPRMScore real NOT NULL , 			-- Only used for Inspect data
			Inspect_FScore real NOT NULL ,					-- Only used for Inspect data
			Inspect_PValue real NOT NULL ,					-- Only used for Inspect data
			
			MSGFDB_SpecProb real NOT NULL ,					-- Only used for MSGFDB data
			MSGFDB_PValue real NOT NULL ,					-- Only used for MSGFDB data
			MSGFDB_FDR real NOT NULL ,						-- Only used for MSGFDB data

			MSAlign_PValue real NOT NULL ,					-- Only used for MSAlign data
			MSAlign_FDR real NOT NULL ,						-- Only used for MSAlign data
			
			Cleavage_State tinyint NOT NULL,
			Terminus_State tinyint NOT NULL,
			Mass float NOT NULL,
			DeltaCn float NOT NULL,							-- Only used for Sequest data
			DeltaCn2 float NOT NULL,						-- Used for Sequset, X!Tandem, and Inspect
			Discriminant_Score real NOT NULL,
			Peptide_Prophet_Probability real NOT NULL,		-- Note, for Inspect data, T_Score_Discriminant.Peptide_Prophet_Probability actually contains "1 minus T_Score_Inspect.PValue"; for MSGFDB and MSAlign, this is "1 minus T_Score_MSGFDB.PValue"
			NET_Difference_Absolute float NOT NULL,
			Pass_FilterSet_Group tinyint NOT NULL,			-- 0 or 1
			MSGF_SpecProb real NOT NULL						-- Closer to 0 means higher confidence; ignored for MSAlign
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
					-- Sequest results
					INSERT INTO #PeptideStats (	Job, Peptide_ID, PeptideLength, Charge_State,
												XCorr, RankScore, Hyperscore, Log_EValue, 
												Inspect_MQScore, Inspect_TotalPRMScore, Inspect_FScore, Inspect_PValue,
												MSGFDB_SpecProb, MSGFDB_PValue, MSGFDB_FDR,
												MSAlign_PValue, MSAlign_FDR,
												Cleavage_State, Terminus_State, Mass,
												DeltaCn, DeltaCn2, Discriminant_Score, Peptide_Prophet_Probability,
												MSGF_SpecProb, NET_Difference_Absolute, Pass_FilterSet_Group)
					SELECT  Job, Peptide_ID, PeptideLength, Charge_State,
							XCorr, RankScore, 0 AS Hyperscore, 0 AS Log_EValue, 
							0 AS Inspect_MQScore, 0 AS Inspect_TotalPRMScore, 0 AS Inspect_FScore, 0 AS Inspect_PValue,
							1 AS MSGFDB_SpecProb, 1 AS MSGFDB_PValue, 1 AS MSGFDB_FDR,
							1 AS MSAlign_PValue, 1 AS MSAlign_FDR,
							MAX(Cleavage_State), MAX(Terminus_State), MH, 
							DeltaCN, DeltaCN2, DiscriminantScoreNorm, Peptide_Prophet_Probability, 
							MSGF_SpecProb, NET_Difference_Absolute, 0 AS Pass_FilterSet_Group
					FROM (	SELECT	P.Job, 
									P.Peptide_ID, 
									Len(MT.Peptide) AS PeptideLength, 
									IsNull(P.Charge_State, 0) AS Charge_State,
									IsNull(S.XCorr, 0) AS XCorr, 
									IsNull(S.RankXc, 1) AS RankScore, 
									IsNull(MTPM.Cleavage_State, 0) AS Cleavage_State, 
									IsNull(MTPM.Terminus_State, 0) AS Terminus_State, 
									IsNull(P.MH, 0) AS MH,
									IsNull(S.DeltaCn, 0) AS DeltaCn, 
									IsNull(S.DeltaCn2, 0) AS DeltaCn2, 
									IsNull(SD.DiscriminantScoreNorm, 0) AS DiscriminantScoreNorm,
									IsNull(SD.Peptide_Prophet_Probability, 0) AS Peptide_Prophet_Probability,
									IsNull(SD.MSGF_SpecProb, 1) AS MSGF_SpecProb,
									CASE WHEN IsNull(P.GANET_Obs, 0) = 0 AND IsNull(MTN.PNET, 0) = 0
									     THEN 0
									     ELSE Abs(IsNull(P.GANET_Obs - MTN.PNET, 0))
									END AS NET_Difference_Absolute
							FROM #JobsInBatch INNER JOIN
								 T_Analysis_Description TAD ON #JobsInBatch.Job = TAD.Job AND TAD.ResultType = @ResultType INNER JOIN
								 T_Peptides P ON #JobsInBatch.Job = P.Job INNER JOIN 
								 T_Score_Sequest S ON P.Peptide_ID = S.Peptide_ID INNER JOIN 
								 T_Score_Discriminant SD ON P.Peptide_ID = SD.Peptide_ID INNER JOIN 
								 T_Mass_Tags MT ON P.Mass_Tag_ID = MT.Mass_Tag_ID INNER JOIN
								 T_Mass_Tags_NET MTN ON MT.Mass_Tag_ID = MTN.Mass_Tag_ID INNER JOIN
								 T_Mass_Tag_to_Protein_Map MTPM ON MT.Mass_Tag_ID= MTPM.Mass_Tag_ID
						) LookupQ
					GROUP BY Job, Peptide_ID, PeptideLength, Charge_State,
							 XCorr, RankScore, MH, DeltaCN, DeltaCN2, 
							 DiscriminantScoreNorm, Peptide_Prophet_Probability,
							 MSGF_SpecProb, NET_Difference_Absolute
					ORDER BY Peptide_ID
					--
					SELECT @myError = @@error, @myRowCount = @@RowCount
				End

				If @ResultType = 'XT_Peptide_Hit'
				Begin
					-- X!Tandem results
					INSERT INTO #PeptideStats (	Job, Peptide_ID, PeptideLength, Charge_State,
												XCorr, RankScore, Hyperscore, Log_EValue, 
												Inspect_MQScore, Inspect_TotalPRMScore, Inspect_FScore, Inspect_PValue,
												MSGFDB_SpecProb, MSGFDB_PValue, MSGFDB_FDR,
												MSAlign_PValue, MSAlign_FDR,
												Cleavage_State, Terminus_State, Mass,
												DeltaCn, DeltaCn2, Discriminant_Score, Peptide_Prophet_Probability,
												MSGF_SpecProb, NET_Difference_Absolute, Pass_FilterSet_Group)
					SELECT  Job, Peptide_ID, PeptideLength, Charge_State,
							0 AS XCorr, 1 AS RankScore, Hyperscore, Log_EValue, 
							0 AS Inspect_MQScore, 0 AS Inspect_TotalPRMScore, 0 AS Inspect_FScore, 0 AS Inspect_PValue,
							1 AS MSGFDB_SpecProb, 1 AS MSGFDB_PValue, 1 AS MSGFDB_FDR,
							1 AS MSAlign_PValue, 1 AS MSAlign_FDR,
							Max(Cleavage_State), Max(Terminus_State), MH, 
							0 AS DeltaCN, DeltaCN2, DiscriminantScoreNorm, Peptide_Prophet_Probability,
							MSGF_SpecProb, NET_Difference_Absolute, 0 as Pass_FilterSet_Group
					FROM (	SELECT	P.Job, 
									P.Peptide_ID, 
									Len(MT.Peptide) AS PeptideLength, 
									IsNull(P.Charge_State, 0) AS Charge_State,
									IsNull(X.Hyperscore, 0) AS Hyperscore,
									IsNull(X.Log_EValue, 0) AS Log_EValue,
									IsNull(MTPM.Cleavage_State, 0) AS Cleavage_State, 
									IsNull(MTPM.Terminus_State, 0) AS Terminus_State, 
									IsNull(P.MH, 0) AS MH,
									IsNull(X.DeltaCn2, 0) AS DeltaCn2, 
									IsNull(SD.DiscriminantScoreNorm, 0) AS DiscriminantScoreNorm,
									IsNull(SD.Peptide_Prophet_Probability, 0) AS Peptide_Prophet_Probability,
									IsNull(SD.MSGF_SpecProb, 1) AS MSGF_SpecProb,
									CASE WHEN IsNull(P.GANET_Obs, 0) = 0 AND IsNull(MTN.PNET, 0) = 0
									     THEN 0
									     ELSE Abs(IsNull(P.GANET_Obs - MTN.PNET, 0))
									END AS NET_Difference_Absolute
							FROM #JobsInBatch INNER JOIN
								 T_Analysis_Description TAD ON #JobsInBatch.Job = TAD.Job AND TAD.ResultType = @ResultType INNER JOIN
								 T_Peptides P ON #JobsInBatch.Job = P.Job INNER JOIN 
								 T_Score_XTandem X ON P.Peptide_ID = X.Peptide_ID INNER JOIN 
								 T_Score_Discriminant SD ON P.Peptide_ID = SD.Peptide_ID INNER JOIN 
								 T_Mass_Tags MT ON P.Mass_Tag_ID = MT.Mass_Tag_ID INNER JOIN
								 T_Mass_Tags_NET MTN ON MT.Mass_Tag_ID = MTN.Mass_Tag_ID INNER JOIN
								 T_Mass_Tag_to_Protein_Map MTPM ON MT.Mass_Tag_ID= MTPM.Mass_Tag_ID
						) LookupQ
					GROUP BY Job, Peptide_ID, PeptideLength, Charge_State,
							 Hyperscore, Log_EValue, MH, DeltaCN2, 
							 DiscriminantScoreNorm, Peptide_Prophet_Probability,
							 MSGF_SpecProb, NET_Difference_Absolute
					ORDER BY Peptide_ID
					--
					SELECT @myError = @@error, @myRowCount = @@RowCount
				End

				If @ResultType = 'IN_Peptide_Hit'
				Begin
					-- Inspect results
					INSERT INTO #PeptideStats (	Job, Peptide_ID, PeptideLength, Charge_State,
												XCorr, RankScore, Hyperscore, Log_EValue, 
												Inspect_MQScore, Inspect_TotalPRMScore, Inspect_FScore, Inspect_PValue,
												MSGFDB_SpecProb, MSGFDB_PValue, MSGFDB_FDR,
												MSAlign_PValue, MSAlign_FDR,
												Cleavage_State, Terminus_State, Mass,
												DeltaCn, DeltaCn2, Discriminant_Score, Peptide_Prophet_Probability,
												MSGF_SpecProb, NET_Difference_Absolute, Pass_FilterSet_Group)
					SELECT  Job, Peptide_ID, PeptideLength, Charge_State,
							0 AS XCorr, RankFScore AS RankScore, 0 AS Hyperscore, 0 AS Log_EValue, 
							Inspect_MQScore, Inspect_TotalPRMScore, Inspect_FScore, Inspect_PValue,
							1 AS MSGFDB_SpecProb, 1 AS MSGFDB_PValue, 1 AS MSGFDB_FDR,
							1 AS MSAlign_PValue, 1 AS MSAlign_FDR,
							Max(Cleavage_State), Max(Terminus_State), MH, 
							0 AS DeltaCN, DeltaNormTotalPRMScore AS DeltaCN2, DiscriminantScoreNorm, Peptide_Prophet_Probability,
							MSGF_SpecProb, NET_Difference_Absolute, 0 as Pass_FilterSet_Group
					FROM (	SELECT	P.Job, 
									P.Peptide_ID, 
									Len(MT.Peptide) AS PeptideLength, 
									IsNull(P.Charge_State, 0) AS Charge_State,
									IsNull(I.RankFScore, 0) AS RankFScore,
									IsNull(I.MQScore, 0) AS Inspect_MQScore,
									IsNull(I.TotalPRMScore, 0) AS Inspect_TotalPRMScore,
									IsNull(I.FScore, 0) AS Inspect_FScore,
									IsNull(I.PValue, 1) AS Inspect_PValue,
									IsNull(MTPM.Cleavage_State, 0) AS Cleavage_State, 
									IsNull(MTPM.Terminus_State, 0) AS Terminus_State, 
									IsNull(P.MH, 0) AS MH,
									IsNull(I.DeltaNormTotalPRMScore, 0) AS DeltaNormTotalPRMScore, 
									IsNull(SD.DiscriminantScoreNorm, 0) AS DiscriminantScoreNorm,
									IsNull(SD.Peptide_Prophet_Probability, 0) AS Peptide_Prophet_Probability,
									IsNull(SD.MSGF_SpecProb, 1) AS MSGF_SpecProb,
									CASE WHEN IsNull(P.GANET_Obs, 0) = 0 AND IsNull(MTN.PNET, 0) = 0
									     THEN 0
									     ELSE Abs(IsNull(P.GANET_Obs - MTN.PNET, 0))
									END AS NET_Difference_Absolute
							FROM #JobsInBatch INNER JOIN
									T_Analysis_Description TAD ON #JobsInBatch.Job = TAD.Job AND TAD.ResultType = @ResultType INNER JOIN
									T_Peptides P ON #JobsInBatch.Job = P.Job INNER JOIN 
									T_Score_Inspect I ON P.Peptide_ID = I.Peptide_ID INNER JOIN 
									T_Score_Discriminant SD ON P.Peptide_ID = SD.Peptide_ID INNER JOIN 
									T_Mass_Tags MT ON P.Mass_Tag_ID = MT.Mass_Tag_ID INNER JOIN
									T_Mass_Tags_NET MTN ON MT.Mass_Tag_ID = MTN.Mass_Tag_ID INNER JOIN
									T_Mass_Tag_to_Protein_Map MTPM ON MT.Mass_Tag_ID= MTPM.Mass_Tag_ID
						) LookupQ
					GROUP BY Job, Peptide_ID, PeptideLength, Charge_State,
							 RankFScore, Inspect_MQScore, Inspect_TotalPRMScore, Inspect_FScore, Inspect_PValue, 
							 MH, DeltaNormTotalPRMScore, DiscriminantScoreNorm, Peptide_Prophet_Probability,
							 MSGF_SpecProb, NET_Difference_Absolute
					ORDER BY Peptide_ID
					--
					SELECT @myError = @@error, @myRowCount = @@RowCount
				End
				

				If @ResultType = 'MSG_Peptide_Hit'
				Begin					
					-- MSGFDB results
					INSERT INTO #PeptideStats (	Job, Peptide_ID, PeptideLength, Charge_State,
												XCorr, RankScore, Hyperscore, Log_EValue, 
												Inspect_MQScore, Inspect_TotalPRMScore, Inspect_FScore, Inspect_PValue,
												MSGFDB_SpecProb, MSGFDB_PValue, MSGFDB_FDR,
												MSAlign_PValue, MSAlign_FDR,
												Cleavage_State, Terminus_State, Mass,
												DeltaCn, DeltaCn2, Discriminant_Score, Peptide_Prophet_Probability,
												MSGF_SpecProb, NET_Difference_Absolute, Pass_FilterSet_Group)
					SELECT  Job, Peptide_ID, PeptideLength, Charge_State,
							0 AS XCorr, RankSpecProb AS RankScore, 0 AS Hyperscore, 0 AS Log_EValue, 
							0 AS Inspect_MQScore, 0 AS Inspect_TotalPRMScore, 0 AS Inspect_FScore, 0 AS Inspect_PValue,
							MSGFDB_SpecProb, MSGFDB_PValue, MSGFDB_FDR,
							1 AS MSAlign_PValue, 1 AS MSAlign_FDR,
							Max(Cleavage_State), Max(Terminus_State), MH, 
							0 AS DeltaCN, 1 AS DeltaCN2, 1 AS DiscriminantScoreNorm, Peptide_Prophet_Probability,
							MSGF_SpecProb, NET_Difference_Absolute, 0 as Pass_FilterSet_Group
					FROM (	SELECT	P.Job, 
									P.Peptide_ID, 
									Len(MT.Peptide) AS PeptideLength, 
									IsNull(P.Charge_State, 0) AS Charge_State,
									IsNull(M.RankSpecProb, 1) AS RankSpecProb,
									IsNull(M.SpecProb, 0) AS MSGFDB_SpecProb,
									IsNull(M.PValue, 1) AS MSGFDB_PValue,
									IsNull(M.FDR, 1) AS MSGFDB_FDR,
									IsNull(MTPM.Cleavage_State, 0) AS Cleavage_State, 
									IsNull(MTPM.Terminus_State, 0) AS Terminus_State, 
									IsNull(P.MH, 0) AS MH,
									IsNull(SD.Peptide_Prophet_Probability, 0) AS Peptide_Prophet_Probability,
									IsNull(SD.MSGF_SpecProb, 1) AS MSGF_SpecProb,
									CASE WHEN IsNull(P.GANET_Obs, 0) = 0 AND IsNull(MTN.PNET, 0) = 0
									     THEN 0
									     ELSE Abs(IsNull(P.GANET_Obs - MTN.PNET, 0))
									END AS NET_Difference_Absolute
							FROM #JobsInBatch INNER JOIN
									T_Analysis_Description TAD ON #JobsInBatch.Job = TAD.Job AND TAD.ResultType = @ResultType INNER JOIN
									T_Peptides P ON #JobsInBatch.Job = P.Job INNER JOIN 
									T_Score_MSGFDB M ON P.Peptide_ID = M.Peptide_ID INNER JOIN 
									T_Score_Discriminant SD ON P.Peptide_ID = SD.Peptide_ID INNER JOIN 
									T_Mass_Tags MT ON P.Mass_Tag_ID = MT.Mass_Tag_ID INNER JOIN
									T_Mass_Tags_NET MTN ON MT.Mass_Tag_ID = MTN.Mass_Tag_ID INNER JOIN
									T_Mass_Tag_to_Protein_Map MTPM ON MT.Mass_Tag_ID= MTPM.Mass_Tag_ID
						) LookupQ
					GROUP BY Job, Peptide_ID, PeptideLength, Charge_State,
							 RankSpecProb, MSGFDB_SpecProb, MSGFDB_PValue, MSGFDB_FDR, 
							 MH, Peptide_Prophet_Probability,
							 MSGF_SpecProb, NET_Difference_Absolute
					ORDER BY Peptide_ID
					--
					SELECT @myError = @@error, @myRowCount = @@RowCount
				End

				If @ResultType = 'MSA_Peptide_Hit'
				Begin
					-- MSAlign results
					INSERT INTO #PeptideStats (	Job, Peptide_ID, PeptideLength, Charge_State,
												XCorr, RankScore, Hyperscore, Log_EValue, 
												Inspect_MQScore, Inspect_TotalPRMScore, Inspect_FScore, Inspect_PValue,
												MSGFDB_SpecProb, MSGFDB_PValue, MSGFDB_FDR,
												MSAlign_PValue, MSAlign_FDR,
												Cleavage_State, Terminus_State, Mass,
												DeltaCn, DeltaCn2, Discriminant_Score, Peptide_Prophet_Probability,
												MSGF_SpecProb, NET_Difference_Absolute, Pass_FilterSet_Group)
					SELECT  Job, Peptide_ID, PeptideLength, Charge_State,
							0 AS XCorr, RankScore, 0 AS Hyperscore, 0 AS Log_EValue, 
							0 AS Inspect_MQScore, 0 AS Inspect_TotalPRMScore, 0 AS Inspect_FScore, 0 AS Inspect_PValue,
							1 AS MSGFDB_SpecProb, 1 AS MSGFDB_PValue, 1 AS MSGFDB_FDR,
							MSAlign_PValue, MSAlign_FDR,
							Max(Cleavage_State), Max(Terminus_State), MH, 
							0 AS DeltaCN, 1 AS DeltaCN2, 1 AS DiscriminantScoreNorm, Peptide_Prophet_Probability,
							MSGF_SpecProb, NET_Difference_Absolute, 0 as Pass_FilterSet_Group
					FROM (	SELECT	P.Job, 
									P.Peptide_ID, 
									Len(MT.Peptide) AS PeptideLength, 
									IsNull(P.Charge_State, 0) AS Charge_State,
									IsNull(P.RankHit, 1) AS RankScore,
									IsNull(M.PValue, 1) AS MSAlign_PValue,
									IsNull(M.FDR, 1) AS MSAlign_FDR,
									IsNull(MTPM.Cleavage_State, 0) AS Cleavage_State, 
									IsNull(MTPM.Terminus_State, 0) AS Terminus_State, 
									IsNull(P.MH, 0) AS MH,
									IsNull(SD.Peptide_Prophet_Probability, 0) AS Peptide_Prophet_Probability,
									IsNull(SD.MSGF_SpecProb, 1) AS MSGF_SpecProb,
									CASE WHEN IsNull(P.GANET_Obs, 0) = 0 AND IsNull(MTN.PNET, 0) = 0
									     THEN 0
									     ELSE Abs(IsNull(P.GANET_Obs - MTN.PNET, 0))
									END AS NET_Difference_Absolute
							FROM #JobsInBatch INNER JOIN
									T_Analysis_Description TAD ON #JobsInBatch.Job = TAD.Job AND TAD.ResultType = @ResultType INNER JOIN
									T_Peptides P ON #JobsInBatch.Job = P.Job INNER JOIN 
									T_Score_MSAlign M ON P.Peptide_ID = M.Peptide_ID INNER JOIN 
									T_Score_Discriminant SD ON P.Peptide_ID = SD.Peptide_ID INNER JOIN 
									T_Mass_Tags MT ON P.Mass_Tag_ID = MT.Mass_Tag_ID INNER JOIN
									T_Mass_Tags_NET MTN ON MT.Mass_Tag_ID = MTN.Mass_Tag_ID INNER JOIN
									T_Mass_Tag_to_Protein_Map MTPM ON MT.Mass_Tag_ID= MTPM.Mass_Tag_ID
						) LookupQ
					GROUP BY Job, Peptide_ID, PeptideLength, Charge_State,
							 RankScore, MSAlign_PValue, MSAlign_FDR,
							 MH, Peptide_Prophet_Probability,
							 MSGF_SpecProb, NET_Difference_Absolute
					ORDER BY Peptide_ID
					--
					SELECT @myError = @@error, @myRowCount = @@RowCount
				End
				
				-- @myError will be non-zero if there is an error or if @ResultType was not recognized
				If @myError <> 0 
				Begin
					If @myError = 51200
						set @message = 'Error populating #PeptideStats in CheckFilterForAnalysesWork; Invalid ResultType ''' + @ResultType + ''''
					Else
						set @message = 'Error populating #PeptideStats in CheckFilterForAnalysesWork'
					Goto done
				End

				-----------------------------------------------------------
				-- Now call GetThresholdsForFilterSet to get the thresholds to filter against
				-- Set Pass_FilterSet_Group to 1 in #PeptideStats for the matching peptides
				-----------------------------------------------------------

				Set @CriteriaGroupStart = 0
				Set @TestThresholds = 1
				
				While @TestThresholds = 1
				Begin -- <c>
				
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
					Begin -- <d>
						-- Construct the Sql Update Query
						--
						Set @S = ''
						Set @S = @S + ' UPDATE #PeptideStats'
						Set @S = @S + ' SET Pass_FilterSet_Group = 1'
						Set @S = @S + ' WHERE  Charge_State ' +  @ChargeStateComparison +          Convert(varchar(11), @ChargeStateThreshold) + ' AND '

						If @ResultType = 'Peptide_Hit'
						Begin
							Set @S = @S +        ' XCorr ' +         @HighNormalizedScoreComparison +  Convert(varchar(11), @HighNormalizedScoreThreshold) + ' AND '
							Set @S = @S +        ' RankScore ' +     @RankScoreComparison           +  Convert(varchar(11), @RankScoreThreshold) + ' AND '
						End
						
						If @ResultType = 'XT_Peptide_Hit'
						Begin
							Set @S = @S +        ' Hyperscore ' +         @XTandemHyperscoreComparison +  Convert(varchar(11), @XTandemHyperscoreThreshold) + ' AND '
							Set @S = @S +        ' Log_EValue ' +         @XTandemLogEValueComparison +   Convert(varchar(11), @XTandemLogEValueThreshold) + ' AND '
						End

						If @ResultType = 'IN_Peptide_Hit'
						Begin
							Set @S = @S +        ' Inspect_MQScore ' +        @InspectMQScoreComparison +        Convert(varchar(11), @InspectMQScoreThreshold) + ' AND '
							Set @S = @S +        ' Inspect_TotalPRMScore ' +  @InspectTotalPRMScoreComparison +  Convert(varchar(11), @InspectTotalPRMScoreThreshold) + ' AND '
							Set @S = @S +        ' Inspect_FScore ' +         @InspectFScoreComparison +         Convert(varchar(11), @InspectFScoreThreshold) + ' AND '
							Set @S = @S +        ' Inspect_PValue ' +         @InspectPValueComparison +         Convert(varchar(11), @InspectPValueThreshold) + ' AND '
							Set @S = @S +        ' RankScore ' +              @RankScoreComparison +             Convert(varchar(11), @RankScoreThreshold) + ' AND '
						End

						If @ResultType = 'MSG_Peptide_Hit'
						Begin
							Set @S = @S +        ' MSGFDB_SpecProb ' +       @MSGFDbSpecProbComparison +   Convert(varchar(11), @MSGFDbSpecProbThreshold) + ' AND '
							Set @S = @S +        ' MSGFDB_PValue ' +         @MSGFDbPValueComparison +     Convert(varchar(11), @MSGFDbPValueThreshold) + ' AND '
							Set @S = @S +        ' MSGFDB_FDR ' +            @MSGFDbFDRComparison +        Convert(varchar(11), @MSGFDbFDRThreshold) + ' AND '
							Set @S = @S +        ' RankScore ' +             @RankScoreComparison +        Convert(varchar(11), @RankScoreThreshold) + ' AND '
						End
						
						If @ResultType = 'MSA_Peptide_Hit'
						Begin
							Set @S = @S +        ' MSAlign_PValue ' +         @MSAlignPValueComparison +     Convert(varchar(11), @MSAlignPValueThreshold) + ' AND '
							Set @S = @S +        ' MSAlign_FDR ' +            @MSAlignFDRComparison +        Convert(varchar(11), @MSAlignFDRThreshold) + ' AND '
						End
						
						If @ResultType <> 'MSA_Peptide_Hit'
						Begin
							Set @S = @S +        ' MSGF_SpecProb ' + @MSGFSpecProbComparison + Convert(varchar(11), @MSGFSpecProbThreshold) + ' AND '						
						End
						
						Set @S = @S +        ' Cleavage_State ' + @CleavageStateComparison + Convert(varchar(11), @CleavageStateThreshold) + ' AND '
						Set @S = @S +        ' Terminus_State ' + @TerminusStateComparison + Convert(varchar(11), @TerminusStateThreshold) + ' AND '
						Set @S = @S +		 ' PeptideLength ' + @PeptideLengthComparison +  Convert(varchar(11), @PeptideLengthThreshold) + ' AND '
						Set @S = @S +		 ' Mass ' + @MassComparison + Convert(varchar(11), @MassThreshold) + ' AND '

						If @ResultType = 'Peptide_Hit'
						Begin
							Set @S = @S +		 ' DeltaCn ' + @DeltaCnComparison + Convert(varchar(11), @DeltaCnThreshold) + ' AND '
						End
						
						Set @S = @S +		 ' DeltaCn2' + @DeltaCn2Comparison + Convert(varchar(11), @DeltaCn2Threshold) + ' AND '
						Set @S = @S +        ' Discriminant_Score ' + @DiscriminantScoreComparison + Convert(varchar(11), @DiscriminantScoreThreshold) + ' AND '
						Set @S = @S +        ' Peptide_Prophet_Probability ' + @PeptideProphetComparison + Convert(varchar(11), @PeptideProphetThreshold) + ' AND '
						Set @S = @S +        ' NET_Difference_Absolute ' + @NETDifferenceAbsoluteComparison + Convert(varchar(11), @NETDifferenceAbsoluteThreshold)

						-- Execute the Sql to update the Pass_FilterSet_Group column
						If @PreviewSql <> 0
						Begin
							Print 'Filter Set ID: ' + Convert(varchar(12), @FilterSetID) + ', Criteria Group: ' + Convert(varchar(12), @CriteriaGroupStart)
							Print @S
						End
						Else
							Exec (@S)
						--
						SELECT @myError = @@error, @myRowCount = @@RowCount
						
					End -- </d>

					-- Lookup the next set of filters
					--
					Set @CriteriaGroupStart = @CriteriaGroupMatch + 1
					
				End -- </c>

				-----------------------------------------------
				-- Populate #PeptideFilterResults with the results
				-----------------------------------------------
				--
				INSERT INTO #PeptideFilterResults (Job, Peptide_ID, Pass_FilterSet)
				SELECT Job, Peptide_ID, Pass_FilterSet_Group
				FROM #PeptideStats				
				--
				SELECT @myError = @@error, @myRowCount = @@RowCount
			
			End -- </b>
			
		End -- </a>


	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'CheckFilterForAnalysesWork')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, @LogWarningErrorList = '',
								@ErrorNum = @myError output, @message = @message output
	End Catch	
	
Done:
	Return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[CheckFilterForAnalysesWork] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[CheckFilterForAnalysesWork] TO [MTS_DB_Lite] AS [dbo]
GO
