SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Analysis_Job_Breakdown]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Analysis_Job_Breakdown]
GO






CREATE VIEW dbo.V_Analysis_Job_Breakdown
AS
SELECT     TOP 100 PERCENT Organism, Campaign, OrganismDBName, ParameterFileName, COUNT(Job) AS Jobs
FROM         V_DMS_Analysis_Job_Import_Ex
WHERE     (NOT (AnalysisTool LIKE '%TIC%'))
GROUP BY Organism, Campaign, OrganismDBName, ParameterFileName
ORDER BY Organism, Campaign, OrganismDBName, ParameterFileName



GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

