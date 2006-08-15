/****** Object:  View [dbo].[V_Filter_Set_Overview] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW dbo.V_Filter_Set_Overview
AS
SELECT DISTINCT 
    TOP 100 PERCENT OuterQ.Filter_Set_ID, 
    OuterQ.PMT_Quality_Score_Value, OuterQ.Experiment_Filter, 
    FSI.Filter_Set_Name, FSI.Filter_Set_Description
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
    MT_Main.dbo.V_DMS_Filter_Sets_Import FSI ON 
    OuterQ.Filter_Set_ID = FSI.Filter_Set_ID
ORDER BY OuterQ.PMT_Quality_Score_Value, OuterQ.Filter_Set_ID


GO
