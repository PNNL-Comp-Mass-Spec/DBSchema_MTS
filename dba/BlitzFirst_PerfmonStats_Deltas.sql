/****** Object:  View [dbo].[BlitzFirst_PerfmonStats_Deltas] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[BlitzFirst_PerfmonStats_Deltas] AS 
SELECT p.ServerName, p.CheckDate, p.object_name, p.counter_name, p.instance_name
, DATEDIFF(ss, pPrior.CheckDate, p.CheckDate) AS ElapsedSeconds
, p.cntr_value
, p.cntr_type
, (p.cntr_value - pPrior.cntr_value) AS cntr_delta
, (p.cntr_value - pPrior.cntr_value) * 1.0 / DATEDIFF(ss, pPrior.CheckDate, p.CheckDate) AS cntr_delta_per_second
FROM [dbo].[BlitzFirst_PerfmonStats] p
INNER JOIN [dbo].[BlitzFirst_PerfmonStats] pPrior ON p.ServerName = pPrior.ServerName AND p.object_name = pPrior.object_name AND p.counter_name = pPrior.counter_name AND p.instance_name = pPrior.instance_name AND p.CheckDate > pPrior.CheckDate
LEFT OUTER JOIN [dbo].[BlitzFirst_PerfmonStats] pMiddle ON p.ServerName = pMiddle.ServerName AND p.object_name = pMiddle.object_name AND p.counter_name = pMiddle.counter_name AND p.instance_name = pMiddle.instance_name AND p.CheckDate > pMiddle.CheckDate AND pMiddle.CheckDate > pPrior.CheckDate
WHERE pMiddle.ID IS NULL AND DATEDIFF(MI, pPrior.CheckDate, p.CheckDate) BETWEEN 1 AND 60;
GO
