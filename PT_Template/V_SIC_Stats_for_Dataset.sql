/****** Object:  View [dbo].[V_SIC_Stats_for_Dataset] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create VIEW dbo.V_SIC_Stats_for_Dataset
AS
SELECT TOP 100 PERCENT DSStatsSIC.Job AS SIC_Job, 
    DS.Dataset_ID, DSStatsSIC.Parent_Ion_Index, 
    DSStatsSIC.Survey_Scan_Number, 
    SurveyScanInfo.Scan_Time AS Survey_Scan_Time, 
    DSStatsSIC.MZ, DSStatsSIC.Frag_Scan_Number, 
    DSStatsSIC.Optimal_Peak_Apex_Scan_Number, 
    PeakApexInfo.Scan_Time AS Optimal_Peak_Apex_Time, 
    DSStatsSIC.Custom_SIC_Peak, DSStatsSIC.Peak_Scan_Start, 
    DSStatsSIC.Peak_Scan_End, 
    DSStatsSIC.Peak_Scan_Max_Intensity, 
    DSStatsSIC.Peak_Intensity, DSStatsSIC.Peak_SN_Ratio, 
    DSStatsSIC.FWHM_In_Scans, DSStatsSIC.Peak_Area
FROM dbo.T_Dataset_Stats_Scans SurveyScanInfo INNER JOIN
    dbo.T_Dataset_Stats_SIC DSStatsSIC ON 
    SurveyScanInfo.Scan_Number = DSStatsSIC.Survey_Scan_Number
     AND SurveyScanInfo.Job = DSStatsSIC.Job INNER JOIN
    dbo.T_Datasets DS ON 
    DSStatsSIC.Job = DS.SIC_Job INNER JOIN
    dbo.T_Dataset_Stats_Scans PeakApexInfo ON 
    DSStatsSIC.Job = PeakApexInfo.Job AND 
    DSStatsSIC.Optimal_Peak_Apex_Scan_Number = PeakApexInfo.Scan_Number

GO
GRANT VIEW DEFINITION ON [dbo].[V_SIC_Stats_for_Dataset] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[V_SIC_Stats_for_Dataset] TO [MTS_DB_Lite] AS [dbo]
GO
