/****** Object:  StoredProcedure [dbo].[GetMassTagsPassingFiltersWork] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.GetMassTagsPassingFiltersWork
/****************************************************************
**  Desc: Populates temporary table #TmpMassTags with the PMTs
**		  that pass the given filters.  The calling procedure
**		  must create #TmpMassTags before calling this procedure
**
**  Return values: 0 if success, otherwise, error code 
**
**  Parameters: See comments below
**
**  Auth:	mem
**	Date:	04/06/2007
**			01/11/2010 mem - Added parameter @infoOnly
**			03/24/2011 mem - Added parameter @MaximumMSGFSpecProb
**			01/06/2012 mem - Updated to use T_Peptides.Job
**			02/28/2012 mem - No longer using @ConfirmedOnly
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
	@ConfirmedOnly tinyint = 0,				-- Mass Tag must have Is_Confirmed = 1  (ignored as of February 2012)
	@ExperimentFilter varchar(64) = '',				-- If non-blank, then selects PMT tags from datasets with this experiment; ignored if @JobToFilterOnByDataset is non-zero
	@ExperimentExclusionFilter varchar(64) = '',	-- If non-blank, then excludes PMT tags from datasets with this experiment; ignored if @JobToFilterOnByDataset is non-zero
	@JobToFilterOnByDataset int = 0,				-- Set to a non-zero value to only select PMT tags from the dataset associated with the given MS job; useful for matching LTQ-FT MS data to peptides detected during the MS/MS portion of the same analysis; if the job is not present in T_FTICR_Analysis_Description then no data is returned
	@MinimumHighNormalizedScore float = 0,			-- The minimum value required for High_Normalized_Score; 0 to allow all
	@MinimumPMTQualityScore decimal(9,5) = 0,		-- The minimum PMT_Quality_Score to allow; 0 to allow all
	@MinimumHighDiscriminantScore real = 0,			-- The minimum High_Discriminant_Score to allow; 0 to allow all
	@MinimumPeptideProphetProbability real = 0,		-- The minimum High_Peptide_Prophet_Probability value to allow; 0 to allow all
	@MaximumMSGFSpecProb float = 0,					-- The maximum MSGF Spectrum Probability value to allow (examines Min_MSGF_SpecProb in T_Mass_Tags); 0 to allow all
	@DatasetToFilterOn varchar(256)='' output,
	@infoOnly tinyint = 0
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

	Set @DatasetToFilterOn = ''
	
	---------------------------------------------------	
	-- Validate the input parameters
	---------------------------------------------------	
	-- @MassCorrectionIDFilterList is validated below
	
	/* Deprecated in February 2012
	--Set @ConfirmedOnly = IsNull(@ConfirmedOnly, 0)
	*/
	
	Set @MinimumHighNormalizedScore = IsNull(@MinimumHighNormalizedScore, 0)
	Set @MinimumPMTQualityScore = IsNull(@MinimumPMTQualityScore, 0)
	Set @MinimumHighDiscriminantScore = IsNull(@MinimumHighDiscriminantScore, 0)
	Set @MinimumPeptideProphetProbability = IsNull(@MinimumPeptideProphetProbability, 0)
	Set @MaximumMSGFSpecProb = IsNull(@MaximumMSGFSpecProb, 0)
	
	Set @ExperimentFilter = IsNull(@ExperimentFilter, '')
	Set @ExperimentExclusionFilter = IsNull(@ExperimentExclusionFilter, '')
	Set @JobToFilterOnByDataset = IsNull(@JobToFilterOnByDataset, 0)
	Set @infoOnly = IsNull(@infoOnly, 0)

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

	If @MaximumMSGFSpecProb <> 0
		Set @ScoreFilteringSQL = @ScoreFilteringSQL + ' AND (IsNull(MT.Min_MSGF_SpecProb, 1) <= ' + Convert(varchar(11), @MaximumMSGFSpecProb) + ') '
	
	/* Deprecated in February 2012
	-- If @ConfirmedOnly <> 0
	--	Set @ScoreFilteringSQL = @ScoreFilteringSQL + ' AND (Is_Confirmed=1) '
	*/

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
		SELECT @DatasetToFilterOn = Dataset
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
		Set @BaseSql = @BaseSql +     ' T_Peptides P ON MT.Mass_Tag_ID = P.Mass_Tag_ID INNER JOIN'
		Set @BaseSql = @BaseSql +     ' T_Analysis_Description TAD ON P.Job = TAD.Job'
		Set @BaseSql = @BaseSql + ' WHERE TAD.Dataset = ''' + @DatasetToFilterOn + ''''
		If Len(@ScoreFilteringSQL) > 0
			Set @BaseSql = @BaseSql + ' AND ' + @ScoreFilteringSQL
	End
	Else
	Begin
		If @ExperimentFilteringSQL = ''
		Begin
			Set @BaseSql = @BaseSql + ' SELECT Mass_Tag_ID'
			Set @BaseSql = @BaseSql + ' FROM T_Mass_Tags MT'
			If Len(@ScoreFilteringSQL) > 0
				Set @BaseSql = @BaseSql + ' WHERE ' + @ScoreFilteringSQL
		End
		Else
		Begin
			Set @BaseSql = @BaseSql + ' SELECT DISTINCT MT.Mass_Tag_ID'
			Set @BaseSql = @BaseSql + ' FROM T_Mass_Tags MT INNER JOIN'
			Set @BaseSql = @BaseSql +      ' T_Peptides P ON MT.Mass_Tag_ID = P.Mass_Tag_ID INNER JOIN'
			Set @BaseSql = @BaseSql +      ' T_Analysis_Description TAD ON P.Job = TAD.Job'
			Set @BaseSql = @BaseSql + ' WHERE ' + @ExperimentFilteringSQL
			If Len(@ScoreFilteringSQL) > 0
				Set @BaseSql = @BaseSql + ' AND ' + @ScoreFilteringSQL
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
	Begin -- <b>
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
	End -- </b>
    
	If @infoOnly <> 0
		Print @FullSql

Done:
	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[GetMassTagsPassingFiltersWork] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetMassTagsPassingFiltersWork] TO [MTS_DB_Lite] AS [dbo]
GO
