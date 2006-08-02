SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[GetThresholdsForFilterSet]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[GetThresholdsForFilterSet]
GO


CREATE PROCEDURE dbo.GetThresholdsForFilterSet
/****************************************************
**
**	Desc: 
**		Returns thresholds for given filter set ID
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**		Auth: mem
**		Date: 08/24/2004
**		 8/28/2004 grk - accounted for V_DMS_Filter_Sets_Import moving to MT_Main
**		 9/10/2004 mem - Added @DiscriminantInitialFilter criteria
**		 9/19/2004 mem - Added @ProteinCount criteria
**		 3/26/2005 mem - Added @TerminusState criteria
**    
*****************************************************/
	@FilterSetID int,
	@CriteriaGroupStart int=0,								-- If > 0, then will return the entries for this Filter Set having Filter_Criteria_Group >= @CriterionOrderStart

	@CriteriaGroupMatch int=0 output,						-- > 0 if the @FilterSetID and @CriteriaGroupStart resolve to a valid set of criteria
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
	@TerminusStateThreshold tinyint=0 output

As
	set nocount on
	
	declare @myRowCount int,
			@myError int
	set @myRowCount = 0
	set @myError = 0

	declare @matchCount int
	Set @matchCount = 0

	--------------------------------	
	-- Set default return values
	--
	Set @CriteriaGroupMatch = 0
	Set @message = ''

	Set @SpectrumCountComparison = '>='
	Set @SpectrumCountThreshold = 0

	Set @ChargeStateComparison = '>='
	Set @ChargeStateThreshold = 0

	Set @HighNormalizedScoreComparison = '>='
	Set @HighNormalizedScoreThreshold = 0

	Set @CleavageStateComparison = '>='
	Set @CleavageStateThreshold = 0

	Set @PeptideLengthComparison = '>='
	Set @PeptideLengthThreshold = 0

	Set @MassComparison = '>='
	Set @MassThreshold = 0

	Set @DeltaCnComparison = '<='
	Set @DeltaCnThreshold = 1

	Set @DeltaCn2Comparison = '>='
	Set @DeltaCn2Threshold = 0

	Set @DiscriminantScoreComparison = '>='
	Set @DiscriminantScoreThreshold = 0

	Set @NETDifferenceAbsoluteComparison = '<='
	Set @NETDifferenceAbsoluteThreshold = 100

	Set @DiscriminantInitialFilterComparison = '>='
	Set @DiscriminantInitialFilterThreshold = 0
	
	Set @ProteinCountComparison = '>='
	Set @ProteinCountThreshold = 0

	Set @TerminusStateComparison = '>='
	Set @TerminusStateThreshold = 0
	
	--------------------------------	
	-- Validate @FilterSetID
	--
	SELECT @matchCount = COUNT(*)
	FROM MT_Main..V_DMS_Filter_Sets_Import
	WHERE Filter_Set_ID = @FilterSetID
	--
	SELECT @myError = @@error, @myRowCount = @@RowCount
	--
	if @myError <> 0
	begin
		set @message = 'Could not validate filter set ID ' + Convert(varchar(11), @FilterSetID) + ' in MT_Main..V_DMS_Filter_Sets_Import'		
		goto Done
	end
	
	if @matchCount = 0 
	begin
		set @message = 'Filter set ID ' + Convert(varchar(11), @FilterSetID) + ' not found in MT_Main..V_DMS_Filter_Sets_Import'
		set @myError = 201
		goto Done
	end

	--------------------------------	
	-- See if any criteria are defined for this filter set, 
	--  having Filter_Criteria_Group >= @CriteriaGroupStart	
	-- 
	Set @CriteriaGroupMatch = 0
	
	SELECT @CriteriaGroupMatch = MIN(Filter_Criteria_Group_ID)
	FROM MT_Main..V_DMS_Filter_Sets_Import
	WHERE Filter_Set_ID = @FilterSetID AND Filter_Criteria_Group_ID >= @CriteriaGroupStart
	GROUP BY Filter_Set_ID
	--
	SELECT @myError = @@error, @myRowCount = @@RowCount
	
	If @myRowCount > 0
	Begin

		--------------------------------	
		-- Lookup thresholds
		SELECT TOP 1 @SpectrumCountComparison = Criterion_Comparison,
					 @SpectrumCountThreshold = Criterion_Value
		FROM MT_Main..V_DMS_Filter_Sets_Import
		WHERE Filter_Set_ID = @FilterSetID AND
			  Filter_Criteria_Group_ID = @CriteriaGroupMatch AND Criterion_ID = 1		-- Spectrum_Count
		--
		set @myError = @@Error
		
		If @myError <> 0
		begin
			set @message = 'Error looking up Spectrum Count threshold for Filter Set ID ' + Convert(varchar(11), @FilterSetID) + ' and Filter_Criteria_Group_ID ' + convert(varchar(11), @CriteriaGroupMatch) + ' in MT_Main..V_DMS_Filter_Sets_Import'
			goto Done
		end

		SELECT TOP 1 @SpectrumCountComparison = Criterion_Comparison,
					 @SpectrumCountThreshold = Criterion_Value
		FROM MT_Main..V_DMS_Filter_Sets_Import
		WHERE Filter_Set_ID = @FilterSetID AND
			  Filter_Criteria_Group_ID = @CriteriaGroupMatch AND Criterion_ID = 1		-- Spectrum_Count
	
		SELECT TOP 1 @ChargeStateComparison = Criterion_Comparison,
					 @ChargeStateThreshold = Criterion_Value
		FROM MT_Main..V_DMS_Filter_Sets_Import
		WHERE Filter_Set_ID = @FilterSetID AND
				Filter_Criteria_Group_ID = @CriteriaGroupMatch AND Criterion_ID = 2		-- Charge

		SELECT TOP 1 @HighNormalizedScoreComparison = Criterion_Comparison,
					 @HighNormalizedScorethreshold = Criterion_Value
		FROM MT_Main..V_DMS_Filter_Sets_Import
		WHERE Filter_Set_ID = @FilterSetID AND
				Filter_Criteria_Group_ID = @CriteriaGroupMatch AND Criterion_ID = 3		-- High_Normalized_Score

		SELECT TOP 1 @CleavageStateComparison = Criterion_Comparison,
					 @CleavageStateThreshold = Criterion_Value
		FROM MT_Main..V_DMS_Filter_Sets_Import
		WHERE Filter_Set_ID = @FilterSetID AND
				Filter_Criteria_Group_ID = @CriteriaGroupMatch AND Criterion_ID = 4		-- Cleavage_State

		SELECT TOP 1 @PeptideLengthComparison = Criterion_Comparison,
					 @PeptideLengthThreshold = Criterion_Value
		FROM MT_Main..V_DMS_Filter_Sets_Import
		WHERE Filter_Set_ID = @FilterSetID AND
				Filter_Criteria_Group_ID = @CriteriaGroupMatch AND Criterion_ID = 5		-- Peptide_Length

		SELECT TOP 1 @MassComparison = Criterion_Comparison,
					 @MassThreshold = Criterion_Value
		FROM MT_Main..V_DMS_Filter_Sets_Import
		WHERE Filter_Set_ID = @FilterSetID AND
				Filter_Criteria_Group_ID = @CriteriaGroupMatch AND Criterion_ID = 6		-- Mass

		SELECT TOP 1 @DeltaCnComparison = Criterion_Comparison,
					 @DeltaCnThreshold = Criterion_Value
		FROM MT_Main..V_DMS_Filter_Sets_Import
		WHERE Filter_Set_ID = @FilterSetID AND
				Filter_Criteria_Group_ID = @CriteriaGroupMatch AND Criterion_ID = 7		-- DeltaCn

		SELECT TOP 1 @DeltaCn2Comparison = Criterion_Comparison,
					 @DeltaCn2Threshold = Criterion_Value
		FROM MT_Main..V_DMS_Filter_Sets_Import
		WHERE Filter_Set_ID = @FilterSetID AND
				Filter_Criteria_Group_ID = @CriteriaGroupMatch AND Criterion_ID = 8		-- DeltaCn2

		SELECT TOP 1 @DiscriminantScoreComparison = Criterion_Comparison,
					 @DiscriminantScoreThreshold = Criterion_Value
		FROM MT_Main..V_DMS_Filter_Sets_Import
		WHERE Filter_Set_ID = @FilterSetID AND
				Filter_Criteria_Group_ID = @CriteriaGroupMatch AND Criterion_ID = 9		-- Discriminant_Score

		SELECT TOP 1 @NETDifferenceAbsoluteComparison = Criterion_Comparison,
					 @NETDifferenceAbsoluteThreshold = Criterion_Value
		FROM MT_Main..V_DMS_Filter_Sets_Import
		WHERE Filter_Set_ID = @FilterSetID AND
				Filter_Criteria_Group_ID = @CriteriaGroupMatch AND Criterion_ID = 10	-- NET_Difference_Absolute

		SELECT TOP 1 @DiscriminantInitialFilterComparison = Criterion_Comparison,
					 @DiscriminantInitialFilterThreshold = Criterion_Value
		FROM MT_Main..V_DMS_Filter_Sets_Import
		WHERE Filter_Set_ID = @FilterSetID AND
				Filter_Criteria_Group_ID = @CriteriaGroupMatch AND Criterion_ID = 11	-- Discriminant_Initial_Filter

		SELECT TOP 1 @ProteinCountComparison = Criterion_Comparison,
					 @ProteinCountThreshold = Criterion_Value
		FROM MT_Main..V_DMS_Filter_Sets_Import
		WHERE Filter_Set_ID = @FilterSetID AND
				Filter_Criteria_Group_ID = @CriteriaGroupMatch AND Criterion_ID = 12	-- Protein_Count

		SELECT TOP 1 @TerminusStateComparison = Criterion_Comparison,
					 @TerminusStateThreshold = Criterion_Value
		FROM MT_Main..V_DMS_Filter_Sets_Import
		WHERE Filter_Set_ID = @FilterSetID AND
				Filter_Criteria_Group_ID = @CriteriaGroupMatch AND Criterion_ID = 13	-- Terminus_State
					 
	End


Done:
	
	Return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

