/****** Object:  StoredProcedure [dbo].[CalculateConfidenceScoresOneAnalysisNoSeqID] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.CalculateConfidenceScoresOneAnalysisNoSeqID
/****************************************************
**
**	Desc: 
**		Updates confidence scores for all the peptides
**		from analysis Job @JobToProcess; does not require
**		that Seq_ID be defined in T_Peptides (uses GANET_Obs for Seq.GANET_Predicted)
**
**	Return values: 0 if no error; otherwise error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	08/31/2006
**			03/22/2007 mem - Added option @OnlyProcessPeptidesWithNullDiscriminant
**			10/10/2008 mem - Added support for Inspect results (type IN_Peptide_Hit)
**			10/29/2008 mem - Updated to use DeltaNormTotalPRMScore for DeltaCn2 for Inspect
**			02/19/2009 mem - Changed @ResidueCount to bigint
**    
*****************************************************/
(
	@JobToProcess int,
	@NextProcessState int = 90,
	@NextProcessStateSkipPeptideProphet int = 60,
	@OnlyProcessPeptidesWithNullDiscriminant tinyint = 1,			-- Set to 1 to only process entries that currently have a null discriminant score
	@message varchar(255)='' OUTPUT
)
AS
	Set NoCount On

	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @DiscriminantTrans varchar(64)
	set @DiscriminantTrans = 'DiscriminantCalc'
	
	set @JobToProcess = IsNull(@JobToProcess, 0)
	set @message = ''
	set @OnlyProcessPeptidesWithNullDiscriminant = IsNull(@OnlyProcessPeptidesWithNullDiscriminant, 0)
	
	declare @jobStr varchar(128)
	set @jobStr = Convert(varchar(12), @JobToProcess)
	
	declare	@MatchFound tinyint
	declare @ProteinCount int
	declare @ResidueCount bigint
	declare @result int
	declare @ResultType varchar(32)
	declare @JobAdvancedToNextState tinyint

	declare @message2 varchar(256)
	set @message2 = ''
	
	Set @ProteinCount = 0
	Set @ResidueCount = 0
	
	------------------------------------------------------------------
	-- Lookup the number of proteins and residues in Organism DB file (aka the FASTA file)
	--  or Protein Collection used for this analysis job
	-- Note that GetOrganismDBFileInfo will post an error to the log if the job
	--  has an unknown Fasta file or Protein Collection List
	------------------------------------------------------------------
	--
	Exec @result = GetOrganismDBFileInfo @JobToProcess, 
										 @ProteinCount = @ProteinCount OUTPUT, 
										 @ResidueCount = @ResidueCount OUTPUT
		
	If IsNull(@ResidueCount, 0) < 1
		Set @ResidueCount = 1

	-----------------------------------------------
	-- Lookup the ResultType for Job @JobToProcess
	-----------------------------------------------
	Set @ResultType = ''
	SELECT @ResultType = ResultType
	FROM T_Analysis_Description
	WHERE Job = @JobToProcess
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 
	begin
		set @message = 'Error retrieving ResultType for job ' + @jobStr
		goto done
	end
	--
	if @myRowCount = 0
	begin
		set @message = 'Job ' + @jobStr + ' not found in T_Analysis_Description'
		set @myError = 50000
		goto done
	end

	------------------------------------------------------------------
	-- Create a temporary table to hold the data needed to compute the discriminant score
	------------------------------------------------------------------
	
	if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[#TmpConfidenceScoreData]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
		drop table [dbo].[#TmpConfidenceScoreData]

	CREATE TABLE #TmpConfidenceScoreData (
		[Peptide_ID] [int] NOT NULL ,
		[XCorr] [real] NULL ,
		[DeltaCn2] [real] NULL ,
		[DelM] [float] NULL ,
		[GANET_Obs] [real] NULL ,
		[GANET_Predicted] [real] NULL ,
		[RankSp] [int] NULL ,
		[RankXc] [int] NULL ,
		[XcRatio] [real] NULL ,
		[Charge_State] [smallint] NULL ,
		[PeptideLength] [int] NULL ,
		[Cleavage_State_Max] [tinyint] NOT NULL ,
		[PassFilt] [int] NULL ,
		[MScore] [real] NULL ,
		[DiscriminantScore] [float] NULL ,
		[DiscriminantScoreNorm] [real] NULL
	) ON [PRIMARY]

	CREATE CLUSTERED INDEX [#IX_Tmp_ConfidenceScoreData_Peptide_ID] ON [dbo].[#TmpConfidenceScoreData]([Peptide_ID]) ON [PRIMARY]

	------------------------------------------------------------------
	-- Populate #TmpConfidenceScoreData
	------------------------------------------------------------------
	--
	-- Initially set @myError to a non-zero value in case @ResultType is invalid for this SP
	-- Note that this error code is used below so update in both places if changing
	set @myError = 50001

	If @ResultType = 'Peptide_Hit'
	Begin
		INSERT INTO #TmpConfidenceScoreData (Peptide_ID, XCorr, DeltaCn2, DelM, GANET_Obs, 
					GANET_Predicted, RankSp, RankXc, XcRatio, Charge_State, 
					PeptideLength, Cleavage_State_Max, 
					PassFilt, MScore)
		SELECT	P.Peptide_ID, S.XCorr, S.DeltaCn2, S.DelM, P.GANET_Obs, 
				P.GANET_Obs AS GANET_Predicted, S.RankSp, S.RankXc, S.XcRatio, P.Charge_State, 
				LEN(dbo.udfCleanSequence(P.Peptide)) AS PeptideLength, MAX(PPM.Cleavage_State) AS Cleavage_State_Max, 
				SD.PassFilt, SD.MScore
		FROM T_Score_Discriminant SD INNER JOIN
			 T_Peptides AS P ON SD.Peptide_ID = P.Peptide_ID INNER JOIN
			 T_Score_Sequest AS S ON SD.Peptide_ID = S.Peptide_ID INNER JOIN
			 T_Peptide_to_Protein_Map AS PPM ON P.Peptide_ID = PPM.Peptide_ID
		WHERE P.Analysis_ID = @JobToProcess AND 
			  (@OnlyProcessPeptidesWithNullDiscriminant = 0 OR SD.DiscriminantScoreNorm Is Null)
		GROUP BY P.Peptide_ID, S.XCorr, S.DeltaCn2, S.DelM, P.GANET_Obs, 
				 S.RankSp, S.RankXc, S.XcRatio, P.Charge_State, 
				 LEN(dbo.udfCleanSequence(P.Peptide)), SD.PassFilt, SD.MScore
    	--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	End

	If @ResultType = 'XT_Peptide_Hit'
	Begin
		-- Note that PassFilt and MScore are estimated for XTandem data
		-- PassFilt was set to 1
		-- MScore was set to 10.75
		
		INSERT INTO #TmpConfidenceScoreData (Peptide_ID, XCorr, DeltaCn2, DelM, GANET_Obs, 
					GANET_Predicted, RankSp, RankXc, 
					XcRatio, Charge_State, PeptideLength, 
					Cleavage_State_Max, PassFilt, MScore)
		SELECT	P.Peptide_ID, X.Normalized_Score, X.DeltaCn2, X.DelM, P.GANET_Obs, 
				P.GANET_Obs AS GANET_Predicted, 1 AS RankSp, 1 AS RankXc, 
				1 AS XcRatio, P.Charge_State, LEN(dbo.udfCleanSequence(P.Peptide)) AS PeptideLength, 
				MAX(PPM.Cleavage_State) AS Cleavage_State_Max, SD.PassFilt, SD.MScore
		FROM T_Score_Discriminant SD INNER JOIN
			 T_Peptides P ON SD.Peptide_ID = P.Peptide_ID INNER JOIN
			 T_Score_XTandem X ON SD.Peptide_ID = X.Peptide_ID INNER JOIN
			 T_Peptide_to_Protein_Map PPM ON P.Peptide_ID = PPM.Peptide_ID
		WHERE P.Analysis_ID = @JobToProcess AND 
			  (@OnlyProcessPeptidesWithNullDiscriminant = 0 OR SD.DiscriminantScoreNorm Is Null)
		GROUP BY P.Peptide_ID, X.Normalized_Score, X.DeltaCn2, X.DelM, P.GANET_Obs, 
				 P.Charge_State, LEN(dbo.udfCleanSequence(P.Peptide)), SD.PassFilt, SD.MScore
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	End

	If @ResultType = 'IN_Peptide_Hit'
	Begin
		-- Note that PassFilt and MScore are estimated for Inspect data
		-- PassFilt was set to 1
		-- MScore was set to 10.75
		
		INSERT INTO #TmpConfidenceScoreData (Peptide_ID, XCorr, DeltaCn2, DelM, GANET_Obs, 
					GANET_Predicted, RankSp, RankXc, XcRatio, 
					Charge_State, PeptideLength, 
					Cleavage_State_Max, PassFilt, MScore)
		SELECT	P.Peptide_ID, I.Normalized_Score, I.DeltaNormTotalPRMScore, I.DelM, P.GANET_Obs, 
				P.GANET_Obs AS GANET_Predicted, 1 AS RankSp, RankFScore AS RankXc, 1 AS XcRatio, 
				P.Charge_State, LEN(dbo.udfCleanSequence(P.Peptide)) AS PeptideLength, 
				MAX(PPM.Cleavage_State) AS Cleavage_State_Max, SD.PassFilt, SD.MScore
		FROM T_Score_Discriminant SD INNER JOIN
			 T_Peptides P ON SD.Peptide_ID = P.Peptide_ID INNER JOIN
			 T_Score_Inspect I ON SD.Peptide_ID = I.Peptide_ID INNER JOIN
			 T_Peptide_to_Protein_Map PPM ON P.Peptide_ID = PPM.Peptide_ID
		WHERE P.Analysis_ID = @JobToProcess AND 
			  (@OnlyProcessPeptidesWithNullDiscriminant = 0 OR SD.DiscriminantScoreNorm Is Null)
		GROUP BY P.Peptide_ID, I.Normalized_Score, I.DeltaNormTotalPRMScore, I.DelM, P.GANET_Obs, I.RankFScore,
				 P.Charge_State, LEN(dbo.udfCleanSequence(P.Peptide)), SD.PassFilt, SD.MScore
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	End	
	--
	if @myError <> 0 
	begin
		If @myError = 50001
			set @message = 'Invalid ResultType ''' + @ResultType + ''' for job ' + @jobStr
		Else
			set @message = 'Error while populating #TmpConfidenceScoreData for job ' + @jobStr
		goto done
	end

	------------------------------------------------------------------
	-- Compute DiscriminantScore, then compute DiscriminantScoreNorm
	------------------------------------------------------------------
	UPDATE #TmpConfidenceScoreData
	SET DiscriminantScore = dbo.calcDiscriminantScore(
					XCorr, DeltaCn2, DelM, ISNULL(GANET_Obs, 0), 
					CASE WHEN IsNull(GANET_Obs, -10000) > -10000 THEN GANET_Predicted ELSE 0 END, 
					RankSp, RankXc, XcRatio, Charge_State, PeptideLength, 
					Cleavage_State_Max, 0, PassFilt, MScore
				)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 
	begin
		set @message = 'Error while computing #TmpConfidenceScoreData.DiscriminantScore for job ' + @jobStr
		goto done
	end

	UPDATE #TmpConfidenceScoreData
	SET DiscriminantScoreNorm = dbo.calcDiscriminantScoreNorm(DiscriminantScore, Charge_state, @ResidueCount)
	FROM #TmpConfidenceScoreData
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 
	begin
		set @message = 'Error while computing #TmpConfidenceScoreData.DiscriminantScoreNorm for job ' + @jobStr
		goto done
	end
	
	------------------------------------------------------------------
	-- Copy the data from #TmpConfidenceScoreData to T_Score_Discriminant
	------------------------------------------------------------------
	--
	Begin Transaction @DiscriminantTrans

	UPDATE T_Score_Discriminant
	SET DiscriminantScore = StatsQ.DiscriminantScore,
		DiscriminantScoreNorm = StatsQ.DiscriminantScoreNorm
	FROM T_Score_Discriminant AS SD INNER JOIN #TmpConfidenceScoreData AS StatsQ ON
		 SD.Peptide_ID = StatsQ.Peptide_ID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 
	begin
		set @message = 'Error while copying data from #TmpConfidenceScoreData to T_Score_Discriminant for job ' + @jobStr
		Rollback Tran @DiscriminantTrans
		goto done
	end
	else
		set @message = 'Discriminant scores computed for job ' + @jobStr + '; processed ' + convert(varchar(11), @myRowCount) + ' peptides'

	
	-- Advance the job state as appropriate
	Set @JobAdvancedToNextState = 0
	Exec @myError = CheckPeptideProphetUpdateRequired 0, @NextProcessStateSkipPeptideProphet, @message2 OUTPUT, @JobFilter = @JobToProcess, @JobAdvancedToNextState = @JobAdvancedToNextState OUTPUT
	if @myError <> 0 
	begin
		set @message = 'Error calling CheckPeptideProphetUpdateRequired for job ' + @jobStr
		If Len(IsNull(@message2, '')) > 0
			Set @message = @message + '; ' + @message2
			
		Rollback Tran @DiscriminantTrans
		goto done
	end
	
	If @JobAdvancedToNextState = 0
	Begin
		-- Job state not advanced to @NextProcessStateSkipPeptideProphet
		-- Therefore, advance to state @NextProcessState
		exec @myError = SetProcessState @JobToProcess, @NextProcessState
		--
		if @myError <> 0 
		begin
			set @message = 'Error setting next process state for job ' + @jobStr
			Rollback Tran @DiscriminantTrans
			goto done
		end
	End
	
	------------------------------------------------------------------
	-- Finalize the transaction
	------------------------------------------------------------------
	--
	Commit Tran @DiscriminantTrans
	
Done:
	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[CalculateConfidenceScoresOneAnalysisNoSeqID] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[CalculateConfidenceScoresOneAnalysisNoSeqID] TO [MTS_DB_Lite] AS [dbo]
GO
