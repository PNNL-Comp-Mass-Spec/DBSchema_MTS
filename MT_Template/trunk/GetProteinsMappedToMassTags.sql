/****** Object:  StoredProcedure [dbo].[GetProteinsMappedToMassTags] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.GetProteinsMappedToMassTags
/****************************************************************
**
**  Desc: Returns protein names, descriptions, and stats for the 
**		  mass tags that match the given filters
**
**  Return values: 0 if success, otherwise, error code 
**
**  Auth:	mem
**	Date:	05/29/2007
**  
****************************************************************/
(
	@ConfirmedOnly tinyint = 0,						-- Set to 1 to only include MTs with Is_Confirmed = 1
	@MinimumHighNormalizedScore real = 0,			-- The minimum value required for High_Normalized_Score; 0 to allow all
	@MinimumPMTQualityScore real = 0,				-- The minimum PMT_Quality_Score to allow; 0 to allow all
	@MinimumHighDiscriminantScore real = 0,			-- The minimum High_Discriminant_Score to allow; 0 to allow all
	@MinimumPeptideProphetProbability real = 0,		-- The minimum High_Peptide_Prophet_Probability to allow; 0 to allow all
	@MassTagIDList varchar(max) = '',				-- If defined, then returns the proteins mapped to the given mass tags; the @ConfirmedOnly and @Minimum... parameters are ignored if a list of Mass Tag IDs is provided
	@IncludeProteinSequence tinyint = 0,
	@PreviewSql tinyint = 0
)
As
	Set NoCount On

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Declare @S nvarchar(max)
	Declare @ScoreFilteringSQL varchar(512)

	---------------------------------------------------	
	-- Validate the inputs
	---------------------------------------------------	
	Set @ConfirmedOnly = IsNull(@ConfirmedOnly, 0)
	Set @MinimumHighNormalizedScore = IsNull(@MinimumHighNormalizedScore, 0)
	Set @MinimumPMTQualityScore = IsNull(@MinimumPMTQualityScore, 0)
	Set @MinimumHighDiscriminantScore = IsNull(@MinimumHighDiscriminantScore, 0)
	Set @MinimumPeptideProphetProbability = IsNull(@MinimumPeptideProphetProbability, 0)
	
	Set @MassTagIDList = LTrim(RTrim(IsNull(@MassTagIDList, '')))
	Set @IncludeProteinSequence = IsNull(@IncludeProteinSequence, 0)
	Set @PreviewSql = IsNull(@PreviewSql, 0)
		
	---------------------------------------------------	
	-- Define the score filtering SQL
	---------------------------------------------------	

	Set @ScoreFilteringSQL = ''
	
	If Len(@MassTagIDList) = 0
	Begin
		If @MinimumPMTQualityScore <> 0
			Set @ScoreFilteringSQL = @ScoreFilteringSQL + ' AND (IsNull(MT.PMT_Quality_Score, 0) >= ' +  Convert(varchar(11), @MinimumPMTQualityScore) + ') '

		If @MinimumHighDiscriminantScore <> 0
			Set @ScoreFilteringSQL = @ScoreFilteringSQL + ' AND (IsNull(MT.High_Discriminant_Score, 0) >= ' + Convert(varchar(11), @MinimumHighDiscriminantScore) + ') '

		If @MinimumPeptideProphetProbability <> 0
			Set @ScoreFilteringSQL = @ScoreFilteringSQL + ' AND (IsNull(MT.High_Peptide_Prophet_Probability, 0) >= ' + Convert(varchar(11), @MinimumPeptideProphetProbability) + ') '

		If @MinimumHighNormalizedScore <> 0
			Set @ScoreFilteringSQL = @ScoreFilteringSQL + ' AND (IsNull(MT.High_Normalized_Score, 0) >= ' +  Convert(varchar(11), @MinimumHighNormalizedScore) + ') '
		
		If @ConfirmedOnly <> 0
			Set @ScoreFilteringSQL = @ScoreFilteringSQL + ' AND (MT.Is_Confirmed=1) '

		-- Remove ' AND' from the start of @ScoreFilteringSQL if non-blank
		If Len(@ScoreFilteringSQL) > 0
			Set @ScoreFilteringSQL = Substring(@ScoreFilteringSQL, 5, LEN(@ScoreFilteringSQL))
	End
	
	---------------------------------------------------	
	-- Construct the Base Sql
	---------------------------------------------------	

	Set @S = ''
	Set @S = @S + ' SELECT Prot.Reference, Prot.Description, Prot.Ref_ID, '
	Set @S = @S +        ' Prot.External_Reference_ID, Prot.External_Protein_ID,'
	Set @S = @S +        ' Prot.Protein_Residue_Count, Prot.Monoisotopic_Mass'
	If @IncludeProteinSequence <> 0
		Set @S = @S +        ',Prot.Protein_Sequence'

	Set @S = @S + ' FROM ( SELECT Prot.Ref_ID'
	Set @S = @S +        ' FROM T_Mass_Tags MT INNER JOIN'
    Set @S = @S +             ' T_Mass_Tag_to_Protein_Map MTPM ON MT.Mass_Tag_ID = MTPM.Mass_Tag_ID INNER JOIN'
    Set @S = @S +             ' T_Proteins Prot ON MTPM.Ref_ID = Prot.Ref_ID'
    If Len(@MassTagIDList) > 0
    Begin
		Set @S = @S +    ' WHERE MT.Mass_Tag_ID IN (' + @MassTagIDList + ')'
	End
    Else
    Begin
		If Len(@ScoreFilteringSQL) > 0    
			Set @S = @S + ' WHERE ' + @ScoreFilteringSQL
	End
	Set @S = @S +        ' GROUP BY Prot.Ref_ID'
	Set @S = @S +        ' ) Src'
	Set @S = @S +      ' INNER JOIN T_Proteins Prot ON Src.Ref_ID = Prot.Ref_ID'
	Set @S = @S + ' ORDER BY Prot.Reference'
	
	If @PreviewSql <> 0
		Print @S
	Else
		EXECUTE sp_executesql @S
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

Done:
	Return @myError


GO
GRANT EXECUTE ON [dbo].[GetProteinsMappedToMassTags] TO [DMS_SP_User]
GO
