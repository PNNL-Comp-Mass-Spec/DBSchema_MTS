/****** Object:  View [dbo].[V_DMS_Filter_Set_Report] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbo.V_DMS_Filter_Set_Report
AS
SELECT TOP 100 PERCENT t1.*
FROM GIGASAX.DMS5.dbo.V_Filter_Set_Report t1
ORDER BY Filter_Set_ID, Filter_Criteria_Group_ID

GO
