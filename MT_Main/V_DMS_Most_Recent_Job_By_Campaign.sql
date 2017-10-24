/****** Object:  View [dbo].[V_DMS_Most_Recent_Job_By_Campaign] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_DMS_Most_Recent_Job_By_Campaign]
AS
SELECT Campaign, MAX(Completed) AS mrcaj
FROM S_V_Analysis_Jobs
WHERE (NOT (AnalysisTool LIKE '%TIC%'))
GROUP BY Campaign


GO
