/****** Object:  StoredProcedure [dbo].[ComputeProteinCoverage] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.ComputeProteinCoverage
/****************************************************
**
**	Desc:
**		Populates the T_Protein_Coverage table with protein coverage stats.
**		Note: Calls SP ComputeProteinCoverageWork to process each
**		 PMT Quality Score level (0, then 0.0001, then 1, 2, 3, ...)
**
**		However, if @PMTQualityScoreMinimumOverride is non-zero then only
**		 updates entries in T_Protein_Coverage for that PMT Quality Score
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	grk
**	Date:	02/19/2002
**			06/06/2004 mem - Added @ComputeORFResidueCoverage and switched from use of a cursor to a temporary table
**			06/12/2004 mem - Now checking whether ORF Residue Coverage is necessary for each ORF (by comparing PMT and AMT count stats before and after update)
**							 Added @message output parameter
**			06/13/2004 mem - Now using temporary tables to hold the sequences associated with ORF, for the various filters
**			09/28/2004 mem - Updated references from ORF to Protein and added computation by @PMTQualityScoreMinimum
**			09/29/2004 mem - Added logic to increase the number of iterations if the maximum PMT_Quality_Score defined is > 1
**			05/11/2005 mem - Added parameter @PMTQualityScoreMinimumOverride
**			03/14/2006 mem - Now calling VerifyUpdateEnabled
**			10/06/2006 mem - Now posting a status message to the log when starting and when finished, plus every @StatusMessageInterval minutes
**						   - Added parameters @ForceResidueLevelComputation and @StatusMessageInterval
**		
*****************************************************/
(
	@ComputeProteinResidueCoverage tinyint = 0,		-- When 1, then computes Protein coverage at the residue level; CPU intensive
	@numProteinsToProcess int = 0,					-- If greater than 0, then only processes this many proteins
	@message varchar(255) = '' output,
	@PMTQualityScoreMinimumOverride int = 0,		-- Set to a value greater than 0 to process only the given PMT Quality Score; additionally, will force a re-computation of residue-level coverage for this PMT QS and higher if @ComputeProteinResidueCoverage = 1
	@ForceResidueLevelComputation tinyint = 0,		-- When 0, then if @ComputeProteinResidueCoverage = 1 then computes protein coverage at the residue level only for those proteins with changed values for Count_PMTs, Count_Confirmed, or Total_MSMS_Observation_Count; when 1, then sets @ComputeProteinResidueCoverage to 1 and recomputes residue level coverage for all proteins
	@StatusMessageInterval int = 5					-- Number of minutes between status updates
)
As
	Set nocount on
	
	Declare @myRowCount int	
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0
	
	Declare @UpdateEnabled tinyint
	Declare @VerifyUpdateMessage varchar(255)
	Set @VerifyUpdateMessage = ''

	Declare @ProcessingStartTime datetime
	Set @ProcessingStartTime = GetDate()
	
	Declare @LastStatusUpdate datetime
	Set @LastStatusUpdate = GetDate()
	
	Declare @LogMessage varchar(256)
	
	------------------------------------------
	-- Validate the inputs
	------------------------------------------
	--
	Set @ComputeProteinResidueCoverage = IsNull(@ComputeProteinResidueCoverage, 0)
	Set @numProteinsToProcess = IsNull(@numProteinsToProcess, 0)
	Set @message = ''
	Set @PMTQualityScoreMinimumOverride = IsNull(@PMTQualityScoreMinimumOverride, 0)
	Set @StatusMessageInterval = IsNull(@StatusMessageInterval, 5)
	If @StatusMessageInterval < 1
		Set @StatusMessageInterval = 1

	Set @ForceResidueLevelComputation = IsNull(@ForceResidueLevelComputation, 0)
	If @ForceResidueLevelComputation <> 0
		Set @ComputeProteinResidueCoverage = 1

	------------------------------------------
	-- Copy the current values from T_Protein_Coverage to #ProteinCoverageSaved
	------------------------------------------
		
	CREATE TABLE #ProteinCoverageSaved (
		Ref_ID int NOT NULL,
		PMT_Quality_Score_Minimum real NOT NULL,
		Count_PMTs int,
		Count_Confirmed int,
		Total_MSMS_Observation_Count int,
		Coverage_PMTs real NULL,
		Coverage_Confirmed real NULL
	)

	INSERT INTO #ProteinCoverageSaved (
		Ref_ID, PMT_Quality_Score_Minimum,
		Count_PMTs, Count_Confirmed, Total_MSMS_Observation_Count,
		Coverage_PMTs, Coverage_Confirmed
		)
	SELECT	Ref_ID, PMT_Quality_Score_Minimum,
			Count_PMTs, Count_Confirmed, Total_MSMS_Observation_Count,
			Coverage_PMTs, Coverage_Confirmed
	FROM T_Protein_Coverage
	WHERE NOT (Coverage_PMTs Is Null OR Coverage_Confirmed Is Null)
	--
	SELECT @myError = @@error, @myRowcount = @@rowcount
	--
	If @myError <> 0
	Begin
		Set @message = 'Could not populate temporary table #ProteinCoverageSaved'
		Set @myError = 53802
		Goto Done
	End

	------------------------------------------
	-- Compute PMT statistics for the Proteins,
	-- using increasing levels of PMT_Quality_Score
	------------------------------------------

	Declare @Iteration int
	Declare @IterationMax int
	Declare @PMTQualityScoreMaxDefined real
	Declare @PMTQualityScoreMinimum real
	
	If @PMTQualityScoreMinimumOverride = 0
	Begin
		Set @Iteration = 0
		Set @IterationMax = 2
		
		-- Bump up @IterationMax to 3 If PMT_Quality_Score_Values > 1 are being computed
		--
		Set @PMTQualityScoreMaxDefined = 0
		SELECT @PMTQualityScoreMaxDefined = MAX(Convert(Real, PMT_Quality_Score_Value))
		FROM V_Filter_Set_Report
		WHERE Len(PMT_Quality_Score_Value) > 0
		
		If @PMTQualityScoreMaxDefined >= 2 AND @PMTQualityScoreMaxDefined < 3
			Set @IterationMax = 3
		Else
		Begin
			If @PMTQualityScoreMaxDefined >= 3
				Set @IterationMax = 4
		End
	End
	Else
	Begin
		Set @Iteration = @PMTQualityScoreMinimumOverride + 1
		Set @IterationMax = @Iteration
		Set @ForceResidueLevelComputation = 1
	End		


	------------------------------------------
	-- Post a status message to the log
	------------------------------------------
	Set @LogMessage = 'Protein Coverage Computation starting: Iterations = ' + Convert(varchar(12), @IterationMax+1) + '; ComputeProteinResidueCoverage = ' + Convert(varchar(6), @ComputeProteinResidueCoverage)
	execute PostLogEntry 'Normal', @LogMessage, 'ComputeProteinCoverage'
	Set @LogMessage = ''
		
	------------------------------------------
	-- Iterate using increasing @PMTQualityScoreMinimum values
	-- On the first iteration, use @PMTQualityScoreMinimum = 0
	-- On the second iteration, use @PMTQualityScoreMinimum = 0.0001
	-- On subsequent iterations, use @PMTQualityScoreMinimum = @Iteration-1  (thus, 1, 2, 3, ...)
	------------------------------------------
	--
	While @Iteration <= @IterationMax
	Begin -- <a>
		If @Iteration = 0
			Set @PMTQualityScoreMinimum = 0
		Else
			If @Iteration = 1
				Set @PMTQualityScoreMinimum = 0.0001
			Else
				Set @PMTQualityScoreMinimum = @Iteration-1

		Exec @myError = ComputeProteinCoverageWork @PMTQualityScoreMinimum, @ComputeProteinResidueCoverage, @ForceResidueLevelComputation, @numProteinsToProcess, @StatusMessageInterval, @LastStatusUpdate OUTPUT, @message OUTPUT

		Set @Iteration = @Iteration + 1

		-- Validate that updating is enabled, abort if not enabled
		exec VerifyUpdateEnabled @CallingFunctionDescription = 'ComputeProteinCoverage', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @VerifyUpdateMessage output
		If @UpdateEnabled = 0
		Begin
			If CharIndex('aborted', @VerifyUpdateMessage) = 0
				Set @VerifyUpdateMessage = @VerifyUpdateMessage + ' (aborted mid-processing since PMT_Tag_DB_Update is disabled in MT_Main)'
			
			Set @message = @VerifyUpdateMessage
			Goto Done
		End
	End -- </a>

	Set @LogMessage = 'Protein Coverage Computation complete: ' + @message
	If @Iteration < @IterationMax
		Set @LogMessage = @LogMessage + '; Completed ' + Convert(varchar(12), @Iteration+1) + ' out of ' + Convert(varchar(12), @IterationMax+1) + ' iterations'
		
	execute PostLogEntry 'Normal', @LogMessage, 'ComputeProteinCoverage'
	Set @LogMessage = ''

Done:	
	return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[ComputeProteinCoverage] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[ComputeProteinCoverage] TO [MTS_DB_Lite] AS [dbo]
GO
