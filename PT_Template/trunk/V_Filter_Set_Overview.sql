SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Filter_Set_Overview]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Filter_Set_Overview]
GO


CREATE VIEW dbo.V_Filter_Set_Overview
AS
SELECT DISTINCT 
    TOP 100 PERCENT LookupQ.Filter_Type_ID, 
    LookupQ.Filter_Set_ID, FSI.Filter_Set_Name, 
    FSI.Filter_Set_Description, 
    FSI.Filter_Type_ID AS Filter_Type_ID_DMS, 
    FSI.Filter_Type_Name AS Filter_Type_Name_DMS
FROM (SELECT CONVERT(int, LTRIM(RTRIM(Value))) 
          AS Filter_Set_ID, 1 AS Filter_Type_ID
      FROM T_Process_Config
      WHERE (Name = 'Peptide_Import_Filter_ID')
      UNION
      SELECT CONVERT(int, LTRIM(RTRIM(Value))) 
          AS Filter_Set_ID, 2 AS Filter_Type_ID
      FROM T_Process_Config
      WHERE (Name = 'MTDB_Export_Filter_ID')) 
    LookupQ INNER JOIN
    MT_Main.dbo.V_DMS_Filter_Sets_Import FSI ON 
    LookupQ.Filter_Set_ID = FSI.Filter_Set_ID
ORDER BY LookupQ.Filter_Type_ID, LookupQ.Filter_Set_ID


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

