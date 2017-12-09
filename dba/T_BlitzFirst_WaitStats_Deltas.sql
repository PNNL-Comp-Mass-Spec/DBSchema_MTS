/****** Object:  View [dbo].[T_BlitzFirst_WaitStats_Deltas] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[T_BlitzFirst_WaitStats_Deltas] AS 
SELECT w.ServerName, w.CheckDate, w.wait_type, COALESCE(wc.WaitCategory, 'Other') AS WaitCategory, COALESCE(wc.Ignorable,0) AS Ignorable
, DATEDIFF(ss, wPrior.CheckDate, w.CheckDate) AS ElapsedSeconds
, (w.wait_time_ms - wPrior.wait_time_ms) AS wait_time_ms_delta
, (w.wait_time_ms - wPrior.wait_time_ms) / 60000.0 AS wait_time_minutes_delta
, (w.wait_time_ms - wPrior.wait_time_ms) / 1000.0 / DATEDIFF(ss, wPrior.CheckDate, w.CheckDate) AS wait_time_minutes_per_minute
, (w.signal_wait_time_ms - wPrior.signal_wait_time_ms) AS signal_wait_time_ms_delta
, (w.waiting_tasks_count - wPrior.waiting_tasks_count) AS waiting_tasks_count_delta
FROM [dbo].[T_BlitzFirst_WaitStats] w
INNER JOIN [dbo].[T_BlitzFirst_WaitStats] wPrior ON w.ServerName = wPrior.ServerName AND w.wait_type = wPrior.wait_type AND w.CheckDate > wPrior.CheckDate
LEFT OUTER JOIN [dbo].[T_BlitzFirst_WaitStats] wMiddle ON w.ServerName = wMiddle.ServerName AND w.wait_type = wMiddle.wait_type AND w.CheckDate > wMiddle.CheckDate AND wMiddle.CheckDate > wPrior.CheckDate
LEFT OUTER JOIN [dbo].[T_BlitzFirst_WaitStats_Categories] wc ON w.wait_type = wc.WaitType
WHERE wMiddle.ID IS NULL AND w.wait_time_ms >= wPrior.wait_time_ms AND DATEDIFF(MI, wPrior.CheckDate, w.CheckDate) BETWEEN 1 AND 60;
GO
