SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_DMS_Filter_Set_Overview]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_DMS_Filter_Set_Overview]
GO

CREATE VIEW dbo.V_DMS_Filter_Set_Overview
AS
SELECT DISTINCT 
    TOP 100 PERCENT Filter_Type_ID, Filter_Type_Name, 
    Filter_Set_ID, Filter_Set_Name, Filter_Set_Description
FROM dbo.V_DMS_Filter_Sets_Import
ORDER BY Filter_Type_ID, Filter_Set_ID

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

