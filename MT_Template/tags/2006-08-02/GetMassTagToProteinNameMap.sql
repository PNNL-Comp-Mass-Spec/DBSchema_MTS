SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[GetMassTagToProteinNameMap]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[GetMassTagToProteinNameMap]
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
**			02/05/2005 mem - Added @MinimumHighDiscriminantScore
**			07/25/2006 mem - Updated to utilize new columns in V_IFC_Mass_Tag_to_Protein_Name_Map
**  
****************************************************************/
(
	@ConfirmedOnly tinyint = 0,					-- Mass Tag must have Is_Confirmed = 1
	@MinimumHighNormalizedScore float = 0,		-- The minimum value required for High_Normalized_Score; 0 to allow all
	@MinimumPMTQualityScore float = 0,			-- The minimum PMT_Quality_Score to allow; 0 to allow all
	@MinimumHighDiscriminantScore real = 0		-- The minimum High_Discriminant_Score to allow; 0 to allow all
)
As
	Set NoCount On

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Declare @S nvarchar(1024),
			@IsCriteriaSQL varchar(1024),
			@ScoreFilteringSQL varchar(256)


	---------------------------------------------------	
	-- Build criteria based on Is_* columns
	---------------------------------------------------	
	Set @IsCriteriaSQL = ''
	If @ConfirmedOnly <> 0
		Set @IsCriteriaSQL = ' (Is_Confirmed=1) '

	---------------------------------------------------	
	-- Build critera for High_Discriminant_Score and PMT_Quality_Score
	---------------------------------------------------	
	Set @ScoreFilteringSQL = ''
	Set @ScoreFilteringSQL = @ScoreFilteringSQL + ' (IsNull(High_Discriminant_Score, 0) >= ' + CAST(@MinimumHighDiscriminantScore as varchar(11)) + ') '
	Set @ScoreFilteringSQL = @ScoreFilteringSQL + ' AND (IsNull(PMT_Quality_Score, 0) >= ' + CAST(@MinimumPMTQualityScore as varchar(11)) + ') '

	---------------------------------------------------	
	-- Possibly add High Normalized Score
	-- It isn't indexed; thus only add it to @ScoreFilteringSQL if it is non-zero
	---------------------------------------------------	
	If @MinimumHighNormalizedScore <> 0
		Set @ScoreFilteringSQL = @ScoreFilteringSQL + ' AND (IsNull(High_Normalized_Score, 0) >= ' + CAST(@MinimumHighNormalizedScore as varchar(11)) + ') '

	---------------------------------------------------	
	-- Construct the Base Sql
	---------------------------------------------------	
	Set @S = ''
	Set @S = @S + ' SELECT PNM.Mass_Tag_ID,'
	Set @S = @S +        ' CASE WHEN IsNull(PNM.Protein_DB_ID, -1) = 0'
	Set @S = @S +        ' THEN PNM.External_Protein_ID'
	Set @S = @S +        ' ELSE PNM.External_Reference_ID'
	Set @S = @S +        ' END AS Protein_ID,'
	Set @S = @S +        ' PNM.Reference'
	Set @S = @S + ' FROM T_Mass_Tags MT INNER JOIN'
    Set @S = @S + ' V_IFC_Mass_Tag_to_Protein_Name_Map PNM ON '
    Set @S = @S + ' MT.Mass_Tag_ID = PNM.Mass_Tag_ID'
	Set @S = @S + ' WHERE ' + @ScoreFilteringSQL
    
	-- Possibly narrow down the listing using Is Criteria
	If Len(@IsCriteriaSQL) > 0
		Set @S = @S + ' AND ' + @IsCriteriaSQL    

	-- Execute the Sql to return the results
	EXECUTE sp_executesql @S
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

Done:
	Return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[GetMassTagToProteinNameMap]  TO [DMS_SP_User]
GO

