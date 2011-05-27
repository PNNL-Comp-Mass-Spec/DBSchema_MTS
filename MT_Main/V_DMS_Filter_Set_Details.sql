/****** Object:  View [dbo].[V_DMS_Filter_Set_Details] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create VIEW V_DMS_Filter_Set_Details
AS
SELECT FSO.[Filter_Type_ID],
       FSO.[Filter_Type_Name],
       FSO.[Filter_Set_ID],
       FSO.[Filter_Set_Name],
       FSO.[Filter_Set_Description],
       FSD.[Filter_Criteria_Group_ID],
       FSD.[Criterion_ID],
       FSD.[Criterion_Name],
       FSD.[Filter_Set_Criteria_ID],
       FSD.[Criterion_Comparison],
       FSD.[Criterion_Value]
FROM dbo.T_DMS_Filter_Set_Details_Cached FSD
     INNER JOIN dbo.T_DMS_Filter_Set_Overview_Cached FSO
       ON FSD.Filter_Set_ID = FSO.Filter_Set_ID

GO
