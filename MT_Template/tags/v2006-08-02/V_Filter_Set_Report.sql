SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Filter_Set_Report]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Filter_Set_Report]
GO

create VIEW dbo.V_Filter_Set_Report
AS
SELECT TOP 100 PERCENT OuterQ.Filter_Set_ID, 
    OuterQ.PMT_Quality_Score_Value, OuterQ.Experiment_Filter, 
    FSR.Filter_Set_Name, FSR.Filter_Set_Description, 
    FSR.Spectrum_Count_Comparison, 
    FSR.Spectrum_Count_Value, FSR.Charge_Comparison, 
    FSR.Charge_Value, FSR.Score_Comparison, FSR.Score_Value, 
    FSR.Cleavage_State_Comparison, FSR.Cleavage_State_Value, 
    FSR.Peptide_Length_Comparison, FSR.Peptide_Length_Value, 
    FSR.Mass_Comparison, FSR.Mass_Value, 
    FSR.DelCn_Comparison, FSR.DelCn_Value, 
    FSR.DelCn2_Comparison, FSR.DelCn2_Value, 
    FSR.Discriminant_Score_Comparison, 
    FSR.Discriminant_Score_Value, 
    FSR.NET_Difference_Comparison, 
    FSR.NET_Difference_Value
FROM (SELECT CONVERT(int, LTRIM(RTRIM(SUBSTRING(Value, 1, 
          CommaLoc - 1)))) AS Filter_Set_ID, 
          CASE WHEN CommaLoc2 > 0 THEN LTRIM(RTRIM(SUBSTRING(Value,
           CommaLoc + 1, CommaLoc2 - CommaLoc - 1))) 
          ELSE LTrim(RTrim(SUBSTRING(Value, CommaLoc + 1, 
          LEN(Value) - CommaLoc))) 
          END AS PMT_Quality_Score_Value, 
          CASE WHEN CommaLoc2 > 0 THEN LTrim(RTrim(SUBSTRING(value,
           CommaLoc2 + 1, LEN(Value) - CommaLoc2))) 
          ELSE '' END AS Experiment_Filter
      FROM (SELECT Process_Config_ID, Value, CHARINDEX(',', 
                Value) AS CommaLoc, CHARINDEX(',', Value, 
                IsNull(CHARINDEX(',', Value), 0) + 1) 
                AS CommaLoc2
            FROM T_Process_Config
            WHERE (Name = 'PMT_Quality_Score_Set_ID_and_Value'))
           LookupQ
      WHERE (CommaLoc > 0)) OuterQ INNER JOIN
    MT_Main.dbo.V_DMS_Filter_Set_Report FSR ON 
    OuterQ.Filter_Set_ID = FSR.Filter_Set_ID
ORDER BY OuterQ.PMT_Quality_Score_Value, 
    OuterQ.Filter_Set_ID, FSR.Charge_Value, 
    FSR.Cleavage_State_Value DESC

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

