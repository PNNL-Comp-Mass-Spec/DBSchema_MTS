/****** Object:  StoredProcedure [dbo].[AddFTICRUmc] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.AddFTICRUmc
/****************************************************	
**	Adds row to the T_FTICR_UMC_Results table
**  Modelled after AddFTICRPeak
**
**	Returns 0 if success; error number on failure
**
**	Auth:	mem
**	Date:	05/22/2003
**			06/27/2003 mem
**			08/11/2003 mem
**			10/26/2003 mem
**			12/31/2003 mem - Added @GANETLockerCount
**			06/29/2004 mem - Added @ExpressionRatioStDev, @ExpressionRatioChargeStateBasisCount, 
**							 @ExpressionRatioMemberBasisCount, and @MemberCountUsedForAbu
**			09/21/2004 mem - Switched from FT_ID to FPR_Type_ID
**			12/20/2005 mem - Renamed column GANET_Locker_Count to InternalStd_Hit_Count
**			10/07/2010 mem - Added parameter @DriftTime
**
****************************************************/
(
	@MDID INT,					--reference to T_Match_Making_Description table
	@UMCInd INT,				--index of UMC class
	@MemberCount INT,			--class members count
	@UMCScore FLOAT,			--UMC score (a measure of the quality of the UMC itself)

	@ScanFirst INT,				--class first scan number
	@ScanLast INT,				--class last scan number
	@ScanMaxAbundance INT,		--scan of the most abundant member

	@ClassMass FLOAT,					--class mass
	@MonoisotopicMassMin FLOAT=Null, 	--minimum mass of UMC members
	@MonoisotopicMassMax FLOAT=Null, 	--maximum mass of UMC members
	@MonoisotopicMassStDev FLOAT=Null, 	--standard deviation of UMC member masses
	@MonoisotopicMassMaxAbu FLOAT=Null,	--mass of the most abundant member (the class representative)
	
	@ClassAbundance FLOAT,			--class intensity
	@AbundanceMin FLOAT=Null,		--minimum intensity
	@AbundanceMax FLOAT=Null,		--maximum intensity

	@ChargeStateMin SMALLINT=Null,		--minimum charge
	@ChargeStateMax SMALLINT=Null,		--maximum charge
	@ChargeStateMaxAbu SMALLINT=Null,	--charge of the most abundant member

	@FitAverage FLOAT,			--isotopic fit for Isotopic distributions
	@FitMin FLOAT=Null,			--isotopic fit for Isotopic distributions
	@FitMax FLOAT=Null,			--isotopic fit for Isotopic distributions
	@FitStDev FLOAT=Null,		--isotopic fit for Isotopic distributions

	@ElutionTime FLOAT=Null,	--elution time (in NET units)
	@ExpressionRatio FLOAT=Null,--expression(abundance) ratio

	@PeakFPRType INT,			--reference to T_FPR_Type_Name table (field FPR_Type_ID)
	@MassTagHitCount INT,		--number of mass tag ID's matching this UMC
	@PairUMCInd INT,			--pair index
	@UMCResultsID INT OUTPUT,				--ID of the newly added row in T_FTICR_UMC_Results
	@ClassStatsChargeBasis TINYINT=NULL,	-- Charge used to determine the class mass and abundance; 0 if all charges were used; if Null, then if @ChargeStateMin = @ChargeStateMax, then will set to @ChargeStateMin; otherwise, will leave Null
	@GANETLockerCount INT=0,				-- number of Internal Standards (aka GANET lockers) matching this UMC
	@ExpressionRatioStDev FLOAT=Null,							-- Standard deviation for the pair's expression ratio
	@ExpressionRatioChargeStateBasisCount SMALLINT=Null,		-- Number of charge states used to compute expression ratio
	@ExpressionRatioMemberBasisCount INT=Null,					-- Number of members used to compute expression ratio
	@MemberCountUsedForAbu INT=Null,							-- Number of members used to compute class abundance
	@DriftTime real=0
)
As
SET NOCOUNT ON

DECLARE @returnvalue INT
SET @returnvalue=0
	
If (@ClassStatsChargeBasis Is Null)
Begin
	If (@ChargeStateMin = @ChargeStateMax)
		Set @ClassStatsChargeBasis = @ChargeStateMin
	Else
		Set @ClassStatsChargeBasis = 0
End

If (@GANETLockerCount Is Null)
	Set @GANETLockerCount = 0

--append new row to the T_FTICR_UMC_Results table
BEGIN
	INSERT INTO dbo.T_FTICR_UMC_Results
		(MD_ID, UMC_Ind, Member_Count, UMC_Score, 
		 Scan_First, Scan_Last, Scan_Max_Abundance, Class_Mass, 
		 Monoisotopic_Mass_Min, Monoisotopic_Mass_Max, 
		 Monoisotopic_Mass_StDev, Monoisotopic_Mass_MaxAbu, 
		 Class_Abundance, Abundance_Min, Abundance_Max, 
		 Class_Stats_Charge_Basis, Charge_State_Min, Charge_State_Max, Charge_State_MaxAbu,
		 Fit_Average, Fit_Min, Fit_Max, Fit_StDev, 
		 ElutionTime, Expression_Ratio, FPR_Type_ID, 
		 Pair_UMC_Ind, MassTag_Hit_Count, InternalStd_Hit_Count,
		 Expression_Ratio_StDev,
		 Expression_Ratio_Charge_State_Basis_Count,
		 Expression_Ratio_Member_Basis_Count,
		 Member_Count_Used_For_Abu,
		 Drift_Time)
		 
	VALUES (@MDID, @UMCInd, @MemberCount, @UMCScore, 
			@ScanFirst, @ScanLast, @ScanMaxAbundance, @ClassMass, 
			@MonoisotopicMassMin, @MonoisotopicMassMax, 
			@MonoisotopicMassStDev, @MonoisotopicMassMaxAbu, 
			@ClassAbundance, @AbundanceMin, @AbundanceMax, 
			@ClassStatsChargeBasis, @ChargeStateMin, @ChargeStateMax, @ChargeStateMaxAbu, 
			@FitAverage, @FitMin, @FitMax, @FitStDev, 
			@ElutionTime, @ExpressionRatio, @PeakFPRType, 
			@PairUMCInd, @MassTagHitCount, @GANETLockerCount,
			@ExpressionRatioStDev, 
			@ExpressionRatioChargeStateBasisCount, 
			@ExpressionRatioMemberBasisCount,
			@MemberCountUsedForAbu,
			@DriftTime)

	SET @UMCResultsID=@@IDENTITY	--return ID
	
	SET @returnvalue=@@ERROR
END
	
RETURN @returnvalue


GO
GRANT EXECUTE ON [dbo].[AddFTICRUmc] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[AddFTICRUmc] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[AddFTICRUmc] TO [MTS_DB_Lite] AS [dbo]
GO
