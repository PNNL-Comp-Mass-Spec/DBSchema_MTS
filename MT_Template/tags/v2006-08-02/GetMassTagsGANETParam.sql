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
**  Auth:	mem
**	Date:	01/06/2004
**			02/02/2004 mem - Now returning High_Normalized_Score in the 6th column of the output
**			07/27/2004 mem - Now returning StD_GANET in the 7th column of the output
**			09/21/2004 mem - Changed format of @MassCorrectionIDFilterList and removed parameters @AmtsOnly and @LockersOnly
**			01/12/2004 mem - Now returning High_Discriminant_Score in the 8th column of the output
**			02/05/2005 mem - Added parameters @MinimumHighDiscriminantScore, @ExperimentFilter, and @ExperimentExclusionFilter
**			09/08/2005 mem - Now returning Number_of_Peptides in the 9th column of the output
**			09/28/2005 mem - Switched to using Peptide_Obs_Count_Passing_Filter instead of Number_of_Peptides for the 9th column of data
**			12/22/2005 mem - Added parameter @JobToFilterOnByDataset
**			06/08/2006 mem - Now returning Mod_Count and Mod_Description as the 10th and 11th columns
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
	@ExperimentFilter varchar(64) = '',				-- If non-blank, then selects PMT tags from datasets with this experiment; ignored if @JobToFilterOnByDataset is non-zero
	@ExperimentExclusionFilter varchar(64) = '',	-- If non-blank, then excludes PMT tags from datasets with this experiment; ignored if @JobToFilterOnByDataset is non-zero
	@JobToFilterOnByDataset int = 0					-- Set to a non-zero value to only select PMT tags from the dataset associated with the given MS job; useful for matching LTQ-FT MS data to peptides detected during the MS/MS portion of the same analysis; if the job is not present in T_FTICR_Analysis_Description then no data is returned
)
As
	Set NoCount On

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Declare @BaseSql varchar(1024),
			@FullSql nvarchar(2048),
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

	Declare @Dataset varchar(128)
	Set @Dataset = ''
	
	---------------------------------------------------	
	-- Validate the input parameters
	---------------------------------------------------	
	-- @MassCorrectionIDFilterList is validated below
	Set @ConfirmedOnly = IsNull(@ConfirmedOnly, 0)
	Set @MinimumHighNormalizedScore = IsNull(@MinimumHighNormalizedScore, 0)
	Set @MinimumPMTQualityScore = IsNull(@MinimumPMTQualityScore, 0)
	Set @NETValueType = IsNull(@NETValueType, 0)
	Set @MinimumHighDiscriminantScore = IsNull(@MinimumHighDiscriminantScore, 0)
	Set @ExperimentFilter = IsNull(@ExperimentFilter, '')
	Set @ExperimentExclusionFilter = IsNull(@ExperimentExclusionFilter, '')
	Set @JobToFilterOnByDataset = IsNull(@JobToFilterOnByDataset, 0)


	---------------------------------------------------	
	-- Create a temporary table to hold the list of mass tags that match the 
	-- inclusion list criteria and Is_Confirmed requirements
	---------------------------------------------------	
	CREATE TABLE #TmpMassTags (
		Mass_Tag_ID int
	)

	CREATE CLUSTERED INDEX #IX_TmpMassTags ON #TmpMassTags (Mass_Tag_ID ASC)

	---------------------------------------------------	
	-- Define the score filtering SQL
	---------------------------------------------------	

	Set @ScoreFilteringSQL = ''
	Set @ScoreFilteringSQL = @ScoreFilteringSQL + ' (IsNull(MT.High_Discriminant_Score, 0) >= ' + Convert(varchar(11), @MinimumHighDiscriminantScore) + ') '
	Set @ScoreFilteringSQL = @ScoreFilteringSQL + ' AND (IsNull(MT.PMT_Quality_Score, 0) >= ' +  Convert(varchar(11), @MinimumPMTQualityScore) + ') '
	If @ConfirmedOnly <> 0
		Set @ScoreFilteringSQL = @ScoreFilteringSQL + ' AND (Is_Confirmed=1) '

	---------------------------------------------------	
	-- Possibly add High Normalized Score
	-- It isn't indexed; thus only add it to @ScoreFilteringSQL if it is non-zero
	---------------------------------------------------	
	If @MinimumHighNormalizedScore <> 0
		Set @ScoreFilteringSQL = @ScoreFilteringSQL + ' AND (IsNull(MT.High_Normalized_Score, 0) >= ' +  Convert(varchar(11), @MinimumHighNormalizedScore) + ') '


	---------------------------------------------------	
	-- Possibly add an experiment filter
	---------------------------------------------------	
	Set @ExperimentFilteringSQL = ''
	If Len(@ExperimentFilter) > 0
		Set @ExperimentFilteringSQL = @ExperimentFilteringSQL + ' AND (TAD.Experiment LIKE ''%' + @ExperimentFilter + '%'')'


	If Len(@ExperimentExclusionFilter) > 0
		Set @ExperimentFilteringSQL = @ExperimentFilteringSQL + ' AND (TAD.Experiment NOT LIKE ''%' + @ExperimentExclusionFilter + '%'')'


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
			-- Limiting to a job, but the job wasn't found; return an error
			-- Note that error 50002 is used by external software to recognize an invalid job, so do not change the error code
			Set @myError = 50002
			Goto Done
		End
	End
	

	---------------------------------------------------	
	-- Construct the Base Sql
	---------------------------------------------------	
	Set @BaseSql = ''
	Set @BaseSql = @BaseSql + 'INSERT INTO #TmpMassTags (Mass_Tag_ID)'

	If @JobToFilterOnByDataset <> 0
	Begin
		Set @BaseSql = @BaseSql + ' SELECT DISTINCT MT.Mass_Tag_ID'
		Set @BaseSql = @BaseSql + ' FROM T_Mass_Tags MT INNER JOIN'
		Set @BaseSql = @BaseSql +      ' T_Peptides P ON MT.Mass_Tag_ID = P.Mass_Tag_ID INNER JOIN'
		Set @BaseSql = @BaseSql +      ' T_Analysis_Description TAD ON P.Analysis_ID = TAD.Job'
		Set @BaseSql = @BaseSql + ' WHERE TAD.Dataset = ''' + @Dataset + ''' AND ' + @ScoreFilteringSQL
	End
	Else
	Begin
		If @ExperimentFilteringSQL = ''
		Begin
			Set @BaseSql = @BaseSql + ' SELECT Mass_Tag_ID'
			Set @BaseSql = @BaseSql + ' FROM T_Mass_Tags MT'
			Set @BaseSql = @BaseSql + ' WHERE ' + @ScoreFilteringSQL
		End
		Else
		Begin
			Set @BaseSql = @BaseSql + ' SELECT DISTINCT MT.Mass_Tag_ID'
			Set @BaseSql = @BaseSql + ' FROM T_Mass_Tags MT INNER JOIN'
			Set @BaseSql = @BaseSql +      ' T_Peptides P ON MT.Mass_Tag_ID = P.Mass_Tag_ID INNER JOIN'
			Set @BaseSql = @BaseSql +      ' T_Analysis_Description TAD ON P.Analysis_ID = TAD.Job'
			Set @BaseSql = @BaseSql + ' WHERE ' + @ScoreFilteringSQL + @ExperimentFilteringSQL
		End
	End

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

	If @JobToFilterOnByDataset <> 0
		SELECT	MT.Mass_Tag_ID, 
				MT.Peptide, 
				MT.Monoisotopic_Mass, 
				CASE WHEN @NETValueType = 1
				THEN MTN.PNET
				ELSE MIN(P.GANET_Obs) 
				END As Net_Value_to_Use, 
				MTN.PNET,
				MT.High_Normalized_Score, 
				0 AS StD_GANET,
				MT.High_Discriminant_Score, 
				MT.Peptide_Obs_Count_Passing_Filter,
				MT.Mod_Count,
				MT.Mod_Description
		FROM #TmpMassTags
			 INNER JOIN T_Mass_Tags MT ON #TmpMassTags.Mass_Tag_ID = MT.Mass_Tag_ID 
			 INNER JOIN T_Peptides P ON MT.Mass_Tag_ID = P.Mass_Tag_ID 
			 INNER JOIN T_Mass_Tags_NET MTN ON MT.Mass_Tag_ID = MTN.Mass_Tag_ID 
			 INNER JOIN T_Analysis_Description TAD ON P.Analysis_ID = TAD.Job
		WHERE TAD.Dataset = @Dataset AND
				P.Max_Obs_Area_In_Job = 1
		GROUP BY MT.Mass_Tag_ID, MT.Peptide, MT.Monoisotopic_Mass, 
					MT.High_Normalized_Score, MT.High_Discriminant_Score, 
					MT.Peptide_Obs_Count_Passing_Filter, MT.Mod_Count, MT.Mod_Description, MTN.PNET
		ORDER BY MT.Monoisotopic_Mass
	Else
		-- Return Avg_GANET as Net_Value_To_Use
		SELECT DISTINCT
			MT.Mass_Tag_ID, 
			MT.Peptide, 
			MT.Monoisotopic_Mass, 
			CASE WHEN @NETValueType = 1 
			THEN MTN.PNET
			ELSE MTN.Avg_GANET 
			END As Net_Value_to_Use, 
			MTN.PNET, 
			MT.High_Normalized_Score, 
			MTN.StD_GANET,
			MT.High_Discriminant_Score,
			MT.Peptide_Obs_Count_Passing_Filter,
			MT.Mod_Count,
			MT.Mod_Description
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

