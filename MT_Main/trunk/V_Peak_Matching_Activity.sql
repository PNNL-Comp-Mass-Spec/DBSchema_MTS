SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Peak_Matching_Activity]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Peak_Matching_Activity]
GO

CREATE VIEW dbo.V_Peak_Matching_Activity
AS
SELECT TOP 100 PERCENT t1.*
FROM POGO.PRISM_RPT.dbo.V_Peak_Matching_Activity t1
WHERE (Active_Processor = 1)
ORDER BY pm_start DESC

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

