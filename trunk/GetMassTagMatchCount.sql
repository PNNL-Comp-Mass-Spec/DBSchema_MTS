/****** Object:  StoredProcedure [dbo].[GetMassTagMatchCount] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.GetMassTagMatchCount
/****************************************************************
**  Desc: Returns the number of mass tags matching the given filters
**
**  Return values: 0 if success, otherwise, error code 
**
**  Parameters: See comments below
**
**  Auth:	mem
**	Date:	09/09/2005
**			12/21/2005 mem - Addedparameter 
**			12/22/2005 mem - Added parameters @ExperimentFilter, @ExperimentExclusionFilter, and @JobToFilterOnByDataset
**			09/06/2006 mem - Added parameter @MinimumPeptideProphetProbability
**  
****************************************************************/
(
	@ConfirmedOnly tinyint = 0,					-- Mass Tag must have Is_Confirmed = 1
	@MinimumHighNormalizedScore float = 0,		-- The minimum value required for High_Normalized_Score; 0 to allow all
	@MinimumPMTQualityScore decimal(9,5) = 0,	-- The minimum PMT_Quality_Score to allow; 0 to allow all
	@MinimumHighDiscriminantScore real = 0,		-- The minimum High_Discriminant_Score to allow; 0 to allow all
	@ExperimentFilter varchar(64) = '',				-- If non-blank, then selects PMT tags from datasets with this experiment; ignored if @JobToFilterOnByDataset is non-zero
	@ExperimentExclusionFilter varchar(64) = '',	-- If non-blank, then excludes PMT tags from datasets with this experiment; ignored if @JobToFilterOnByDataset is non-zero
	@JobToFilterOnByDataset int = 0,				-- Set to a non-zero value to only select PMT tags from the dataset associated with the given MS job; useful for matching LTQ-FT MS data to peptides detected during the MS/MS portion of the same analysis; if the job is not present in T_FTICR_Analysis_Description then the count will be zero
	@MinimumPeptideProphetProbability real = 0		-- The minimum High_Peptide_Prophet_Probability value to allow; 0 to allow all
)
As
	Set NoCount On

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Declare @S varchar(1024)
	Declare @ScoreFilteringSQL varchar(256)
	Declare @ExperimentFilteringSQL varchar(256)
	
	Declare @Dataset varchar(128)
	Set @Dataset = ''

	---------------------------------------------------	
	-- Validate the input parameters
	---------------------------------------------------	
	Set @ConfirmedOnly = IsNull(@ConfirmedOnly, 0)
	Set @MinimumHighNormalizedScore = IsNull(@MinimumHighNormalizedScore, 0)
	Set @MinimumPMTQualityScore = IsNull(@MinimumPMTQualityScore, 0)
	Set @MinimumHighDiscriminantScore = IsNull(@MinimumHighDiscriminantScore, 0)
	Set @ExperimentFilter = IsNull(@ExperimentFilter, '')
	Set @ExperimentExclusionFilter = IsNull(@ExperimentExclusionFilter, '')
	Set @JobToFilterOnByDataset = IsNull(@JobToFilterOnByDataset, 0)
	Set @MinimumPeptideProphetProbability = IsNull(@MinimumPeptideProphetProbability, 0)

	---------------------------------------------------	
	-- Define the score filtering SQL
	---------------------------------------------------	

	Set @ScoreFilteringSQL = ''
	
	If @MinimumPMTQualityScore <> 0
		Set @ScoreFilteringSQL = @ScoreFilteringSQL + ' AND (IsNull(MT.PMT_Quality_Score, 0) >= ' +  Convert(varchar(11), @MinimumPMTQualityScore) + ') '

	If @MinimumHighDiscriminantScore <> 0
		Set @ScoreFilteringSQL = @ScoreFilteringSQL + ' AND (IsNull(MT.High_Discriminant_Score, 0) >= ' + Convert(varchar(11), @MinimumHighDiscriminantScore) + ') '

	If @MinimumPeptideProphetProbability <> 0
		Set @ScoreFilteringSQL = @ScoreFilteringSQL + ' AND (IsNull(MT.High_Peptide_Prophet_Probability, 0) >= ' + Convert(varchar(11), @MinimumPeptideProphetProbability) + ') '

	If @MinimumHighNormalizedScore <> 0
		Set @ScoreFilteringSQL = @ScoreFilteringSQL + ' AND (IsNull(MT.High_Normalized_Score, 0) >= ' +  Convert(varchar(11), @MinimumHighNormalizedScore) + ') '
	
	If @ConfirmedOnly <> 0
		Set @ScoreFilteringSQL = @ScoreFilteringSQL + ' AND (Is_Confirmed=1) '

	-- Remove ' AND' from the start of @ScoreFilteringSQL if non-blank
	If Len(@ScoreFilteringSQL) > 0
		Set @ScoreFilteringSQL = Substring(@ScoreFilteringSQL, 5, LEN(@ScoreFilteringSQL))


	---------------------------------------------------	
	-- Possibly add an experiment filter
	---------------------------------------------------	
	Set @ExperimentFilteringSQL = ''

	If Len(@ExperimentFilter) > 0
	Begin
		If CharIndex('%', @ExperimentFilter) = 0
			Set @ExperimentFilteringSQL = @ExperimentFilteringSQL + ' AND (TAD.Experiment LIKE ''%' + @ExperimentFilter + '%'')'
		Else
			Set @ExperimentFilteringSQL = @ExperimentFilteringSQL + ' AND (TAD.Experiment LIKE ''' + @ExperimentFilter + ''')'
	End

	If Len(@ExperimentExclusionFilter) > 0
	Begin
		If CharIndex('%', @ExperimentExclusionFilter) = 0
			Set @ExperimentFilteringSQL = @ExperimentFilteringSQL + ' AND (TAD.Experiment NOT LIKE ''%' + @ExperimentExclusionFilter + '%'')'
		Else
			Set @ExperimentFilteringSQL = @ExperimentFilteringSQL + ' AND (TAD.Experiment NOT LIKE ''' + @ExperimentExclusionFilter + ''')'
	End

	-- Remove ' AND' from the start of @ExperimentFilteringSQL if non-blank
	If Len(@ExperimentFilteringSQL) > 0
		Set @ExperimentFilteringSQL = Substring(@ExperimentFilteringSQL, 5, LEN(@ExperimentFilteringSQL))


	---------------------------------------------------	
	-- If @JobToFilterOnByDataset is non-zero, then lookup the details in T_FTICR_Analysis_Description
	---------------------------------------------------	
	If @JobToFilterOnByDataset <> 0
	Begin
		-- Lookup the dataset for @JobToFilterOnByDataset
		SELECT @Dataset = Dataset
		FROM T_FTICR_Analysis_Description
		WHERE Job = @JobToFilterOnByDataset
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @myRowCount = 0
		Begin
			-- Limiting to a job, but the job wasn't found; return a count of 0
			Set @S = 'SELECT 0 As TotalMassTags'
		End
		Else
		Begin
			Set @Dataset = IsNull(@Dataset, '')

			Set @S = ''
			Set @S = @S + ' SELECT COUNT(DISTINCT MT.Mass_Tag_ID) AS TotalMassTags'
			Set @S = @S + ' FROM T_Mass_Tags MT INNER JOIN'
			Set @S = @S +      ' T_Peptides P ON MT.Mass_Tag_ID = P.Mass_Tag_ID INNER JOIN'
			Set @S = @S +      ' T_Analysis_Description TAD ON P.Analysis_ID = TAD.Job'
			Set @S = @S + ' WHERE TAD.Dataset = ''' + @Dataset + ''''
			If Len(@ScoreFilteringSQL) > 0
				Set @S = @S + ' AND ' + @ScoreFilteringSQL
		End		
	End
	Else
	Begin
		If @ExperimentFilteringSQL = ''
		Begin
			Set @S = ''
			Set @S = @S + ' SELECT COUNT(Mass_Tag_ID) As TotalMassTags'
			Set @S = @S + ' FROM T_Mass_Tags MT'
			If Len(@ScoreFilteringSQL) > 0
				Set @S = @S + ' WHERE ' + @ScoreFilteringSQL
		End
		Else
		Begin
			Set @S = ''
			Set @S = @S + ' SELECT COUNT(DISTINCT MT.Mass_Tag_ID)'
			Set @S = @S + ' FROM T_Mass_Tags MT INNER JOIN'
			Set @S = @S +      ' T_Peptides P ON MT.Mass_Tag_ID = P.Mass_Tag_ID INNER JOIN'
			Set @S = @S +      ' T_Analysis_Description TAD ON P.Analysis_ID = TAD.Job'
			Set @S = @S + ' WHERE ' + @ExperimentFilteringSQL
			If Len(@ScoreFilteringSQL) > 0
				Set @S = @S + ' AND ' + @ScoreFilteringSQL
		End
	End

	Exec (@S)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

Done:
	Return @myError


GO
GRANT EXECUTE ON [dbo].[GetMassTagMatchCount] TO [DMS_SP_User]
GO
