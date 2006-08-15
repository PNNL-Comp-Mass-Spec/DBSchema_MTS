/****** Object:  StoredProcedure [dbo].[ComputeProteinCoverage] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.ComputeProteinCoverage
/****************************************************
**
**	Desc:
**		Populates the T_Protein_Coverage table with
**		protein coverage stats
**
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
**		
*****************************************************/
(
	@ComputeProteinResidueCoverage tinyint = 0,		-- When 1, then computes Protein coverage at the residue level; CPU intensive
	@numProteinsToProcess int = 0,					-- If greater than 0, then only processes this many proteins
	@message varchar(255) = '' output,
	@PMTQualityScoreMinimumOverride int = 0			-- Set to a value greater than 0 to process only the given PMT Quality Score
)
As
	set nocount on
	
	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
		
	Set @message = ''
	
	declare @UpdateEnabled tinyint
	declare @VerifyUpdateMessage varchar(255)
	set @VerifyUpdateMessage = ''
	
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
	if @myError <> 0
	begin
		Set @message = 'Could not populate temporary table #ProteinCoverageSaved'
		Set @myError = 53802
		Goto Done
	end


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
		
		-- Bump up @IterationMax to 3 if PMT_Quality_Score_Values > 1 are being computed
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
	End		
	
	-- Iterate using increasing @PMTQualityScoreMinimum values
	-- On the first iteration, use @PMTQualityScoreMinimum = 0
	-- On the second iteration, use @PMTQualityScoreMinimum = 0.0001
	-- On subsequent iterations, use @PMTQualityScoreMinimum = @Iteration-1  (thus, 1, 2, 3, ...)
	--
	While @Iteration <= @IterationMax
	Begin
		If @Iteration = 0
			Set @PMTQualityScoreMinimum = 0
		Else
			If @Iteration = 1
				Set @PMTQualityScoreMinimum = 0.0001
			Else
				Set @PMTQualityScoreMinimum = @Iteration-1

		Exec @myError = ComputeProteinCoverageWork @PMTQualityScoreMinimum, @ComputeProteinResidueCoverage, @numProteinsToProcess, @message OUTPUT

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

	End

Done:	
	return @myError


GO
