/****** Object:  StoredProcedure [dbo].[GetMassTagToProteinNameMap] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.GetMassTagToProteinNameMap
/****************************************************************
**  Desc: Returns mass tags and protein names, optionally filtering
**		  on IsConfirmed, HighNormalizedScore, or PMTQualityScore
**
**  Return values: 0 if success, otherwise, error code 
**
**  Parameters: See comments below
**
**  Auth:	mem
**	Date:	12/31/2004
**			02/05/2005 mem - Added parameter @MinimumHighDiscriminantScore
**			07/25/2006 mem - Updated to utilize new columns in V_IFC_Mass_Tag_to_Protein_Name_Map
**			10/09/2006 mem - Added parameter @MinimumPeptideProphetProbability and updated @ScoreFilteringSQL to match GetMassTagsGANETParam
**			05/29/2007 mem - Now returning Ref_ID
**  
****************************************************************/
(
	@ConfirmedOnly tinyint = 0,					-- Mass Tag must have Is_Confirmed = 1
	@MinimumHighNormalizedScore float = 0,		-- The minimum value required for High_Normalized_Score; 0 to allow all
	@MinimumPMTQualityScore float = 0,			-- The minimum PMT_Quality_Score to allow; 0 to allow all
	@MinimumHighDiscriminantScore real = 0,		-- The minimum High_Discriminant_Score to allow; 0 to allow all
	@MinimumPeptideProphetProbability real = 0	-- The minimum High_Peptide_Prophet_Probability to allow; 0 to allow all
)
As
	Set NoCount On

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Declare @S nvarchar(1024)
	Declare @ScoreFilteringSQL varchar(256)

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
		Set @ScoreFilteringSQL = @ScoreFilteringSQL + ' AND (MT.Is_Confirmed=1) '

	-- Remove ' AND' from the start of @ScoreFilteringSQL if non-blank
	If Len(@ScoreFilteringSQL) > 0
		Set @ScoreFilteringSQL = Substring(@ScoreFilteringSQL, 5, LEN(@ScoreFilteringSQL))

	---------------------------------------------------	
	-- Construct the Base Sql
	---------------------------------------------------	
	Set @S = ''
	Set @S = @S + ' SELECT PNM.Mass_Tag_ID,'
	Set @S = @S +        ' CASE WHEN IsNull(PNM.Protein_DB_ID, -1) = 0'
	Set @S = @S +        ' THEN PNM.External_Protein_ID'
	Set @S = @S +        ' ELSE PNM.External_Reference_ID'
	Set @S = @S +        ' END AS Protein_ID,'
	Set @S = @S +        ' PNM.Reference,'
	Set @S = @S +        ' PNM.Internal_Ref_ID AS Ref_ID'
	Set @S = @S + ' FROM T_Mass_Tags MT INNER JOIN'
    Set @S = @S +      ' V_IFC_Mass_Tag_to_Protein_Name_Map PNM ON '
    Set @S = @S +      ' MT.Mass_Tag_ID = PNM.Mass_Tag_ID'
	If Len(@ScoreFilteringSQL) > 0    
		Set @S = @S + ' WHERE ' + @ScoreFilteringSQL

	-- Execute the Sql to return the results
	EXECUTE sp_executesql @S
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

Done:
	Return @myError


GO
GRANT EXECUTE ON [dbo].[GetMassTagToProteinNameMap] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetMassTagToProteinNameMap] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetMassTagToProteinNameMap] TO [MTS_DB_Lite] AS [dbo]
GO
