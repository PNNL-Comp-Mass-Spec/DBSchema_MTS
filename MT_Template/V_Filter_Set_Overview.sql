/****** Object:  View [dbo].[V_Filter_Set_Overview] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_Filter_Set_Overview]
AS
SELECT DISTINCT 
	OuterQ.Filter_Set_ID,
    OuterQ.PMT_Quality_Score_Value,
    OuterQ.Experiment_Filter,
	OuterQ.Instrument_Class_Filter,
    FSO.Filter_Set_Name,
    FSO.Filter_Set_Description
FROM ( SELECT CONVERT(int, LTRIM(RTRIM(SUBSTRING(Value, 1, CommaLoc - 1)))) AS Filter_Set_ID,
              CASE
                  WHEN CommaLoc2 > 0 THEN LTRIM(RTRIM(SUBSTRING(Value, CommaLoc + 1, CommaLoc2 - CommaLoc - 1)))
                  ELSE LTrim(RTrim(SUBSTRING(Value, CommaLoc + 1, LEN(Value) - CommaLoc)))
              END AS PMT_Quality_Score_Value,
              CASE
                  WHEN CommaLoc2 > 0 THEN LTrim(RTrim(SUBSTRING(Value, CommaLoc2 + 1, CASE WHEN CommaLoc3 > 0 Then CommaLoc3-1 Else LEN(Value) End - CommaLoc2)))
                  ELSE ''
              END AS Experiment_Filter,
              CASE
                  WHEN CommaLoc2 > 0 AND CommaLoc3 > 0 THEN LTrim(RTrim(SUBSTRING(Value, CommaLoc3 + 1, LEN(Value) - CommaLoc3)))
                  ELSE ''
              END AS Instrument_Class_Filter
       FROM ( SELECT Process_Config_ID,
                     Value,
                     CHARINDEX(',', Value) AS CommaLoc,
                     CHARINDEX(',', Value, IsNull(CHARINDEX(',', Value), 0) + 1) AS CommaLoc2,
                     CHARINDEX(',', Value, IsNull(CHARINDEX(',', Value, IsNull(CHARINDEX(',', Value), 0) + 1), 0) + 1) AS CommaLoc3
              FROM T_Process_Config
              WHERE (Name = 'PMT_Quality_Score_Set_ID_and_Value') ) LookupQ
       WHERE (CommaLoc > 0) ) OuterQ
     LEFT OUTER JOIN MT_Main.dbo.V_DMS_Filter_Set_Overview FSO
       ON OuterQ.Filter_Set_ID = FSO.Filter_Set_ID



GO
