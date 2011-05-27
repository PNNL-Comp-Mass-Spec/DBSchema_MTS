/****** Object:  StoredProcedure [dbo].[PMExportFeatureMatches] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE Procedure dbo.PMExportFeatureMatches
/****************************************************	
**  Desc:	Exports LC-MS Feature to AMT matches
**			for the peak matching tasks specified by the given MDID list
**
**  Return values:	0 if success, otherwise, error code 
**
**  Auth:	mem
**	Date:	07/19/2009
**			08/24/2009 jds - Removed use of T_Match_Making_Description from the queries
**			11/03/2009 mem - Now utilizing FURD.Mass_Tag_Mod_Mass when computing MassErrorPPM
**			10/12/2010 mem - Now returning STAC-related columns
**						   - Added parameter @FDRThreshold
**			02/16/2011 mem - Now customizing the name returned for the Match_Score and Del_Match_Score column
**
****************************************************/
(
	@MDIDs varchar(max) = '',
	@FDRThreshold real = 0,			-- If non-zero, then filters the data using FDR_Threshold in T_FTICR_UMC_ResultDetails or T_FTICR_UMC_InternalStdDetails
	@infoOnly tinyint = 0,
	@PreviewSql tinyint=0,
	@message varchar(512)='' output
)
AS
	Set NoCount On

	Declare @myError int
	Declare @myRowcount int
	Set @myRowcount = 0
	Set @myError = 0

	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	-- @MatchScoreMode will be -1 if a mix of modes was used, 0 if SLiC score was used, and 1 if STAC was used
	Declare @MatchScoreMode int = 0
	Declare @MatchScoreModeMin int = 0
	Declare @MatchScoreModeMax int = 0

	Declare @MatchScoreCol varchar(32)
	Declare @DelMatchScoreCol varchar(32)
	Declare @S varchar(4000)
	
	Begin Try
		
		-------------------------------------------------
		-- Validate the inputs
		-------------------------------------------------	
		Set @MDIDs = IsNull(@MDIDs, '')
		
		Set @FDRThreshold = IsNull(@FDRThreshold, 0)
		Set @infoOnly = IsNull(@infoOnly, 0)
		Set @PreviewSql = IsNull(@PreviewSql, 0)

		Set @message = ''
		
		If @MDIDs = ''
		Begin
			Set @message = '@MDIDs is empty; nothing to do'
			Goto Done
		End
		

		-------------------------------------------------
		-- Create and populate a temporary table with the data in @MDIDs
		-------------------------------------------------	

		CREATE TABLE #Tmp_MDIDList (
			MD_ID int NOT NULL,
			Match_Score_Mode tinyint not null
		)
		CREATE UNIQUE INDEX IX_Tmp_MDIDList_MDID ON #Tmp_MDIDList (MD_ID ASC)

		exec @myError = PMPopulateMDIDTable @MDIDs, @message = @message output
		if @myError <> 0
			Goto Done
		
		-------------------------------------------------	
		-- Update Match_Score_Mode in #Tmp_MDIDList
		-------------------------------------------------	
		--
		UPDATE #Tmp_MDIDList
		SET Match_Score_Mode = MMD.Match_Score_Mode
		FROM #Tmp_MDIDList
		     INNER JOIN T_Match_Making_Description MMD
		       ON #Tmp_MDIDList.MD_ID = MMD.MD_ID
		--
		SELECT @myError = @@Error, @myRowCount = @@RowCount
		
		
		-------------------------------------------------	
		-- Determine whether STAC was used, SLiC was used, or we have a mix
		-------------------------------------------------	
		
		SELECT @MatchScoreModeMin = MIN(Match_Score_Mode), @MatchScoreModeMax = MAX(Match_Score_Mode)
		FROM #Tmp_MDIDList
		
		If @MatchScoreModeMin <> @MatchScoreModeMax
			Set @MatchScoreMode = -1
		Else
			Set @MatchScoreMode = @MatchScoreModeMin
		
		If @MatchScoreMode = 0
		Begin
			Set @MatchScoreCol = 'SLiC_Score'	-- This column was previously named "Match_Score"
			Set @DelMatchScoreCol = 'Del_SLiC'	-- This column was previously named "Del_Match_Score"
		End
		Else
		Begin
			If @MatchScoreMode = 1
			Begin
				Set @MatchScoreCol = 'STAC_Score'
				Set @DelMatchScoreCol = 'Del_STAC'
			End
			Else
			Begin
				Set @MatchScoreCol = 'STAC_Score_and_SLiC_Score_Mixed'
				Set @DelMatchScoreCol = 'Del_STAC_and_Del_SLiC_Mixed'
			End
		End

		-------------------------------------------------	
		-- Return the data
		-------------------------------------------------	

		If @infoOnly <> 0
		Begin
			SELECT FUR.MD_ID,			    
				COUNT(DISTINCT FUR.UMC_Ind) as FeatureCount,
				COUNT(*) AS FeatureMatchCount,
				ML.Match_Score_Mode
			FROM #Tmp_MDIDList ML
			     INNER JOIN T_FTICR_UMC_Results FUR
			       ON ML.MD_ID = FUR.MD_ID
			     INNER JOIN T_FTICR_UMC_ResultDetails FURD
			       ON FUR.UMC_Results_ID = FURD.UMC_Results_ID
			     INNER JOIN T_Mass_Tags MT
			       ON FURD.Mass_Tag_ID = MT.Mass_Tag_ID
			GROUP BY FUR.MD_ID, ML.Match_Score_Mode
			--
			SELECT @myError = @@Error, @myRowCount = @@RowCount
		End
		Else
		Begin	
			Set @S = ''
			Set @S = @S + ' SELECT FUR.MD_ID,'
			Set @S = @S +        ' FUR.UMC_Ind,'
			Set @S = @S +        ' FUR.Pair_UMC_Ind,'
			Set @S = @S +        ' FURD.Mass_Tag_ID,'
			Set @S = @S +        ' FURD.Match_Score AS ' + @MatchScoreCol + ','
			Set @S = @S +        ' FURD.Match_State,'
			Set @S = @S +        ' FURD.Expected_NET,'
			Set @S = @S +        ' FURD.Mass_Tag_Mods,'
			Set @S = @S +        ' FURD.Mass_Tag_Mod_Mass,'
			Set @S = @S +        ' FURD.Matching_Member_Count,'
			Set @S = @S +        ' FURD.Del_Match_Score AS ' + @DelMatchScoreCol + ','
			Set @S = @S +        ' FURD.UMC_Results_ID,'
			Set @S = @S +        ' CONVERT(real, CASE'
			Set @S = @S +                      ' WHEN IsNull(MT.Monoisotopic_Mass, 0) > 0 '
			Set @S = @S +                      ' THEN 1E6 * (FUR.Class_Mass - (MT.Monoisotopic_Mass + FURD.Mass_Tag_Mod_Mass)) / (MT.Monoisotopic_Mass + FURD.Mass_Tag_Mod_Mass)'
			Set @S = @S +                      ' ELSE 0'
			Set @S = @S +                      ' END) AS MassErrorPPM,'
			Set @S = @S +        ' CONVERT(real, FUR.ElutionTime - FURD.Expected_NET) AS NETError,'
			Set @S = @S +        ' CONVERT(tinyint, 0) AS InternalStdMatch,'
			Set @S = @S +        ' IsNull(FURD.Uniqueness_Probability, 0) AS Uniqueness_Probability, '
			Set @S = @S +        ' IsNull(FURD.FDR_Threshold, 1) AS FDR_Threshold'
			Set @S = @S + ' FROM #Tmp_MDIDList ML'
			Set @S = @S + '      INNER JOIN T_FTICR_UMC_Results FUR'
			Set @S = @S +        ' ON ML.MD_ID = FUR.MD_ID'
			Set @S = @S + '      INNER JOIN T_FTICR_UMC_ResultDetails FURD'
			Set @S = @S +        ' ON FUR.UMC_Results_ID = FURD.UMC_Results_ID'
			Set @S = @S + '      INNER JOIN T_Mass_Tags MT'
			Set @S = @S +        ' ON FURD.Mass_Tag_ID = MT.Mass_Tag_ID'
			If @FDRThreshold > 0
				Set @S = @S + ' WHERE IsNull(FURD.FDR_Threshold, 1) <= ' + Convert(varchar(12), @FDRThreshold)
			Set @S = @S + ' UNION'
			Set @S = @S + ' SELECT FUR.MD_ID,'
			Set @S = @S +        ' FUR.UMC_Ind,'
			Set @S = @S +        ' FUR.Pair_UMC_Ind,'
			Set @S = @S +        ' FURD.Seq_ID AS Mass_Tag_ID,'
			Set @S = @S +        ' FURD.Match_Score AS ' + @MatchScoreCol + ','
			Set @S = @S +        ' FURD.Match_State,'
			Set @S = @S +        ' FURD.Expected_NET,'
			Set @S = @S +        ' '''' AS Mass_Tag_Mods,'
			Set @S = @S +        ' 0 AS Mass_Tag_Mod_Mass,'
			Set @S = @S +        ' FURD.Matching_Member_Count,'
			Set @S = @S +        ' FURD.Del_Match_Score AS ' + @DelMatchScoreCol + ','
			Set @S = @S +        ' FURD.UMC_Results_ID,'
			Set @S = @S +        ' CONVERT(real, CASE'
			Set @S = @S +                      ' WHEN IsNull(MT.Monoisotopic_Mass, 0) > 0  '
			Set @S = @S +                      ' THEN 1E6 * (FUR.Class_Mass - MT.Monoisotopic_Mass) / MT.Monoisotopic_Mass'
			Set @S = @S +                      ' ELSE 0'
			Set @S = @S +                      ' END) AS MassErrorPPM,'
			Set @S = @S +        ' CONVERT(real, FUR.ElutionTime - FURD.Expected_NET) AS NETError,'
			Set @S = @S +        ' CONVERT(tinyint, 1) AS InternalStdMatch,'
			Set @S = @S +        ' IsNull(FURD.Uniqueness_Probability, 0) AS Uniqueness_Probability, '
			Set @S = @S +        ' IsNull(FURD.FDR_Threshold, 1) AS FDR_Threshold'
			Set @S = @S + ' FROM #Tmp_MDIDList ML'
			Set @S = @S + '      INNER JOIN T_FTICR_UMC_Results FUR'
			Set @S = @S +        ' ON ML.MD_ID = FUR.MD_ID'
			Set @S = @S + '      INNER JOIN T_FTICR_UMC_InternalStdDetails FURD'
			Set @S = @S +        ' ON FUR.UMC_Results_ID = FURD.UMC_Results_ID'
			Set @S = @S + '      INNER JOIN T_Mass_Tags MT'
			Set @S = @S +        ' ON FURD.Seq_ID = MT.Mass_Tag_ID'
			If @FDRThreshold > 0
				Set @S = @S + ' WHERE IsNull(FURD.FDR_Threshold, 1) <= ' + Convert(varchar(12), @FDRThreshold)
			Set @S = @S + ' ORDER BY MD_ID, UMC_Ind, Mass_Tag_ID'
			
			If @PreviewSql <> 0
				Print @S
			Else
				Exec (@S)
			--
			SELECT @myError = @@Error, @myRowCount = @@RowCount

		End

	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'PMExportFeatureMatches')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, @LogWarningErrorList = '',
								@ErrorNum = @myError output, @message = @message output
		Goto DoneSkipLog
	End Catch
				
Done:
	-----------------------------------------------------------
	-- Done processing
	-----------------------------------------------------------
		
	If @myError <> 0 
	Begin
		Execute PostLogEntry 'Error', @message, 'PMExportFeatureMatches'
		Print @message
	End

DoneSkipLog:	
	Return @myError


GO
GRANT EXECUTE ON [dbo].[PMExportFeatureMatches] TO [DMS_SP_User] AS [dbo]
GO
