/****** Object:  View [dbo].[V_DMS_Filter_Sets_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_DMS_Filter_Sets_Import]
AS
SELECT Filter_Type_ID,
       Filter_Type_Name,
       Filter_Set_ID,
       Filter_Set_Name,
       Filter_Set_Description,
       Filter_Criteria_Group_ID,
       Criterion_ID,
       Criterion_Name,
       Filter_Set_Criteria_ID,
       Criterion_Comparison,
       Criterion_Value
FROM S_V_Filter_Sets


GO
