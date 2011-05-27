/****** Object:  StoredProcedure [dbo].[PMExportMatchOverview] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE Procedure dbo.PMExportMatchOverview
/****************************************************	
**  Desc:	Exports overview info
**			for the peak matching tasks specified by the given MDID list
**
**  Return values:	0 if success, otherwise, error code 
**
**  Auth:	mem
**	Date:	07/15/2009
**			08/24/2009 jds - Rearranged queries to reference #Tmp_MDIDList first
**			10/13/2010 mem - Now returning STAC-related columns from T_Match_Making_Description
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
			SELECT COUNT(DISTINCT FAD.Dataset_ID) AS Dataset_Count,
			       COUNT(DISTINCT FAD.Job) AS Job_Count,
			       COUNT(*) AS MDID_Count
			FROM #Tmp_MDIDList ML
			     INNER JOIN T_Match_Making_Description MMD
			       ON MMD.MD_ID = ML.MD_ID
			     INNER JOIN T_FTICR_Analysis_Description FAD
			       ON MMD.MD_Reference_Job = FAD.Job
			--
			SELECT @myError = @@Error, @myRowCount = @@RowCount
		End
		Else
		Begin	
			SELECT FAD.Dataset,
			       FAD.Dataset_ID,
			       FAD.Job,
			       MMD.MD_ID,
			       MMD.MD_File,
			       MMD.MD_Date,
			       MMD.MD_State,
			       MMD.MD_Peaks_Count,
			       MMD.MD_Tool_Version,
			       MMD.MD_Comparison_Mass_Tag_Count,
			       MMD.Minimum_High_Normalized_Score,
			       MMD.Minimum_High_Discriminant_Score,
			       MMD.Minimum_Peptide_Prophet_Probability,
			       MMD.Minimum_PMT_Quality_Score,
			       MMD.Experiment_Filter,
			       MMD.Experiment_Exclusion_Filter,
			       MMD.Limit_To_PMTs_From_Dataset,
			       MMD.MD_UMC_TolerancePPM,
			       MMD.MD_UMC_Count,
			       MMD.MD_NetAdj_TolerancePPM,
			       MMD.MD_NetAdj_UMCs_HitCount,
			       MMD.MD_NetAdj_TopAbuPct,
			       MMD.MD_NetAdj_IterationCount,
			       MMD.MD_NetAdj_NET_Min,
			       MMD.MD_NetAdj_NET_Max,
			       MMD.MD_MMA_TolerancePPM,
			       MMD.MD_NET_Tolerance,
			       MMD.GANET_Fit,
			       MMD.GANET_Slope,
			       MMD.GANET_Intercept,
			       MMD.Refine_Mass_Cal_PPMShift,
			       MMD.Refine_Mass_Cal_PeakHeightCounts,
			       MMD.Refine_Mass_Cal_PeakWidthPPM,
			       MMD.Refine_Mass_Cal_PeakCenterPPM,
			       MMD.Refine_Mass_Tol_Used,
			       MMD.Refine_NET_Tol_PeakHeightCounts,
			       MMD.Refine_NET_Tol_PeakWidth,
			       MMD.Refine_NET_Tol_PeakCenter,
			       MMD.Refine_NET_Tol_Used,
			       MMD.Ini_File_Name,
			       MMD.Match_Score_Mode,
			       MMD.STAC_Used_Prior_Probability,
			       MMD.AMT_Count_1pct_FDR,
			       MMD.AMT_Count_5pct_FDR,
			       MMD.AMT_Count_10pct_FDR,
			       MMD.AMT_Count_25pct_FDR,
			       MMD.AMT_Count_50pct_FDR
			FROM #Tmp_MDIDList ML
			     INNER JOIN T_Match_Making_Description MMD
			       ON MMD.MD_ID = ML.MD_ID
			     INNER JOIN T_FTICR_Analysis_Description FAD
			       ON MMD.MD_Reference_Job = FAD.Job
			ORDER BY MMD.MD_ID
			--
			SELECT @myError = @@Error, @myRowCount = @@RowCount

		End

	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'PMExportMatchOverview')
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
		Execute PostLogEntry 'Error', @message, 'PMExportMatchOverview'
		Print @message
	End

DoneSkipLog:	
	Return @myError


GO
GRANT EXECUTE ON [dbo].[PMExportMatchOverview] TO [DMS_SP_User] AS [dbo]
GO
