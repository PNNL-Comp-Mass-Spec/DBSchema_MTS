/****** Object:  View [dbo].[V_Peak_Matching_Activity] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbo.V_Peak_Matching_Activity
AS
SELECT TOP 100 PERCENT t1.*
FROM POGO.PRISM_RPT.dbo.V_Peak_Matching_Activity t1
WHERE (Active_Processor = 1)
ORDER BY pm_start DESC

GO
