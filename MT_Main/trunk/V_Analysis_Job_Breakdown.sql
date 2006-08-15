/****** Object:  View [dbo].[V_Analysis_Job_Breakdown] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO





CREATE VIEW dbo.V_Analysis_Job_Breakdown
AS
SELECT     TOP 100 PERCENT Organism, Campaign, OrganismDBName, ParameterFileName, COUNT(Job) AS Jobs
FROM         V_DMS_Analysis_Job_Import_Ex
WHERE     (NOT (AnalysisTool LIKE '%TIC%'))
GROUP BY Organism, Campaign, OrganismDBName, ParameterFileName
ORDER BY Organism, Campaign, OrganismDBName, ParameterFileName



GO
