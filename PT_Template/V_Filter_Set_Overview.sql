/****** Object:  View [dbo].[V_Filter_Set_Overview] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_Filter_Set_Overview]
AS
SELECT  LookupQ.Filter_Type_ID,
        LookupQ.Filter_Set_ID,
		LookupQ.Campaign_Filter,
        FSO.Filter_Set_Name,
        FSO.Filter_Set_Description,
        FSO.Filter_Type_ID AS Filter_Type_ID_DMS,
        FSO.Filter_Type_Name AS Filter_Type_Name_DMS
FROM (SELECT CONVERT(int, LTRIM(RTRIM(Value))) AS Filter_Set_ID,
             '(n/a)' AS Campaign_Filter,
             1 AS Filter_Type_ID
      FROM T_Process_Config
      WHERE (Name = 'Peptide_Import_Filter_ID')
      UNION
      SELECT CONVERT(int, LTRIM(RTRIM(Substring(Value, 1, CommaLoc - 1)))) AS Filter_Set_ID,
             LTRIM(RTRIM(Substring(Value, CommaLoc + 1, 256))) AS Campaign_Filter,
             1 AS Filter_Type_ID
      FROM ( SELECT Value,
                    CharIndex(',', Value) AS CommaLoc
             FROM T_Process_Config
             WHERE (Name = 'Peptide_Import_Filter_ID_by_Campaign') AND
                   Value LIKE '%,%' ) PIFC
      UNION
      SELECT CONVERT(int, LTRIM(RTRIM(Value))) AS Filter_Set_ID,
             '(n/a)' AS Campaign_Filter,
             2 AS Filter_Type_ID
      FROM T_Process_Config
      WHERE (Name = 'MTDB_Export_Filter_ID') ) LookupQ
     INNER JOIN MT_Main.dbo.V_DMS_Filter_Set_Overview FSO
       ON LookupQ.Filter_Set_ID = FSO.Filter_Set_ID


GO
