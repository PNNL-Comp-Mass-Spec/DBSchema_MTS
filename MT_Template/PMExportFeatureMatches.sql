/****** Object:  StoredProcedure [dbo].[PMExportFeatureMatches] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
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
**
****************************************************/
(
	@MDIDs varchar(max) = '',
	@infoOnly tinyint = 0,
	@PreviewSql tinyint=0,			-- Not used in this procedure
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

	Begin Try
		
		-------------------------------------------------
		-- Validate the inputs
		-------------------------------------------------	
		Set @MDIDs = IsNull(@MDIDs, '')
		
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
			MD_ID int NOT NULL
		)
		CREATE UNIQUE INDEX IX_Tmp_MDIDList_MDID ON #Tmp_MDIDList (MD_ID ASC)

		exec @myError = PMPopulateMDIDTable @MDIDs, @message = @message output
		if @myError <> 0
			Goto Done
		

		-------------------------------------------------	
		-- Return the data
		-------------------------------------------------	

		If @infoOnly <> 0
		Begin
			SELECT FUR.MD_ID,
				COUNT(DISTINCT FUR.UMC_Ind) as FeatureCount,
				COUNT(*) AS FeatureMatchCount
			FROM #Tmp_MDIDList ML
			     INNER JOIN T_FTICR_UMC_Results FUR
			       ON ML.MD_ID = FUR.MD_ID
			     INNER JOIN T_FTICR_UMC_ResultDetails FURD
			       ON FUR.UMC_Results_ID = FURD.UMC_Results_ID
			     INNER JOIN T_Mass_Tags MT
			       ON FURD.Mass_Tag_ID = MT.Mass_Tag_ID
			GROUP BY FUR.MD_ID
			--
			SELECT @myError = @@Error, @myRowCount = @@RowCount
		End
		Else
		Begin	
			SELECT FUR.MD_ID,
			       FUR.UMC_Ind,
			       FUR.Pair_UMC_Ind,
			       FURD.Mass_Tag_ID,
			       FURD.Match_Score,
			       FURD.Match_State,
			       FURD.Expected_NET,
			       FURD.Mass_Tag_Mods,
			       FURD.Mass_Tag_Mod_Mass,
			       FURD.Matching_Member_Count,
			       FURD.Del_Match_Score,
			       FURD.UMC_Results_ID,
			       CONVERT(real, CASE
			                         WHEN IsNull(MT.Monoisotopic_Mass, 0) > 0 
			                         THEN 1E6 * (FUR.Class_Mass - (MT.Monoisotopic_Mass + FURD.Mass_Tag_Mod_Mass)) / (MT.Monoisotopic_Mass + FURD.Mass_Tag_Mod_Mass)
			                         ELSE 0
			                     END) AS MassErrorPPM,
                   CONVERT(real, FUR.ElutionTime - FURD.Expected_NET) AS NETError,
			       CONVERT(tinyint, 0) AS InternalStdMatch
			FROM #Tmp_MDIDList ML
			     INNER JOIN T_FTICR_UMC_Results FUR
			       ON ML.MD_ID = FUR.MD_ID
			     INNER JOIN T_FTICR_UMC_ResultDetails FURD
			       ON FUR.UMC_Results_ID = FURD.UMC_Results_ID
			     INNER JOIN T_Mass_Tags MT
			       ON FURD.Mass_Tag_ID = MT.Mass_Tag_ID
			UNION
			SELECT FUR.MD_ID,
			       FUR.UMC_Ind,
			       FUR.Pair_UMC_Ind,
			       FURD.Seq_ID AS Mass_Tag_ID,
			       FURD.Match_Score,
			       FURD.Match_State,
			       FURD.Expected_NET,
			       '' AS Mass_Tag_Mods,
			       0 AS Mass_Tag_Mod_Mass,
			       FURD.Matching_Member_Count,
			       FURD.Del_Match_Score,
			       FURD.UMC_Results_ID,
			       CONVERT(real, CASE
			   WHEN IsNull(MT.Monoisotopic_Mass, 0) > 0 
			                         THEN 1E6 * (FUR.Class_Mass - MT.Monoisotopic_Mass) / MT.Monoisotopic_Mass
			                         ELSE 0
			   END) AS MassErrorPPM,
                   CONVERT(real, FUR.ElutionTime - FURD.Expected_NET) AS NETError,
			       CONVERT(tinyint, 1) AS InternalStdMatch
			FROM #Tmp_MDIDList ML
			     INNER JOIN T_FTICR_UMC_Results FUR
			       ON ML.MD_ID = FUR.MD_ID
			     INNER JOIN T_FTICR_UMC_InternalStdDetails FURD
			       ON FUR.UMC_Results_ID = FURD.UMC_Results_ID
			     INNER JOIN T_Mass_Tags MT
			       ON FURD.Seq_ID = MT.Mass_Tag_ID
			ORDER BY MD_ID, UMC_Ind, Mass_Tag_ID
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
