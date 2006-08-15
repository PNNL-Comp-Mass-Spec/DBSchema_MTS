/****** Object:  View [dbo].[V_IFC_PM_Results_Summary] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW dbo.V_IFC_PM_Results_Summary
AS
SELECT TOP 100 PERCENT MMD.MD_ID, MMD.MD_Reference_Job, 
    MMD.MD_File, MTN.MD_Type_Name, MMD.MD_Date, 
    MSN.MD_State_Name, MMD.MD_Peaks_Count, 
    MMD.MD_Tool_Version, 
    MMD.MD_Comparison_Mass_Tag_Count, 
    MMD.MD_UMC_TolerancePPM, MMD.MD_UMC_Count, 
    MMD.MD_NetAdj_TolerancePPM, 
    MMD.MD_NetAdj_UMCs_HitCount, 
    MMD.MD_NetAdj_TopAbuPct, MMD.MD_NetAdj_IterationCount, 
    MMD.MD_NetAdj_NET_Min, MMD.MD_NetAdj_NET_Max, 
    MMD.MD_MMA_TolerancePPM, MMD.MD_NET_Tolerance, 
    MMD.GANET_Fit, MMD.GANET_Slope, MMD.GANET_Intercept, 
    MMD.Refine_Mass_Cal_PPMShift, FAD.Dataset, 
    FAD.Total_Scans, FAD.Scan_Start, FAD.Scan_End, 
    MMD.MD_Parameters, 
    MMD.Refine_Mass_Cal_PeakHeightCounts, 
    MMD.Refine_Mass_Cal_PeakWidthPPM, 
    MMD.Refine_Mass_Cal_PeakCenterPPM, 
    MMD.Refine_Mass_Tol_Used, 
    MMD.Refine_NET_Tol_PeakHeightCounts, 
    MMD.Refine_NET_Tol_PeakWidth, 
    MMD.Refine_NET_Tol_PeakCenter, 
    MMD.Refine_NET_Tol_Used, MMD.Ini_File_Name
FROM dbo.T_Match_Making_Description MMD INNER JOIN
    dbo.T_FTICR_Analysis_Description FAD ON 
    MMD.MD_Reference_Job = FAD.Job INNER JOIN
    dbo.T_MMD_State_Name MSN ON 
    MMD.MD_State = MSN.MD_State INNER JOIN
    dbo.T_MMD_Type_Name MTN ON 
    MMD.MD_Type = MTN.MD_Type
ORDER BY MMD.MD_ID


GO
