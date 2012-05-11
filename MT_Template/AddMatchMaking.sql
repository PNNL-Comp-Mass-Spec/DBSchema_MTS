/****** Object:  StoredProcedure [dbo].[AddMatchMaking] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.AddMatchMaking
/******************************************************* 	
**	Adds row to the T_Match_Making table
**
**  Returns ID assigned to new record in output pararameter @MatchMakingID
**
**	Returns 0 if success; error number on failure
**
**	Date:	12/14/2001 
**	Author: nt
**
**			06/23/2003 mem - added @ToolVersion
**			06/25/2003 mem - added 7 new inputs
**			07/01/2003 mem - changed MD_State update logic to Set to 5 if previously analyzed; 
**							 added new State column to allow setting of State to 2 immediately;
**							 added GANET_Fit, GANET_Slope, and GANET_Intercept parameters
**			07/17/2003 mem - added NetAdjNetMin, NetAdjNetMax, RefineMassCalPPMShift,  
**							 RefineMassCalPeakHeightCounts, RefineMassTolUsed, and 
**							 RefineNETTolUsed parameters
**			07/20/2003 mem - added MD_NetAdj_TopAbuPct and MD_NetAdj_IterationCount parameters
**			04/08/2004 mem - added MinimumHighNormalizedScore and MinimumPMTQualityScore parameters
**			10/05/2004 mem - now extracting the Ini File Name from @Parameters; added @IniFileName
**			02/05/2005 mem - added parameters @MinimumHighDiscriminantScore, @ExperimentFilter, and @ExperimentExclusionFilter
**			05/06/2005 mem - Added parameters @RefineMassCalPeakWidthPPM, @RefineMassCalPeakCenterPPM, @RefineNETTolPeakHeightCounts, @RefineNETTolPeakWidthNET, & @RefineNETTolPeakCenterNET
**			12/20/2005 mem - Added parameter @LimitToPMTsFromDataset
**			09/06/2006 mem - Added parameter @MinimumPeptideProphetProbability
**			10/07/2010 mem - Added parameter @MatchScoreMode
**			10/08/2010 mem - Added parameter @STACUsedPriorProbability
**			10/12/2010 mem - Added parameters @AMTCount1pctFDR, @AMTCount5pctFDR, and @AMTCount10pctFDR
**			10/13/2010 mem - Added parameters @AMTCount25pctFDR and @AMTCount50pctFDR
**			05/04/2011 mem - Now calling AutoAddFTICRJob to make sure @Reference_Job is present in T_FTICR_Analysis_Description
**			06/22/2011 mem - Added parameter @DriftTimeTolerance
**			06/23/2011 mem - Added parameters @DriftTimeAlignmentSlope and @DriftTimeAlignmentIntercept
**			06/29/2011 mem - Expanded @File to be varchar(2048)
**			02/28/2012 mem - Added parameter @PMTCollectionID
**
*******************************************************/
(
	@Reference_Job int,
	@File varchar(2048),		-- For multialign, this could be a comma-separated list of files
	@Type int,					-- MD_Type, pointer to table T_MMD_Type_Name, field MT_ID
	@Parameters varchar(2048),
	@PeaksCount int,
	@MatchMakingID int OUTPUT,
	@ToolVersion			varchar(128)=NULL,
	@ComparisonMassTagCount int=0,
	@UMCTolerancePPM		numeric(9,4)=0,
	@UMCCount				int=0,
	@NetAdjTolerancePPM		numeric(9,4)=0,
	@NetAdjUMCsHitCount		int=0,
	@NetAdjTopAbuPct		tinyint=0,
	@NetAdjIterationCount	tinyint=0,
	@MMATolerancePPM		numeric(9,4)=0,
	@NETTolerance			numeric(9,5)=0,
	@State					tinyint=1,			-- Default State is 1 = New
	@GANETFit				float=NULL,
	@GANETSlope				float=NULL,
	@GANETIntercept			float=NULL,
	@NetAdjNetMin			numeric(9,5)=NULL,
	@NetAdjNetMax			numeric(9,5)=NULL,
	@RefineMassCalPPMShift	numeric(9,4)=NULL,
	@RefineMassCalPeakHeightCounts	int=NULL,
	@RefineMassTolUsed			tinyint=0,
	@RefineNETTolUsed			tinyint=0,
	@MinimumHighNormalizedScore decimal(9,5)=NULL,
	@MinimumPMTQualityScore		decimal(9,5)=NULL,
	@IniFileName			    varchar(255)=NULL,
	@MinimumHighDiscriminantScore real=0, 
	@ExperimentFilter           varchar(64)='',
	@ExperimentExclusionFilter  varchar(64)='',
	@RefineMassCalPeakWidthPPM  real=NULL,
	@RefineMassCalPeakCenterPPM real = NULL,
	@RefineNETTolPeakHeightCounts int=NULL,
	@RefineNETTolPeakWidthNET  real=NULL,
	@RefineNETTolPeakCenterNET real = NULL,
	@LimitToPMTsFromDataset   tinyint = 0,
	@MinimumPeptideProphetProbability real = 0,
	@MatchScoreMode           tinyint = 0,			-- Pointer to table T_MMD_Match_Score_Mode; 0 = SLiC Score, 1 = STAC Score
	@STACUsedPriorProbability tinyint = 0,
	@AMTCount1pctFDR int = 0,						-- Unique count of AMT tags with FDR <= 0.01
	@AMTCount5pctFDR int = 0,						-- Unique count of AMT tags with FDR <= 0.05
	@AMTCount10pctFDR int = 0,						-- Unique count of AMT tags with FDR <= 0.10
	@AMTCount25pctFDR int = 0,						-- Unique count of AMT tags with FDR <= 0.25
	@AMTCount50pctFDR int = 0,						-- Unique count of AMT tags with FDR <= 0.50
	@DriftTimeTolerance real = NULL,
	@DriftTimeAlignmentSlope real = NULL,
	@DriftTimeAlignmentIntercept real = NULL,
	@PMTCollectionID int = NULL
)
As
	Set NoCount On

	declare @myRowCount int	
	declare @myError int
	Set @myRowCount = 0
	Set @myError = 0
		
	Declare @charLoc int

	If Len(IsNull(@IniFileName, '')) = 0
		Set @IniFileName = ''

	If Len(@IniFileName) = 0 And @Parameters Like 'IniFile=%'
	Begin
		Set @charLoc = CHARINDEX('.ini', @Parameters)	
		If IsNull(@charLoc, 0) > 1
			Set @IniFileName = SubString(@Parameters, 9, @charLoc - 5)
	End

	-- Make sure @Reference_Job is present in T_FTICR_Analysis_Description
	exec AutoAddFTICRJob @Reference_Job
	
	-- Start a transaction
	BEGIN TRANSACTION FullTrans
		
	-- If there are analyses with same Reference_Job and Type, then mark
	-- this as an update (all previous have to be marked as Updated)
	UPDATE dbo.T_Match_Making_Description
	Set MD_State = 5
	WHERE MD_Reference_Job=@Reference_Job AND 
		  MD_Type=@Type
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	If @myError <> 0
	Begin
		ROLLBACK TRANSACTION FullTrans
		Goto Done
	End
		
	-- Append new row to the T_Match_Making_Description table
	INSERT INTO dbo.T_Match_Making_Description (
		MD_Reference_Job, MD_File, MD_Type, MD_Parameters, 
		MD_Date, MD_State, MD_Peaks_Count, 
		MD_Tool_Version, MD_Comparison_Mass_Tag_Count, 
		MD_UMC_TolerancePPM, MD_UMC_Count,
		MD_NetAdj_TolerancePPM, MD_NetAdj_UMCs_HitCount, 
		MD_NetAdj_TopAbuPct, MD_NetAdj_IterationCount,
		MD_NetAdj_NET_Min, MD_NetAdj_NET_Max,
		MD_MMA_TolerancePPM, MD_NET_Tolerance, MD_DriftTime_Tolerance,
		GANET_Fit, GANET_Slope, GANET_Intercept,
		Refine_Mass_Cal_PPMShift, 
		Refine_Mass_Cal_PeakHeightCounts, Refine_Mass_Cal_PeakWidthPPM,
		Refine_Mass_Cal_PeakCenterPPM, Refine_Mass_Tol_Used, 
		Refine_NET_Tol_PeakHeightCounts, Refine_NET_Tol_PeakWidth, 
		Refine_NET_Tol_PeakCenter, Refine_NET_Tol_Used,
		Minimum_High_Normalized_Score, Minimum_High_Discriminant_Score, 
		Minimum_Peptide_Prophet_Probability, Minimum_PMT_Quality_Score,
		Ini_File_Name, Experiment_Filter, Experiment_Exclusion_Filter, 
		Limit_To_PMTs_From_Dataset,
		Match_Score_Mode,
		STAC_Used_Prior_Probability,
		AMT_Count_1pct_FDR,
		AMT_Count_5pct_FDR,
		AMT_Count_10pct_FDR,
		AMT_Count_25pct_FDR,
		AMT_Count_50pct_FDR,
		DriftTime_Alignment_Slope,
		DriftTime_Alignment_Intercept,
		PMT_Collection_ID
		)
	VALUES (@Reference_Job, @File, @Type, @Parameters, 
			GetDate(), @State, @PeaksCount, 
			@ToolVersion, @ComparisonMassTagCount,
			@UMCTolerancePPM, @UMCCount,
			@NetAdjTolerancePPM, @NetAdjUMCsHitCount,
			@NetAdjTopAbuPct, @NetAdjIterationCount,
			@NetAdjNetMin, @NetAdjNetMax,
			@MMATolerancePPM, @NETTolerance, @DriftTimeTolerance,
			@GANETFit, @GANETSlope, @GANETIntercept,
			@RefineMassCalPPMShift, 
			@RefineMassCalPeakHeightCounts, @RefineMassCalPeakWidthPPM, 
			@RefineMassCalPeakCenterPPM, @RefineMassTolUsed, 
			@RefineNETTolPeakHeightCounts, @RefineNETTolPeakWidthNET, 
			@RefineNETTolPeakCenterNET, @RefineNETTolUsed,
			@MinimumHighNormalizedScore, @MinimumHighDiscriminantScore, 
			@MinimumPeptideProphetProbability, @MinimumPMTQualityScore,
			@IniFileName, @ExperimentFilter, @ExperimentExclusionFilter, 
			@LimitToPMTsFromDataset,
			@MatchScoreMode,
			@STACUsedPriorProbability,
			@AMTCount1pctFDR,
			@AMTCount5pctFDR,
			@AMTCount10pctFDR,
			@AMTCount25pctFDR,
			@AMTCount50pctFDR,
			@DriftTimeAlignmentSlope,
			@DriftTimeAlignmentIntercept,
			@PMTCollectionID
			)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount, @MatchMakingID = SCOPE_IDENTITY()

	If @myError <> 0
	Begin
		ROLLBACK TRANSACTION FullTrans
		Goto Done
	End
	Else
		COMMIT TRANSACTION	FullTrans

Done:
	Return @myError


GO
GRANT EXECUTE ON [dbo].[AddMatchMaking] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[AddMatchMaking] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[AddMatchMaking] TO [MTS_DB_Lite] AS [dbo]
GO
