/****** Object:  View [dbo].[V_Old_Unused_Jobs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW dbo.V_Old_Unused_Jobs
AS
SELECT TOP 100 PERCENT DAJI.ResultType, DAJI.Campaign, 
    DAJI.Dataset, DAJI.Job, DAJI.Completed, 
    MAX(LookupQ.Last_Affected) AS Last_Affected_Max, 
    COUNT(DISTINCT LookupQ.Server) AS ServerCount
FROM (SELECT @@ServerName AS Server, Job, 
          Last_Affected
      FROM T_Analysis_Job_to_MT_DB_Map AJMDM
      UNION
      SELECT 'Pogo' AS Server, Job, Last_Affected
      FROM Pogo.MT_Main.dbo.T_Analysis_Job_to_MT_DB_Map) 
    LookupQ RIGHT OUTER JOIN
    dbo.V_DMS_Analysis_Job_Import_Ex DAJI ON 
    LookupQ.Job = DAJI.Job
WHERE (DAJI.ResultType LIKE '%Peptide_Hit') OR
    (DAJI.ResultType = 'HMMA_Peak')
GROUP BY DAJI.ResultType, DAJI.Campaign, DAJI.Dataset, 
    DAJI.Job, DAJI.Completed
HAVING (ISNULL(MAX(LookupQ.Last_Affected), DAJI.Completed) 
    < DATEADD(month, - 18, GETDATE()))
ORDER BY ISNULL(MAX(LookupQ.Last_Affected), 
    DAJI.Completed) DESC

GO
