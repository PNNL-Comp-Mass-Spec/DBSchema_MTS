/****** Object:  View [dbo].[V_DMS_Filter_Set_Overview_Import] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_DMS_Filter_Set_Overview_Import]
AS
SELECT Filter_Type_ID,
       Filter_Type_Name,
       Filter_Set_ID,
       Filter_Set_Name,
       Filter_Set_Description
FROM S_V_Filter_Set_Overview


GO
