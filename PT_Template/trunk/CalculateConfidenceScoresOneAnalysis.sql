SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[CalculateConfidenceScoresOneAnalysis]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[CalculateConfidenceScoresOneAnalysis]
GO


CREATE PROCEDURE dbo.CalculateConfidenceScoresOneAnalysis
/****************************************************
**
**	Desc: 
**		Updates confidence scores for
**		all the peptides from analysis Job @JobToProcess
**
**	Return values: 0 if no error; otherwise error code
**
**	Parameters:
**
**		Auth: mem
**		Date: 08/07/2004
**			  09/11/2004 mem - Switched to using T_Peptide_to_Protein_Map
**			  01/22/2004 mem - Changed method of looking up the cleavage state value for a peptide
**			  10/01/2005 mem - Updated to use Cleavage_State_Max in T_Sequence rather than polling T_Peptide_to_Protein_Map
**			  10/02/2005 mem - Updated to copy the data to process into a temporary table to avoid long lasting locks on T_Score_Discriminant
**    
*****************************************************/
	@JobToProcess int,
	@NextProcessState int = 60,
	@message varchar(255)='' OUTPUT
AS
	Set NoCount On

	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @DiscriminantTrans varchar(64)
	set @DiscriminantTrans = 'DiscriminantCalc'
	
	set @message = ''

	declare @jobStr varchar(128)
	set @jobStr = cast(@JobToProcess as varchar(12))
	
	declare	@ORFCount int,
			@ResidueCount int,
			@result int

	Set @ORFCount = 0
	Set @ResidueCount = 0

	------------------------------------------------------------------
	-- Lookup the size of the Organism DB file (aka the FASTA file) for this job
	------------------------------------------------------------------
	--
	Exec @result = GetOrganismDBFileStats @JobToProcess, @ORFCount OUTPUT, @ResidueCount OUTPUT

	If IsNull(@ResidueCount, 0) < 1
		Set @ResidueCount = 1


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
	INSERT INTO #TmpConfidenceScoreData (Peptide_ID, XCorr, DeltaCn2, DelM, GANET_Obs, 
				 GANET_Predicted, RankSp, RankXc, XcRatio, Charge_State, 
				 PeptideLength, Cleavage_State_Max, PassFilt, MScore)
	SELECT	P.Peptide_ID, S.XCorr, S.DeltaCn2, S.DelM, P.GANET_Obs, 
			Seq.GANET_Predicted, S.RankSp, S.RankXc, S.XcRatio, P.Charge_State, 
			LEN(Seq.Clean_Sequence) AS PeptideLength, Seq.Cleavage_State_Max, 
			SD.PassFilt, SD.MScore
	FROM T_Score_Discriminant AS SD INNER JOIN
		 T_Peptides AS P ON SD.Peptide_ID = P.Peptide_ID INNER JOIN
		 T_Score_Sequest AS S ON SD.Peptide_ID = S.Peptide_ID INNER JOIN
		 T_Sequence AS Seq ON P.Seq_ID = Seq.Seq_ID
	WHERE P.Analysis_ID = @JobToProcess
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 
	begin
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

	exec @myError = SetProcessState @JobToProcess, @NextProcessState
	--
	if @myError <> 0 
	begin
		set @message = 'Error setting next process state for job ' + @jobStr
		Rollback Tran @DiscriminantTrans
		goto done
	end
	
	------------------------------------------------------------------
	-- Finalize the transaction
	------------------------------------------------------------------
	--
	Commit Tran @DiscriminantTrans
	
Done:
	Return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

