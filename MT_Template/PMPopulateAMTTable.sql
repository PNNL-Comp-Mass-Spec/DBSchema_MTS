/****** Object:  StoredProcedure [dbo].[PMPopulateAMTTable] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE PMPopulateAMTTable
/****************************************************
**
**	Desc: 
**		Populates table #Tmp_FilteredMTs with a filtered list of Mass_Tag_ID values
**
**		Alternatively, if @CountRowsOnly is 1, then populates 
**		  @AMTCount with the number of AMTs that would be returned
**
**		If @FilterByMDID = 0, then table T_Mass_Tags will be filtered based on the specified thresholds
**		In this case, @UseScoreThresholds must be non-zero
**
**		If @FilterByMDID is non-zero, then constructs a list of the Mass_Tag_ID
**		 values identified in the MDIDs defined in table #Tmp_MDIDList
**		This data will be further filtered if @UseScoreThresholds is non-zero
**
**		The calling procedure must create tables #Tmp_MDIDList and #Tmp_FilteredMTs
**
**		The procedure will return an error code if @FilterByMDID = 0 and @UseScoreThresholds = 0
**
**
**	Return values: 0 if no error; otherwise error code
**
**	Auth:	mem
**	Date:	07/16/2009 mem - Initial version
**			10/27/2009 mem - Added parameter @MinimumCleavageState
**    
*****************************************************/
(
	@FilterByMDID tinyint = 0,						-- When 1, then only returns Mass Tag IDs identified by the MDIDs in #Tmp_MDIDList; otherwise, ignores #Tmp_MDIDList
	@UseScoreThresholds tinyint = 0,				-- When 1, then filters the data using the following score thresholds; otherwise, does not filter by threshold
	@MinimumHighNormalizedScore real = 0,			-- The minimum value required for High_Normalized_Score; 0 to allow all
	@MinimumHighDiscriminantScore real = 0,			-- The minimum High_Discriminant_Score to allow; 0 to allow all
	@MinimumPeptideProphetProbability real = 0,		-- The minimum High_Peptide_Prophet_Probability value to allow; 0 to allow all
	@MinimumPMTQualityScore real = 0,				-- The minimum PMT_Quality_Score to allow; 0 to allow all
	@MinimumCleavageState smallint = 0,				-- The minimum Max_Cleavage_State to allow; 0 to allow all
	@CountRowsOnly tinyint = 0,						-- When 1, then populates @AMTCount but does not populate #Tmp_FilteredMTs
	@AMTCount int = 0 output,						-- The number of AMT tags that pass the thresholds
	@AMTLastAffectedMax datetime = null output,		-- The maximum Last_Affected value for the AMT tags that pass the thresholds
	@previewSql tinyint = 0,
	@message varchar(512)='' output
)
AS
	set nocount on

	Declare @myRowCount int
	Declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Declare @S nvarchar(2000)
	Declare @ScoreFilteringSQL nvarchar(1024)
	Declare @SqlFull nvarchar(4000)
	Declare @SqlParams nvarchar(128)
	
	-------------------------------------------------
	-- Validate the inputs
	-------------------------------------------------
	
	Set @FilterByMDID = IsNull(@FilterByMDID, 0)
	Set @UseScoreThresholds = IsNull(@UseScoreThresholds, 1)

	Set @MinimumHighNormalizedScore = IsNull(@MinimumHighNormalizedScore, 0)
	Set @MinimumHighDiscriminantScore = IsNull(@MinimumHighDiscriminantScore, 0)
	Set @MinimumPeptideProphetProbability = IsNull(@MinimumPeptideProphetProbability, 0)
	Set @MinimumPMTQualityScore = IsNull(@MinimumPMTQualityScore, 0)
	Set @MinimumCleavageState = IsNull(@MinimumCleavageState, 0)

	Set @CountRowsOnly = IsNull(@CountRowsOnly, 0)
	Set @previewSql = IsNull(@previewSql, 0)

	Set @AMTCount = 0
	Set @AMTLastAffectedMax = Convert(datetime, '2000-01-01')

	If @FilterByMDID = 0 And @UseScoreThresholds = 0
	Begin
		Set @message = 'Both @FilterByMDID and @UseScoreThresholds are zero; this is not allowed'
		Print @message
		Set @myError = 50000
		Goto Done
	End
	
	-------------------------------------------------
	-- Populate #Tmp_FilteredMTs
	-------------------------------------------------

	Set @ScoreFilteringSQL = ''

	If @UseScoreThresholds <> 0		
	Begin
		-- Construct dynamic SQL to obtain the data
		If @MinimumPMTQualityScore <> 0
			Set @ScoreFilteringSQL = @ScoreFilteringSQL + ' AND (IsNull(MT.PMT_Quality_Score, 0) >= ' +  Convert(varchar(11), @MinimumPMTQualityScore) + ') '

		If @MinimumHighDiscriminantScore <> 0
			Set @ScoreFilteringSQL = @ScoreFilteringSQL + ' AND (IsNull(MT.High_Discriminant_Score, 0) >= ' + Convert(varchar(11), @MinimumHighDiscriminantScore) + ') '

		If @MinimumPeptideProphetProbability <> 0
			Set @ScoreFilteringSQL = @ScoreFilteringSQL + ' AND (IsNull(MT.High_Peptide_Prophet_Probability, 0) >= ' + Convert(varchar(11), @MinimumPeptideProphetProbability) + ') '

		If @MinimumHighNormalizedScore <> 0
			Set @ScoreFilteringSQL = @ScoreFilteringSQL + ' AND (IsNull(MT.High_Normalized_Score, 0) >= ' +  Convert(varchar(11), @MinimumHighNormalizedScore) + ') '

		If @MinimumCleavageState > 0
			Set @ScoreFilteringSQL = @ScoreFilteringSQL + ' AND (IsNull(MT.Cleavage_State_Max, 0) >= ' +  Convert(varchar(11), @MinimumCleavageState) + ') '
			
		-- Remove ' AND' from the start of @ScoreFilteringSQL if non-blank
		If Len(@ScoreFilteringSQL) > 0
			Set @ScoreFilteringSQL = Substring(@ScoreFilteringSQL, 5, LEN(@ScoreFilteringSQL))

	End

	-- Construct dynamic SQL to obtain the data

	Set @S = ''
	If @FilterByMDID = 0
	Begin
		If @CountRowsOnly = 0
			Set @S = @S + ' SELECT Mass_Tag_ID '
		Else
			Set @S = @S + ' SELECT Mass_Tag_ID, Last_Affected '
		
		Set @S = @S + ' FROM T_Mass_Tags MT '
		If @ScoreFilteringSQL <> ''
			Set @S = @S + ' WHERE ' + @ScoreFilteringSQL
	End
	Else
	Begin
		If @CountRowsOnly = 0
			Set @S = @S + ' SELECT DISTINCT UnionQ.Mass_Tag_ID'
		Else
			Set @S = @S + ' SELECT DISTINCT UnionQ.Mass_Tag_ID, MT.Last_Affected'
		
		Set @S = @S + ' FROM ('
		Set @S = @S +     ' SELECT DISTINCT FURD.Mass_Tag_ID AS Mass_Tag_ID'
		Set @S = @S +      ' FROM T_Match_Making_Description MMD'
		Set @S = @S +            ' INNER JOIN T_FTICR_UMC_Results FUR ON MMD.MD_ID = FUR.MD_ID'
		Set @S = @S +            ' INNER JOIN T_FTICR_UMC_ResultDetails FURD ON FUR.UMC_Results_ID = FURD.UMC_Results_ID'
		Set @S = @S +            ' INNER JOIN T_Mass_Tags MT ON FURD.Mass_Tag_ID = MT.Mass_Tag_ID'
		Set @S = @S +            ' INNER JOIN #Tmp_MDIDList ML ON MMD.MD_ID = ML.MD_ID'
		Set @S = @S +      ' UNION'
		Set @S = @S +      ' SELECT DISTINCT FURD.Seq_ID AS Mass_Tag_ID'
		Set @S = @S +      ' FROM T_Match_Making_Description MMD'
		Set @S = @S +            ' INNER JOIN T_FTICR_UMC_Results FUR ON MMD.MD_ID = FUR.MD_ID'
		Set @S = @S +            ' INNER JOIN T_FTICR_UMC_InternalStdDetails FURD ON FUR.UMC_Results_ID = FURD.UMC_Results_ID'
		Set @S = @S +            ' INNER JOIN T_Mass_Tags MT ON FURD.Seq_ID = MT.Mass_Tag_ID'
		Set @S = @S +            ' INNER JOIN #Tmp_MDIDList ML ON MMD.MD_ID = ML.MD_ID'
		Set @S = @S +      ') UnionQ'
		Set @S = @S +      ' INNER JOIN T_Mass_Tags MT ON UnionQ.Mass_Tag_ID = MT.Mass_Tag_ID'
		
		If @ScoreFilteringSQL <> ''
		Begin
			Set @S = @S + ' WHERE ' + @ScoreFilteringSQL
		End
	End


	If @CountRowsOnly = 0
		-- Populate #Tmp_FilteredMTs with the data returned by @S
		Set @SqlFull = 'INSERT INTO #Tmp_FilteredMTs ( Mass_Tag_ID ) ' + @S
	Else
	Begin
		-- Count the number of rows in @S; also determine the most recent Last_Affected date
		Set @SqlFull = ''
		Set @SqlFull = @SqlFull + ' SELECT @AMTCount = COUNT(*),'
		Set @SqlFull = @SqlFull +        ' @AMTLastAffectedMax = Max(Last_Affected)'
		Set @SqlFull = @SqlFull +        ' FROM (' + @S + ') LookupQ'
	End

	If @PreviewSql <> 0
		Print @SqlFull
	Else
	Begin
		If @CountRowsOnly = 0
		Begin
			-- Run the query to populate #Tmp_FilteredMTs
			Exec (@SqlFull)
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			
			-- Count the number of filtered AMT tags
			-- Also, lookup the most recent Last_Affected date/time
			SELECT @AMTCount = COUNT(*),
			       @AMTLastAffectedMax = Max(MT.Last_Affected)
			FROM T_Mass_Tags MT
			     INNER JOIN #Tmp_FilteredMTs F
			       ON MT.Mass_Tag_ID = F.Mass_Tag_ID
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			
		End
		Else
		Begin
			-- Run the query to compute @AMTCount and @AMTLastAffectedMax
			Set @SqlParams = '@AMTCount int output, @AMTLastAffectedMax datetime output'
			
			exec sp_executesql @SqlFull, @SqlParams, @AMTCount = @AMTCount output, @AMTLastAffectedMax = @AMTLastAffectedMax output
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
		End	
	End
		
Done:
	Return @myError


GO
