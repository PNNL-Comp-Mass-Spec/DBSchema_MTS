/****** Object:  View [dbo].[V_DMS_Filter_Set_Overview] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW V_DMS_Filter_Set_Overview
AS
SELECT Filter_Type_ID,
       Filter_Type_Name,
       Filter_Set_ID,
       Filter_Set_Name,
       Filter_Set_Description
FROM T_DMS_Filter_Set_Overview_Cached

GO
