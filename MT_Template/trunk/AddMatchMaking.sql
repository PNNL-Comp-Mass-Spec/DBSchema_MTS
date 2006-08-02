SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[AddMatchMaking]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[AddMatchMaking]
GO


CREATE Procedure dbo.AddMatchMaking
/******************************************************* 	
**	adds row to the T_Match_Making table
**  returns ID assigned to new rec. in output par.
**	returns 0 if success; error number on failure
**
**	Date:	12/14/2001 
**	Author: nt
**
**			06/23/2003 mem - added @ToolVersion
**			06/25/2003 mem - added 7 new inputs
**			07/01/2003 mem - changed MD_State update logic to set to 5 if previously analyzed; 
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
*******************************************************/
(
	@Reference_Job int,
	@File varchar(255),
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
	@RefineMassTolUsed				tinyint=0,
	@RefineNETTolUsed				tinyint=0,
	@MinimumHighNormalizedScore decimal(9,5)=NULL,
	@MinimumPMTQualityScore		decimal(9,5)=NULL,
	@IniFileName			 varchar(255)=NULL,
	@MinimumHighDiscriminantScore real=0, 
	@ExperimentFilter varchar(64)='',
	@ExperimentExclusionFilter varchar(64)='',
	@RefineMassCalPeakWidthPPM real=NULL,
	@RefineMassCalPeakCenterPPM real = NULL,
	@RefineNETTolPeakHeightCounts int=NULL,
	@RefineNETTolPeakWidthNET real=NULL,
	@RefineNETTolPeakCenterNET real = NULL
)
As
Set NoCount On

DECLARE @returnvalue INT
SET @returnvalue=0
	
DECLARE @Date DATETIME
SET @Date=GETDATE()	

Declare @charLoc int

If Len(IsNull(@IniFileName, '')) = 0
	Set @IniFileName = ''

If Len(@IniFileName) = 0 And @Parameters Like 'IniFile=%'
Begin
	Set @charLoc = CHARINDEX('.ini', @Parameters)	
	If IsNull(@charLoc, 0) > 1
		set @IniFileName = SubString(@Parameters, 9, @charLoc - 5)
End

BEGIN TRANSACTION FullTrans		-- two updates; better have rollback available
	
--if there are analyses with same Reference_Job and Type, then mark
--this as an update (all previous have to be marked as Updated)
UPDATE dbo.T_Match_Making_Description
SET MD_State = 5
WHERE (MD_Reference_Job=@Reference_Job AND MD_Type=@Type)	-- AND MD_Parameters=@Parameters

SET @returnvalue=@@ERROR

--append new row to the T_Match_Making_Description table
IF @returnvalue=0 
BEGIN
	INSERT INTO dbo.T_Match_Making_Description (
		MD_Reference_Job, MD_File, MD_Type, MD_Parameters, 
		MD_Date, MD_State, MD_Peaks_Count, 
		MD_Tool_Version, MD_Comparison_Mass_Tag_Count, 
		MD_UMC_TolerancePPM, MD_UMC_Count,
		MD_NetAdj_TolerancePPM, MD_NetAdj_UMCs_HitCount, 
		MD_NetAdj_TopAbuPct, MD_NetAdj_IterationCount,
		MD_NetAdj_NET_Min, MD_NetAdj_NET_Max,
		MD_MMA_TolerancePPM, MD_NET_Tolerance, 
		GANET_Fit, GANET_Slope, GANET_Intercept,
		Refine_Mass_Cal_PPMShift, 
		Refine_Mass_Cal_PeakHeightCounts, Refine_Mass_Cal_PeakWidthPPM,
		Refine_Mass_Cal_PeakCenterPPM, Refine_Mass_Tol_Used, 
		Refine_NET_Tol_PeakHeightCounts, Refine_NET_Tol_PeakWidth, 
		Refine_NET_Tol_PeakCenter, Refine_NET_Tol_Used,
		Minimum_High_Normalized_Score, Minimum_High_Discriminant_Score, Minimum_PMT_Quality_Score,
		Ini_File_Name, Experiment_Filter, Experiment_Exclusion_Filter
		)
	VALUES (@Reference_Job, @File, @Type, @Parameters, 
			@Date, @State, @PeaksCount, 
			@ToolVersion, @ComparisonMassTagCount,
			@UMCTolerancePPM, @UMCCount,
			@NetAdjTolerancePPM, @NetAdjUMCsHitCount,
			@NetAdjTopAbuPct, @NetAdjIterationCount,
			@NetAdjNetMin, @NetAdjNetMax,
			@MMATolerancePPM, @NETTolerance,
			@GANETFit, @GANETSlope, @GANETIntercept,
			@RefineMassCalPPMShift, 
			@RefineMassCalPeakHeightCounts, @RefineMassCalPeakWidthPPM, 
			@RefineMassCalPeakCenterPPM, @RefineMassTolUsed, 
			@RefineNETTolPeakHeightCounts, @RefineNETTolPeakWidthNET, 
			@RefineNETTolPeakCenterNET, @RefineNETTolUsed,
			@MinimumHighNormalizedScore, @MinimumHighDiscriminantScore, @MinimumPMTQualityScore,
			@IniFileName, @ExperimentFilter, @ExperimentExclusionFilter
			)

	SET @MatchMakingID=@@IDENTITY	--return ID	
		
	SET @returnvalue=@@ERROR
END
	
--if everything OK commit transaction, otherwise rollback
IF @returnvalue=0
	COMMIT TRANSACTION	FullTrans
ELSE
	ROLLBACK TRANSACTION FullTrans

Return @returnvalue


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[AddMatchMaking]  TO [DMS_SP_User]
GO

