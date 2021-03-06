/****** Object:  StoredProcedure [dbo].[GetThresholdsForFilterSet] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE GetThresholdsForFilterSet
/****************************************************
**
**	Desc: 
**		Returns thresholds for given filter Set ID
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	08/24/2004
**			08/28/2004 grk - accounted for V_DMS_Filter_Sets_Import moving to MT_Main
**			09/10/2004 mem - Added @DiscriminantInitialFilter criteria
**			09/19/2004 mem - Added @ProteinCount criteria
**			03/26/2005 mem - Added @TerminusState criteria
**			12/11/2005 mem - Added @XTandemHyperscore and @XTandemLogEValue criteria
**			07/10/2006 mem - Added @PeptideProphetComparison and @PeptideProphetThreshold
**			08/26/2006 mem - Added @RankScoreComparison and @RankScoreThreshold
**						   - Updated to cache the criteria for the given filter set group locally to remove the need to repeatedly query MT_Main.dbo.V_DMS_Filter_Sets_Import
**			10/30/2008 mem - Added @InspectMQScore, @InspectTotalPRMScore, and @InspectFScore criteria
**			07/21/2009 mem - Added @InspectPValue
**			08/02/2010 mem - Added @MSGFSpecProb
**						   - Switched to using V_DMS_Filter_Set_Details (which queries a table in MT_Main) rather than querying V_DMS_Filter_Sets_Import
**			08/09/2011 mem - Switched default PeptideProphet Threshold from >= 0 to >= -1
**			09/16/2011 mem - Switched default PeptideProphet Threshold from >= -1 to >= -100
**						   - Added parameters @MSGFDbSpecProb, @MSGFDbPValue, and @MSGFDbFDR
**			12/05/2012 mem - Added parameters @MSAlignPValueComparison and @MSAlignFDRComparison
**			05/07/2013 mem - Renamed parameter @MSGFDbFDR to @MSGFPlusQValue
**							 Added parameter @MSGFPlusPepQValue
**    
*****************************************************/
(
	@FilterSetID int,
	@CriteriaGroupStart int=0,								-- If > 0, then will return the entries for this Filter Set having Filter_Criteria_Group >= @CriterionOrderStart

	@CriteriaGroupMatch int=0 output,						-- > 0 If the @FilterSetID and @CriteriaGroupStart resolve to a valid Set of criteria
	@message varchar(255)='' output,

	@SpectrumCountComparison varchar(2)='>=' output,
	@SpectrumCountThreshold int=0 output,

	@ChargeStateComparison varchar(2)='>=' output,
	@ChargeStateThreshold smallint=0 output,

	@HighNormalizedScoreComparison varchar(2)='>=' output,
	@HighNormalizedScoreThreshold float=0 output,

	@CleavageStateComparison varchar(2)='>=' output,
	@CleavageStateThreshold tinyint=0 output,

	@PeptideLengthComparison varchar(2)='>=' output,
	@PeptideLengthThreshold int=0 output,

	@MassComparison varchar(2)='>=' output,
	@MassThreshold float=0 output,

	@DeltaCnComparison varchar(2)='>=' output,
	@DeltaCnThreshold float=0 output,

	@DeltaCn2Comparison varchar(2)='>=' output,
	@DeltaCn2Threshold float=0 output,

	@DiscriminantScoreComparison varchar(2)='>=' output,
	@DiscriminantScoreThreshold float=0 output,

	@NETDifferenceAbsoluteComparison varchar(2)='>=' output,
	@NETDifferenceAbsoluteThreshold float=0 output,
	
	@DiscriminantInitialFilterComparison varchar(2)='>=' output,
	@DiscriminantInitialFilterThreshold float=0 output,
	
	@ProteinCountComparison varchar(2)='>=' output,
	@ProteinCountThreshold int=0 output,
	
	@TerminusStateComparison varchar(2)='>=' output,
	@TerminusStateThreshold tinyint=0 output,

	@XTandemHyperscoreComparison varchar(2)='>=' output,
	@XTandemHyperscoreThreshold real=0 output,

	@XTandemLogEValueComparison varchar(2)='<=' output,
	@XTandemLogEValueThreshold real=0 output,
	
	@PeptideProphetComparison varchar(2)='>=' output,
	@PeptideProphetThreshold float=-100 output,
	
	@RankScoreComparison varchar(2)='>=' output,
	@RankScoreThreshold smallint=0 output,

	@InspectMQScoreComparison varchar(2)='>=' output,
	@InspectMQScoreThreshold real=-10000 output,				
	
	@InspectTotalPRMScoreComparison varchar(2)='>=' output,
	@InspectTotalPRMScoreThreshold real=-10000 output,

	@InspectFScoreComparison varchar(2)='>=' output,
	@InspectFScoreThreshold real=-10000 output,
	
	@InspectPValueComparison varchar(2)='<=' output,
	@InspectPValueThreshold real=1 output,

	@MSGFSpecProbComparison varchar(2)='<=' output,
	@MSGFSpecProbThreshold real=1 output,

	@MSGFDbSpecProbComparison varchar(2)='<=' output,
	@MSGFDbSpecProbThreshold real=1 output,
	
	@MSGFDbPValueComparison varchar(2)='<=' output,
	@MSGFDbPValueThreshold real=1 output,

	@MSGFPlusQValueComparison varchar(2)='<=' output,
	@MSGFPlusQValueThreshold real=1 output, 

	@MSGFPlusPepQValueComparison varchar(2)='<=' output,
	@MSGFPlusPepQValueThreshold real=1 output, 

	@MSAlignPValueComparison varchar(2)='<=' output,
	@MSAlignPValueThreshold real=1 output,

	@MSAlignFDRComparison varchar(2)='<=' output,
	@MSAlignFDRThreshold real=1 output
	
)
As
	Set nocount on
	
	Declare @myRowCount int,
			@myError int
	Set @myRowCount = 0
	Set @myError = 0

	Declare @MatchCount int
	Set @MatchCount = 0
		
	-------------------------------------------------
	-- Set default return values
	-------------------------------------------------
	--
	Set @CriteriaGroupMatch = 0
	Set @message = ''

	Set @SpectrumCountComparison = '>='
	Set @SpectrumCountThreshold  = 0

	Set @ChargeStateComparison = '>='
	Set @ChargeStateThreshold  = 0

	Set @HighNormalizedScoreComparison = '>='
	Set @HighNormalizedScoreThreshold  = 0

	Set @CleavageStateComparison = '>='
	Set @CleavageStateThreshold  = 0

	Set @PeptideLengthComparison = '>='
	Set @PeptideLengthThreshold = 0

	Set @MassComparison = '>='
	Set @MassThreshold  = 0

	Set @DeltaCnComparison = '<='
	Set @DeltaCnThreshold  = 1

	Set @DeltaCn2Comparison = '>='
	Set @DeltaCn2Threshold  = 0

	Set @DiscriminantScoreComparison = '>='
	Set @DiscriminantScoreThreshold  = 0

	Set @NETDifferenceAbsoluteComparison = '<='
	Set @NETDifferenceAbsoluteThreshold  = 100

	Set @DiscriminantInitialFilterComparison = '>='
	Set @DiscriminantInitialFilterThreshold  = 0
	
	Set @ProteinCountComparison = '>='
	Set @ProteinCountThreshold  = 0

	Set @TerminusStateComparison = '>='
	Set @TerminusStateThreshold  = 0

	Set @XTandemHyperscoreComparison = '>='
	Set @XTandemHyperscoreThreshold  = 0

	Set @XTandemLogEValueComparison = '<='
	Set @XTandemLogEValueThreshold  = 0
	
	Set @PeptideProphetComparison = '>='
	Set @PeptideProphetThreshold  = -100

	Set @RankScoreComparison = '>='
	Set @RankScoreThreshold  = 0

	Set @InspectMQScoreComparison = '>='
	Set @InspectMQScoreThreshold  = -10000			-- MQScore can be negative, so defaulting to >= -10000
	
	Set @InspectTotalPRMScoreComparison = '>='
	Set @InspectTotalPRMScoreThreshold  = -10000	-- TotalPRMScore can be negative, so defaulting to >= -10000

	Set @InspectFScoreComparison = '>='
	Set @InspectFScoreThreshold  = -10000			-- FScore can be negative, so defaulting to >= -10000
	
	Set @InspectPValueComparison = '<='
	Set @InspectPValueThreshold = 1

	Set @MSGFSpecProbComparison = '<='				-- MSGF re-scorer tool
	Set @MSGFSpecProbThreshold = 1

	Set @MSGFDbSpecProbComparison = '<='			-- MSGF+ (aka MSGFDB) Search Engine
	Set @MSGFDbSpecProbThreshold = 1
	
	Set @MSGFDbPValueComparison = '<='				-- MSGFDB Search Engine
	Set @MSGFDbPValueThreshold = 1

	Set @MSGFPlusQValueComparison = '<='			-- MSGF+ Search Engine (was called FDR by MSGFDB)
	Set @MSGFPlusQValueThreshold = 1

	Set @MSGFPlusPepQValueComparison = '<='			-- MSGF+ Search Engine (was called PepFDR by MSGFDB)
	Set @MSGFPlusPepQValueThreshold = 1

	Set @MSAlignPValueComparison = '<='				-- MSAlign Search Engine
	Set @MSAlignPValueThreshold = 1

	Set @MSAlignFDRComparison = '<='				-- MSAlign Search Engine
	Set @MSAlignFDRThreshold = 1
	
	-------------------------------------------------
	-- Validate @FilterSetID
	-------------------------------------------------
	--
	SELECT @MatchCount = COUNT(*)
	FROM MT_Main.dbo.V_DMS_Filter_Set_Overview
	WHERE Filter_Set_ID = @FilterSetID
	--
	SELECT @myError = @@error, @myRowCount = @@RowCount
	--
	If @myError <> 0
	Begin
		Set @message = 'Could not validate filter Set ID ' + Convert(varchar(11), @FilterSetID) + ' in MT_Main.dbo.V_DMS_Filter_Set_Overview'		
		Goto Done
	End
	
	If @MatchCount = 0
	Begin
		Set @message = 'Filter Set ID ' + Convert(varchar(11), @FilterSetID) + ' not found in MT_Main.dbo.V_DMS_Filter_Set_Overview'
		Set @myError = 201
		Goto Done
	End

	-------------------------------------------------
	-- Populate a temporary table with the criteria defined for this filter Set
	-- Using a temporary table to avoid having to re-query 
	-- MT_Main.dbo.V_DMS_Filter_Set_Details repeatedly
	-------------------------------------------------
	-- 

	--	if exists (select * from dbo.sysobjects where id = object_id(N'[#T_TmpFilterSetCriteria') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	--	drop table [#T_TmpFilterSetCriteria

	CREATE TABLE #T_TmpFilterSetCriteria (
		Filter_Criteria_Group_ID int NOT NULL ,
		Criterion_ID int NOT NULL ,
		Criterion_Comparison char(2) NOT NULL ,
		Criterion_Value float NOT NULL 
	)
	
	Set @CriteriaGroupMatch = 0
	Set @CriteriaGroupStart = IsNull(@CriteriaGroupStart, 0)

	INSERT INTO #T_TmpFilterSetCriteria (Filter_Criteria_Group_ID, Criterion_ID, Criterion_Comparison, Criterion_Value)
	SELECT Filter_Criteria_Group_ID, Criterion_ID, Criterion_Comparison, Criterion_Value
	FROM MT_Main.dbo.V_DMS_Filter_Set_Details
	WHERE Filter_Set_ID = @FilterSetID AND Filter_Criteria_Group_ID >= @CriteriaGroupStart
	ORDER BY Filter_Criteria_Group_ID
	--
	SELECT @myError = @@error, @myRowCount = @@RowCount

	If @myRowCount > 0
	Begin
		-------------------------------------------------
		-- Found one or more groups and criteria
		-- Populate @CriteriaGroupMatch
		-------------------------------------------------
		SELECT @CriteriaGroupMatch = MIN(Filter_Criteria_Group_ID)
		FROM #T_TmpFilterSetCriteria
		--
		SELECT @myError = @@error, @myRowCount = @@RowCount
		
		-- Delete entries not belonging to @CriteriaGroupMatch, 
		-- which will remove the need for us to filter on Filter_Criteria_Group_ID below
		DELETE FROM #T_TmpFilterSetCriteria
		WHERE Filter_Criteria_Group_ID <> @CriteriaGroupMatch
		--
		SELECT @myError = @@error, @myRowCount = @@RowCount
		
		-------------------------------------------------
		-- Lookup thresholds
		-------------------------------------------------
		
		SELECT TOP 1 @SpectrumCountComparison = Criterion_Comparison,
					 @SpectrumCountThreshold = Criterion_Value
		FROM #T_TmpFilterSetCriteria
		WHERE Criterion_ID = 1		-- Spectrum_Count
		--
		Set @myError = @@Error
		
		If @myError <> 0
		Begin
			Set @message = 'Error looking up Spectrum Count threshold for Filter Set ID ' + Convert(varchar(11), @FilterSetID) + ' and Filter_Criteria_Group_ID ' + convert(varchar(11), @CriteriaGroupMatch) + ' in MT_Main.dbo.V_DMS_Filter_Set_Details'
			Goto DoneDropTable
		End

		SELECT TOP 1 @ChargeStateComparison = Criterion_Comparison,
					 @ChargeStateThreshold = Criterion_Value
		FROM #T_TmpFilterSetCriteria
		WHERE Criterion_ID = 2		-- Charge

		SELECT TOP 1 @HighNormalizedScoreComparison = Criterion_Comparison,
					 @HighNormalizedScorethreshold = Criterion_Value
		FROM #T_TmpFilterSetCriteria
		WHERE Criterion_ID = 3		-- High_Normalized_Score

		SELECT TOP 1 @CleavageStateComparison = Criterion_Comparison,
					 @CleavageStateThreshold = Criterion_Value
		FROM #T_TmpFilterSetCriteria
		WHERE Criterion_ID = 4		-- Cleavage_State

		SELECT TOP 1 @PeptideLengthComparison = Criterion_Comparison,
					 @PeptideLengthThreshold = Criterion_Value
		FROM #T_TmpFilterSetCriteria
		WHERE Criterion_ID = 5		-- Peptide_Length

		SELECT TOP 1 @MassComparison = Criterion_Comparison,
					 @MassThreshold = Criterion_Value
		FROM #T_TmpFilterSetCriteria
		WHERE Criterion_ID = 6		-- Mass

		SELECT TOP 1 @DeltaCnComparison = Criterion_Comparison,
					 @DeltaCnThreshold = Criterion_Value
		FROM #T_TmpFilterSetCriteria
		WHERE Criterion_ID = 7		-- DeltaCn

		SELECT TOP 1 @DeltaCn2Comparison = Criterion_Comparison,
					 @DeltaCn2Threshold = Criterion_Value
		FROM #T_TmpFilterSetCriteria
		WHERE Criterion_ID = 8		-- DeltaCn2

		SELECT TOP 1 @DiscriminantScoreComparison = Criterion_Comparison,
					 @DiscriminantScoreThreshold = Criterion_Value
		FROM #T_TmpFilterSetCriteria
		WHERE Criterion_ID = 9		-- Discriminant_Score

		SELECT TOP 1 @NETDifferenceAbsoluteComparison = Criterion_Comparison,
					 @NETDifferenceAbsoluteThreshold = Criterion_Value
		FROM #T_TmpFilterSetCriteria
		WHERE Criterion_ID = 10	-- NET_Difference_Absolute

		SELECT TOP 1 @DiscriminantInitialFilterComparison = Criterion_Comparison,
					 @DiscriminantInitialFilterThreshold = Criterion_Value
		FROM #T_TmpFilterSetCriteria
		WHERE Criterion_ID = 11	-- Discriminant_Initial_Filter

		SELECT TOP 1 @ProteinCountComparison = Criterion_Comparison,
					 @ProteinCountThreshold = Criterion_Value
		FROM #T_TmpFilterSetCriteria
		WHERE Criterion_ID = 12	-- Protein_Count

		SELECT TOP 1 @TerminusStateComparison = Criterion_Comparison,
					 @TerminusStateThreshold = Criterion_Value
		FROM #T_TmpFilterSetCriteria
		WHERE Criterion_ID = 13	-- Terminus_State

		SELECT TOP 1 @XTandemHyperscoreComparison = Criterion_Comparison,
					 @XTandemHyperscoreThreshold = Criterion_Value
		FROM #T_TmpFilterSetCriteria
		WHERE Criterion_ID = 14	-- XTandem_Hyperscore

		SELECT TOP 1 @XTandemLogEValueComparison = Criterion_Comparison,
					 @XTandemLogEValueThreshold = Criterion_Value
		FROM #T_TmpFilterSetCriteria
		WHERE Criterion_ID = 15	-- XTandem_LogEValue

		SELECT TOP 1 @PeptideProphetComparison = Criterion_Comparison,
					 @PeptideProphetThreshold = Criterion_Value
		FROM #T_TmpFilterSetCriteria
		WHERE Criterion_ID = 16	-- Peptide_Prophet_Probability

		SELECT TOP 1 @RankScoreComparison = Criterion_Comparison,
					 @RankScoreThreshold = Criterion_Value
		FROM #T_TmpFilterSetCriteria
		WHERE Criterion_ID = 17	-- RankScore

		SELECT TOP 1 @InspectMQScoreComparison = Criterion_Comparison,
					 @InspectMQScoreThreshold = Criterion_Value
		FROM #T_TmpFilterSetCriteria
		WHERE Criterion_ID = 18	-- Inspect MQScore

		SELECT TOP 1 @InspectTotalPRMScoreComparison = Criterion_Comparison,
					 @InspectTotalPRMScoreThreshold = Criterion_Value
		FROM #T_TmpFilterSetCriteria
		WHERE Criterion_ID = 19	-- Inspect TotalPRMScore
		
		SELECT TOP 1 @InspectFScoreComparison = Criterion_Comparison,
					 @InspectFScoreThreshold = Criterion_Value
		FROM #T_TmpFilterSetCriteria
		WHERE Criterion_ID = 20	-- Inspect FScore

		SELECT TOP 1 @InspectPValueComparison = Criterion_Comparison,
					 @InspectPValueThreshold = Criterion_Value
		FROM #T_TmpFilterSetCriteria
		WHERE Criterion_ID = 21	-- Inspect PValue

		SELECT TOP 1 @MSGFSpecProbComparison = Criterion_Comparison,
					 @MSGFSpecProbThreshold = Criterion_Value
		FROM #T_TmpFilterSetCriteria
		WHERE Criterion_ID = 22	-- MSGF SpecProb

		SELECT TOP 1 @MSGFDbSpecProbComparison = Criterion_Comparison,
					 @MSGFDbSpecProbThreshold = Criterion_Value
		FROM #T_TmpFilterSetCriteria
		WHERE Criterion_ID = 23	-- MSGFDB SpecProb

		SELECT TOP 1 @MSGFDbPValueComparison = Criterion_Comparison,
					 @MSGFDbPValueThreshold = Criterion_Value
		FROM #T_TmpFilterSetCriteria
		WHERE Criterion_ID = 24	-- MSGFDB PValue

		SELECT TOP 1 @MSGFPlusQValueComparison = Criterion_Comparison,
					 @MSGFPlusQValueThreshold = Criterion_Value
		FROM #T_TmpFilterSetCriteria
		WHERE Criterion_ID = 25	-- MSGFPlus QValue

		SELECT TOP 1 @MSGFPlusPepQValueComparison = Criterion_Comparison,
					 @MSGFPlusPepQValueThreshold = Criterion_Value
		FROM #T_TmpFilterSetCriteria
		WHERE Criterion_ID = 28	-- MSGFPlus PepQValue

		SELECT TOP 1 @MSAlignPValueComparison = Criterion_Comparison,
					 @MSAlignPValueThreshold = Criterion_Value
		FROM #T_TmpFilterSetCriteria
		WHERE Criterion_ID = 26	-- MSAlign PValue

		SELECT TOP 1 @MSAlignFDRComparison = Criterion_Comparison,
					 @MSAlignFDRThreshold = Criterion_Value
		FROM #T_TmpFilterSetCriteria
		WHERE Criterion_ID = 27	-- MSAlign FDR

	End

DoneDropTable:
	DROP TABLE #T_TmpFilterSetCriteria

Done:
	Return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[GetThresholdsForFilterSet] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetThresholdsForFilterSet] TO [MTS_DB_Lite] AS [dbo]
GO
