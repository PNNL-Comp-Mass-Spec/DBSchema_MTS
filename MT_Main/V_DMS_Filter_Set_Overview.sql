/****** Object:  View [dbo].[V_DMS_Filter_Set_Overview] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW dbo.V_DMS_Filter_Set_Overview
AS
SELECT DISTINCT 
    TOP 100 PERCENT Filter_Type_ID, Filter_Type_Name, 
    Filter_Set_ID, Filter_Set_Name, Filter_Set_Description
FROM dbo.V_DMS_Filter_Sets_Import
ORDER BY Filter_Type_ID, Filter_Set_ID


GO
