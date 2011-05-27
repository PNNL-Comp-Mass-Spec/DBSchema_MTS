/****** Object:  StoredProcedure [dbo].[PMExportFeatures] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE Procedure PMExportFeatures
/****************************************************	
**  Desc:	Exports LC-MS Features
**			for the peak matching tasks specified by the given MDID list
**
**  Return values:	0 if success, otherwise, error code 
**
**  Auth:	mem
**	Date:	07/15/2009
**			08/24/2009 jds - Removed use of T_Match_Making_Description from the queries
**			02/16/2011 mem - Added column Match_Score_Mode to #Tmp_MDIDList
**
****************************************************/
(
	@MDIDs varchar(max) = '',
	@infoOnly tinyint = 0,
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
		-- Return the data
		-------------------------------------------------	

		If @infoOnly <> 0
		Begin
			SELECT FUR.MD_ID, COUNT(*) AS FeatureCount
			FROM #Tmp_MDIDList ML
			     INNER JOIN T_FTICR_UMC_Results FUR
			       ON ML.MD_ID = FUR.MD_ID
			GROUP BY FUR.MD_ID
			--
			SELECT @myError = @@Error, @myRowCount = @@RowCount
		End
		Else
		Begin	
			SELECT FUR.MD_ID,
			       FUR.UMC_Ind,
			       FUR.Member_Count,
			       FUR.Member_Count_Used_For_Abu,
			       FUR.UMC_Score,
			       FUR.Scan_First,
			       FUR.Scan_Last,
			       FUR.Scan_Max_Abundance,
			       FUR.Class_Mass,
			       FUR.Monoisotopic_Mass_Min,
			       FUR.Monoisotopic_Mass_Max,
			       FUR.Monoisotopic_Mass_StDev,
			       FUR.Monoisotopic_Mass_MaxAbu,
			       FUR.Class_Abundance,
			       FUR.Abundance_Min,
			       FUR.Abundance_Max,
			       FUR.Class_Stats_Charge_Basis,
			       FUR.Charge_State_Min,
			       FUR.Charge_State_Max,
			       FUR.Charge_State_MaxAbu,
			       FUR.Fit_Average,
			       FUR.Fit_Min,
			       FUR.Fit_Max,
			       FUR.Fit_StDev,
			       FUR.ElutionTime,
			       FUR.Expression_Ratio,
			       FUR.FPR_Type_ID,
			       FUR.MassTag_Hit_Count,
			       FUR.Pair_UMC_Ind,
			       FUR.InternalStd_Hit_Count,
			       FUR.Expression_Ratio_StDev,
			       FUR.Expression_Ratio_Charge_State_Basis_Count,
			       FUR.Expression_Ratio_Member_Basis_Count,
			       FUR.UMC_Results_ID
			FROM #Tmp_MDIDList ML
			     INNER JOIN T_FTICR_UMC_Results FUR
			       ON ML.MD_ID = FUR.MD_ID
			ORDER BY ML.MD_ID, FUR.UMC_Ind
			--
			SELECT @myError = @@Error, @myRowCount = @@RowCount

		End

	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'PMExportFeatures')
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
		Execute PostLogEntry 'Error', @message, 'PMExportFeatures'
		Print @message
	End

DoneSkipLog:	
	Return @myError


GO
GRANT EXECUTE ON [dbo].[PMExportFeatures] TO [DMS_SP_User] AS [dbo]
GO
