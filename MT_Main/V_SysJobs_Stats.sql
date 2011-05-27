/****** Object:  View [dbo].[V_SysJobs_Stats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW dbo.V_SysJobs_Stats
AS
SELECT Category,
       Job,
       Job_ID,
       RunDuration_Avg_Minutes,
       RunDuration_Min_Minutes,
       RunDuration_Max_Minutes,
       Message,
       Convert(smalldatetime, 
         Substring(Convert(varchar(12), RunDate_First), 1, 4) + '-' + 
         Substring(Convert(varchar(12), RunDate_First), 5, 2) + '-' + 
         Substring(Convert(varchar(12), RunDate_First), 7, 2)) AS RunDate_First,
       Convert(smalldatetime, 
         Substring(Convert(varchar(12), RunDate_Last ), 1, 4) + '-' + 
         Substring(Convert(varchar(12), RunDate_Last ), 5, 2) + '-' + 
         Substring(Convert(varchar(12), RunDate_Last ), 7, 2)) AS RunDate_Last,
       Run_Count
FROM ( SELECT C.Name AS Category,
              V.Name AS Job,
              V.Job_ID,
              H.message,
              Min(H.run_date) AS RunDate_First,
              Max(H.run_date) AS RunDate_Last,
              Convert(decimal(18, 2), Avg(H.run_Duration / 60.0)) AS RunDuration_Avg_Minutes,
              Convert(decimal(18, 2), Min(H.run_Duration / 60.0)) AS RunDuration_Min_Minutes,
              Convert(decimal(18, 2), Max(H.run_Duration / 60.0)) AS RunDuration_Max_Minutes,
              COUNT(*) as Run_Count
       FROM msdb.dbo.sysjobhistory H
            INNER JOIN msdb.dbo.sysjobs_view V
              ON V.job_id = H.Job_ID
            INNER JOIN msdb.dbo.syscategories C
              ON V.category_id = C.category_ID
       WHERE H.step_id = 0
       GROUP BY C.Name, V.Name, V.Job_ID, H.message ) LookupQ

GO
