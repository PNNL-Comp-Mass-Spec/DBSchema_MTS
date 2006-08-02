SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_DMS_Filter_Set_Report]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_DMS_Filter_Set_Report]
GO

CREATE VIEW dbo.V_DMS_Filter_Set_Report
AS
SELECT TOP 100 PERCENT t1.*
FROM GIGASAX.DMS5.dbo.V_Filter_Set_Report t1
ORDER BY Filter_Set_ID, Filter_Criteria_Group_ID

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

