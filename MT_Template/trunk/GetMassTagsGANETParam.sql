SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[GetMassTagsGANETParam]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[GetMassTagsGANETParam]
GO


CREATE PROCEDURE dbo.GetMassTagsGANETParam
/****************************************************************
**  Desc: Returns mass tags and NET values relevant for PMT peak matching
**
**  Return values: 0 if success, otherwise, error code 
**
**  Parameters: See comments below
**
**  Auth: mem
**	Date: 01/06/2004
**
**  Updated: 02/02/2004 mem - Now returning High_Normalized_Score in the 6th column of the output
**			 07/27/2004 mem - Now returning StD_GANET in the 7th column of the output
**			 09/21/2004 mem - Changed format of @MassCorrectionIDFilterList and removed parameters @AmtsOnly and @LockersOnly
**			 01/12/2004 mem - Now returning High_Discriminant_Score in the 8th column of the output
**			 02/05/2005 mem - Added parameters @MinimumHighDiscriminantScore, @ExperimentFilter, and @ExperimentExclusionFilter
**			 09/08/2005 mem - Now returning Number_of_Peptides in the 9th column of the output
**			 09/28/2005 mem - Switched to using Peptide_Obs_Count_Passing_Filter
 instead of Number_of_Peptides for the 9th column of data
**  
****************************************************************/
(
	@MassCorrectionIDFilterList varchar(255) = '',
											-- Mass tag modification masses inclusion list, leave blank or Null to include all mass tags
											-- Items in list can be of the form:  [Not] GlobModID/Any
											-- For example: 1014			will filter for Mass Tags containing Mod 1014
											--          or: 1014, 1010		will filter for Mass Tags containing Mod 1014 or Mod 1010
											--			or: Any				will filter for any and all mass tags, regardless of mods
											--			or: Not 1014		will filter for Mass Tags not containing Mod 1014 (including unmodified mass tags)
											--			or: Not Any			will filter for Mass Tags without modifications
											-- Note that GlobModID = 1 means no modification, and thus:
											--				1				will filter for Mass Tags without modifications (just like Not Any)
											--				Not 1			will filter for Mass Tags with modifications
											-- Mods are defined in T_Mass_Correction_Factors in DMS and are accessible via MT_Main.V_DMS_Mass_Correction_Factors
	@ConfirmedOnly tinyint = 0,				-- Mass Tag must have Is_Confirmed = 1
	@MinimumHighNormalizedScore float = 0,	-- The minimum value required for High_Normalized_Score; 0 to allow all
	@MinimumPMTQualityScore decimal(9,5) = 0,	-- The minimum PMT_Quality_Score to allow; 0 to allow all
	@NETValueType tinyint = 0,					-- 0 to use GANET values, 1 to use PNET values
	@MinimumHighDiscriminantScore real = 0,		-- The minimum High_Discriminant_Score to allow; 0 to allow all
	@ExperimentFilter varchar(64) = '',
	@ExperimentExclusionFilter varchar(64) = ''
)
As
	Set NoCount On

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Declare @BaseSql varchar(1024),
			@FullSql nvarchar(2048),
			@IsCriteriaSQL varchar(1024),
			@ScoreFilteringSQL varchar(256),
			@ExperimentFilteringSQL varchar(256)
			

	Declare @IncList varchar(1024),
			@CurrIncItem varchar(512),
			@NotString varchar(512),
			@MassCorrectionIDString varchar(512)

	Declare @DelimiterLoc int,			--delimiter position
			@MassCorrectionID int,		-- Mass_Correction_ID to filter on (or against)
			@MassCorrectionTag varchar(8),
			@LikeString varchar(25),
			@IsNot tinyint,				-- 1 if the ID is preceded by NOT
			@IsAny tinyint,				-- 1 if the ID is text text ANY
			@ModWhereString varchar(128)


	---------------------------------------------------	
	-- Create a temporary table to hold the list of mass tags that match the 
	-- inclusion list criteria and Is_Confirmed requirements
	---------------------------------------------------	
	CREATE TABLE #TmpMassTags (
		Mass_Tag_ID int
	)

	CREATE CLUSTERED INDEX #IX_TmpMassTags ON #TmpMassTags (Mass_Tag_ID ASC)

	
	---------------------------------------------------	
	-- Build criteria based on Is_* columns
	---------------------------------------------------	
	Set @IsCriteriaSQL = ''
	If @ConfirmedOnly <> 0
		Set @IsCriteriaSQL = ' (Is_Confirmed=1) '

	---------------------------------------------------	
	-- Build critera for High_Normalized_Score
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
	-- Possibly add an experiment filter
	---------------------------------------------------	
	Set @ExperimentFilteringSQL = ''
	If Len(IsNull(@ExperimentFilter, '')) > 0
		Set @ExperimentFilteringSQL = @ExperimentFilteringSQL + ' AND (T_Analysis_Description.Experiment LIKE ''%' + @ExperimentFilter + '%'')'


	If Len(IsNull(@ExperimentExclusionFilter, '')) > 0
		Set @ExperimentFilteringSQL = @ExperimentFilteringSQL + ' AND (T_Analysis_Description.Experiment NOT LIKE ''%' + @ExperimentExclusionFilter + '%'')'


	---------------------------------------------------	
	-- Construct the Base Sql
	---------------------------------------------------	
	Set @BaseSql = ''
	Set @BaseSql = @BaseSql + 'INSERT INTO #TmpMassTags '
	If @ExperimentFilteringSQL = ''
	Begin
		Set @BaseSql = @BaseSql + 'SELECT Mass_Tag_ID '
		Set @BaseSql = @BaseSql + 'FROM T_Mass_Tags '
		Set @BaseSql = @BaseSql + 'WHERE ' + @ScoreFilteringSQL
	End
	Else
	Begin
		Set @BaseSql = @BaseSql + 'SELECT DISTINCT T_Mass_Tags.Mass_Tag_ID '
		Set @BaseSql = @BaseSql + 'FROM T_Mass_Tags INNER JOIN T_Peptides ON T_Mass_Tags.Mass_Tag_ID = T_Peptides.Mass_Tag_ID INNER JOIN T_Analysis_Description ON T_Peptides.Analysis_ID = T_Analysis_Description.Job '
		Set @BaseSql = @BaseSql + 'WHERE ' + @ScoreFilteringSQL + @ExperimentFilteringSQL
	End
		
	-- Possibly narrow down the listing using Is Criteria
	If Len(@IsCriteriaSQL) > 0
		Set @BaseSql = @BaseSql + ' AND ' + @IsCriteriaSQL    


	---------------------------------------------------	
	-- Clean up @MassCorrectionIDFilterList
	---------------------------------------------------	
	Set @MassCorrectionIDFilterList = LTrim(RTrim(IsNull(@MassCorrectionIDFilterList, '')))
	
	-- Replace any semicolons in @MassCorrectionIDFilterList with commas
	Set @MassCorrectionIDFilterList = Replace(@MassCorrectionIDFilterList, ';', ',')
	
	-- Copy data from @MassCorrectionIDFilterList into @IncList
	Set @IncList = @MassCorrectionIDFilterList
	
	If Len(@IncList) > 0 And @IncList <> '-1'
	While Len(@IncList) > 0
	  Begin -- <a>
			---------------------------------------------------	
			-- Extract next inclusion item and build criteria
			---------------------------------------------------	
			Set @DelimiterLoc = CharIndex(',', @IncList)		
			If @DelimiterLoc > 0	--cleave inclusion list on first delimiter
			  Begin
				Set @CurrIncItem = RTrim(LTrim(SubString(@IncList, 1, @DelimiterLoc-1)))
				Set @IncList = RTrim(LTrim(SubString(@IncList, @DelimiterLoc+1, Len(@IncList)-@DelimiterLoc)))
			  End
			Else			--last inclusion item
			  Begin
				Set @CurrIncItem = RTrim(LTrim(@IncList))
				Set @IncList=''
			  End

			---------------------------------------------------	
			-- Populate temporary table with all Mass Tags containing the given Modification ID
			-- (or not containing the given ID)
			---------------------------------------------------	
			--
			-- @CurrIncItem should be of the form '1014'  or  'Not 1014'
			-- If it doesn't match this form, abort processing and do not return any mass tags


			Set @IsNot = 0
			Set @IsAny = 0
						
			Set @DelimiterLoc = CharIndex(' ', @CurrIncItem)
			If @DelimiterLoc > 0
			Begin
				-- Space is Present
				Set @NotString = RTrim(LTrim(SubString(@CurrIncItem, 1, @DelimiterLoc-1)))
				Set @MassCorrectionIDString = RTrim(LTrim(SubString(@CurrIncItem, @DelimiterLoc+1, Len(@CurrIncItem)-@DelimiterLoc)))
				If Upper(@NotString) = 'NOT'
					Set @IsNot = 1
			End
			Else
				Set @MassCorrectionIDString = @CurrIncItem
			

			If IsNumeric(@MassCorrectionIDString) <> 1
			Begin
				If Upper(@MassCorrectionIDString) = 'ANY'
					Set @IsAny = 1
				else
				Begin
					-- Invalid @CurrIncItem; do not return any mass tags
					Set @myError = 50000
					Goto Done
				End
			End

			If @IsAny = 0
			Begin
				---------------------------------------------------	
				-- Look up the Mass correction tag for this Mass Correction ID
				---------------------------------------------------	
				Set @MassCorrectionID = Convert(int, @MassCorrectionIDString)
				
				If @MassCorrectionID = 1
				Begin
					-- MassCorrectionID of 1 indicates no modification
					-- Not 1 indicates any modification (but, must be modified)
					
					If @IsNot = 0
						-- Construct list of Mass Tags that contain no modifications
						Set @ModWhereString = '(Mod_Count = 0)'
					Else
						-- Construct list of Mass Tags that contain a modification
						Set @ModWhereString = '(Mod_Count > 0)'
				End
				Else
				Begin
					SELECT @MassCorrectionTag = Mass_Correction_Tag
					FROM MT_Main..V_DMS_Mass_Correction_Factors
					WHERE Mass_Correction_ID = @MassCorrectionID
					--
					SELECT @myError = @@error, @myRowCount = @@rowcount
					
					If @myRowCount = 0
					Begin
						-- Invalid @MassCorrectionID; do not return any mass tags
						Set @myError = 50001
						Goto Done
					End


					Set @LikeString = '''%' + @MassCorrectionTag + ':%'''
				
					If @IsNot = 0
						-- Construct list of Mass Tags that contain @MassCorrectionTag
						Set @ModWhereString = '(Mod_Count > 0 AND Mod_Description LIKE ' + @LikeString + ')'
					Else
						-- Construct list of Mass Tags that do not contain @MassCorrectionTag (including unmodified ones)
						Set @ModWhereString = '(Mod_Count = 0 OR (Mod_Count > 0 AND Mod_Description NOT LIKE ' + @LikeString + '))'
				End
			End
			Else
			Begin
				---------------------------------------------------	
				-- @IsAny is 1
				---------------------------------------------------	
				If @IsNot = 0
					-- Match any and all Mass Tags
					Set @ModWhereString = '(Mod_Count >= 0)'
				Else
					-- Construct list of Mass Tags that are not modified
					Set @ModWhereString = '(Mod_Count = 0)'
				
			End			
			
			-- Create Sql to obtain the list of mass tags that contain the given modification
			Set @FullSql = Convert(nvarchar(2048), @BaseSql + ' AND ' + @ModWhereString)

			-- Execute the Sql to add mass tags to #TmpMassTags
			EXECUTE sp_executesql @FullSql
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--
			If @MyError <> 0
				Goto Done

	  End -- </a>
	Else
	  Begin

		---------------------------------------------------	
		-- Do not filter on Modifications
		---------------------------------------------------	
		
		Set @FullSql = Convert(nvarchar(2048), @BaseSql)
		
		-- Execute the Sql to add mass tags to #TmpMassTags
		EXECUTE sp_executesql @FullSql
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		If @MyError <> 0
			Goto Done
	  End   

	---------------------------------------------------
	-- Join the data in #TmpMassTags with T_Mass_Tags
	-- and T_Mass_Tags_NET
	---------------------------------------------------
	
	If @NETValueType < 0 or @NETValueType > 1
		Set @NETValueType = 0
	  
	If @NETValueType = 0
		-- Return Avg_GANET as Net_Value_To_Use
		SELECT DISTINCT
			MT.Mass_Tag_ID, 
			MT.Peptide, 
			MT.Monoisotopic_Mass, 
			MTN.Avg_GANET As Net_Value_to_Use, 
			MTN.PNET, 
			MT.High_Normalized_Score, 
			MTN.StD_GANET,
			MT.High_Discriminant_Score,
			MT.Peptide_Obs_Count_Passing_Filter

		FROM #TmpMassTags 
			INNER JOIN T_Mass_Tags AS MT ON #TmpMassTags.Mass_Tag_ID = MT.Mass_Tag_ID
			INNER JOIN T_Mass_Tags_NET AS MTN ON #TmpMassTags.Mass_Tag_ID = MTN.Mass_Tag_ID
		ORDER BY MT.Monoisotopic_Mass
	Else
		-- Return PNET as Net_Value_To_Use
		SELECT DISTINCT
			MT.Mass_Tag_ID, 
			MT.Peptide, 
			MT.Monoisotopic_Mass, 
			MTN.Avg_GANET As Net_Value_to_Use, 
			MTN.PNET, 
			MT.High_Normalized_Score, 
			MTN.StD_GANET,
			MT.High_Discriminant_Score,
			MT.Peptide_Obs_Count_Passing_Filter

		FROM #TmpMassTags 
			INNER JOIN T_Mass_Tags AS MT ON #TmpMassTags.Mass_Tag_ID = MT.Mass_Tag_ID
			INNER JOIN T_Mass_Tags_NET AS MTN ON #TmpMassTags.Mass_Tag_ID = MTN.Mass_Tag_ID
		ORDER BY MT.Monoisotopic_Mass

	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


Done:
	Return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[GetMassTagsGANETParam]  TO [DMS_SP_User]
GO

