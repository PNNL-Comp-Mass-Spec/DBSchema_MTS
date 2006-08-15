/****** Object:  View [dbo].[V_DMS_Most_Recent_Job_By_Campaign] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbo.V_DMS_Most_Recent_Job_By_Campaign
AS
SELECT Campaign, MAX(Completed) AS mrcaj
FROM GIGASAX.DMS5.dbo.V_Analysis_Job_Export t1
WHERE (NOT (AnalysisTool LIKE '%TIC%'))
GROUP BY Campaign

GO
