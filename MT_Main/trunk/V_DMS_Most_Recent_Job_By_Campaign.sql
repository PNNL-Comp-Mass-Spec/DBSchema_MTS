SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_DMS_Most_Recent_Job_By_Campaign]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_DMS_Most_Recent_Job_By_Campaign]
GO

CREATE VIEW dbo.V_DMS_Most_Recent_Job_By_Campaign
AS
SELECT Campaign, MAX(Completed) AS mrcaj
FROM GIGASAX.DMS5.dbo.V_Analysis_Job_Export t1
WHERE (NOT (AnalysisTool LIKE '%TIC%'))
GROUP BY Campaign

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

