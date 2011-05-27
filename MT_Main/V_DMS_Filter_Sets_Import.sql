/****** Object:  View [dbo].[V_DMS_Filter_Sets_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE view V_DMS_Filter_Sets_Import
AS
SELECT t1.Filter_Type_ID,
        t1.Filter_Type_Name,
        t1.Filter_Set_ID,
        t1.Filter_Set_Name,
        t1.Filter_Set_Description,
        t1.Filter_Criteria_Group_ID,
        t1.Criterion_ID,
        t1.Criterion_Name,
        t1.Filter_Set_Criteria_ID,
        t1.Criterion_Comparison,
        t1.Criterion_Value
FROM GIGASAX.DMS5.dbo.V_Filter_Sets t1

GO
