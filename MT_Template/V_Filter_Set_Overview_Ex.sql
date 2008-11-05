/****** Object:  View [dbo].[V_Filter_Set_Overview_Ex] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_Filter_Set_Overview_Ex]
AS
SELECT TOP 100 PERCENT *
FROM (SELECT DISTINCT 'Observation Count Filter' AS Filter_Type,
                      LookupQ.Filter_Set_ID,
                      '' AS Extra_Info,
                      FSO.Filter_Set_Name,
                      FSO.Filter_Set_Description
      FROM ( SELECT CONVERT(int, Value) AS Filter_Set_ID
             FROM T_Process_Config
             WHERE (Name = 'Peptide_Obs_Count_Filter_ID') ) LookupQ
           INNER JOIN MT_Main.dbo.V_DMS_Filter_Set_Overview FSO
             ON LookupQ.Filter_Set_ID = FSO.Filter_Set_ID
      UNION
      SELECT DISTINCT 'Peptide Import Filter' AS Filter_Type,
                      LookupQ.Filter_Set_ID,
                      '' AS Extra_Info,
                      FSO.Filter_Set_Name,
                      FSO.Filter_Set_Description
      FROM ( SELECT CONVERT(int, Value) AS Filter_Set_ID
             FROM T_Process_Config
             WHERE (Name = 'Peptide_Import_Filter_ID') ) LookupQ
           INNER JOIN MT_Main.dbo.V_DMS_Filter_Set_Overview FSO
             ON LookupQ.Filter_Set_ID = FSO.Filter_Set_ID
      UNION
      SELECT 'PMT Quality Score Filter' AS Filter_Type,
             Filter_Set_ID,
             'PMT_Quality_Score_Value = ' + 
               CONVERT(varchar(9), PMT_Quality_Score_Value) + 
               CASE
                   WHEN Len(Experiment_Filter) > 0 THEN '; Experiment_Filter = ' + Experiment_Filter
                   ELSE '' 
               END +
               CASE
                   WHEN Len(Instrument_Class_Filter) > 0 THEN '; Instrument_Class_Filter = ' + Instrument_Class_Filter
                   ELSE ''
               END AS Extra_Info,
             Filter_Set_Name,
             Filter_Set_Description
      FROM V_Filter_Set_Overview ) LookupQ
ORDER BY Filter_Type, Extra_Info, Filter_Set_ID


GO
