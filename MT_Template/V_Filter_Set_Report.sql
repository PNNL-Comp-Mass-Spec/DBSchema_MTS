/****** Object:  View [dbo].[V_Filter_Set_Report] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW V_Filter_Set_Report
AS
SELECT OuterQ.Filter_Set_ID, 
    OuterQ.PMT_Quality_Score_Value, OuterQ.Experiment_Filter, 
    FSR.Filter_Set_Name, FSR.Filter_Set_Description, 
    FSR.Charge,
    FSR.High_Normalized_Score,
    FSR.Cleavage_State,
    FSR.Terminus_State,
    FSR.DelCn,
    FSR.DelCn2,
    FSR.RankScore,
    FSR.XTandem_Hyperscore,
    FSR.XTandem_LogEValue,
    FSR.Peptide_Prophet_Probability,
    FSR.MSGF_SpecProb,
    FSR.MSGFDB_SpecProb,
    FSR.MSGFDB_PValue,
    FSR.MSGFDB_FDR,
    FSR.MSAlign_PValue,
    FSR.MSAlign_FDR,
    FSR.Inspect_MQScore,
    FSR.Inspect_TotalPRMScore,
    FSR.Inspect_FScore,
    FSR.Inspect_PValue,
    FSR.Discriminant_Score,
    FSR.NET_Difference_Absolute,
    FSR.Discriminant_Initial_Filter,
    FSR.Peptide_Length,
    FSR.Mass,
    FSR.Spectrum_Count,
    FSR.Protein_Count    
FROM (SELECT CONVERT(int, LTRIM(RTRIM(SUBSTRING(Value, 1, CommaLoc - 1)))) AS Filter_Set_ID, 
          CASE WHEN CommaLoc2 > 0 
          THEN LTRIM(RTRIM(SUBSTRING(Value, CommaLoc + 1, CommaLoc2 - CommaLoc - 1))) 
          ELSE LTrim(RTrim(SUBSTRING(Value, CommaLoc + 1, LEN(Value) - CommaLoc))) 
          END AS PMT_Quality_Score_Value, 
          CASE WHEN CommaLoc2 > 0 
          THEN LTrim(RTrim(SUBSTRING(value, CommaLoc2 + 1, LEN(Value) - CommaLoc2))) 
          ELSE '' 
          END AS Experiment_Filter
      FROM (SELECT  Process_Config_ID, Value, 
                    CHARINDEX(',', Value) AS CommaLoc, 
                    CHARINDEX(',', Value, ISNULL(CHARINDEX(',', Value), 0) + 1) AS CommaLoc2
            FROM dbo.T_Process_Config
            WHERE (Name = 'PMT_Quality_Score_Set_ID_and_Value'))
           AS LookupQ
      WHERE (CommaLoc > 0)) AS OuterQ INNER JOIN
    MT_Main.dbo.V_DMS_Filter_Set_Report AS FSR ON 
    OuterQ.Filter_Set_ID = FSR.Filter_Set_ID


GO
